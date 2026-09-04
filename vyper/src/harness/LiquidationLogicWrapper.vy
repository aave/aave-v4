# pragma version 0.5.0b2

from hub.libraries import Premium
from libraries import Errors
from libraries.math import WadRayMath
from spoke.libraries import LiquidationLogic
from hub.interfaces import IHub
from spoke.interfaces import IAaveOracle
from spoke.interfaces import ILiquidationLogic

error SafeCastOverflowedUintDowncast:
    arg0: uint8
    arg1: uint256

error SafeERC20FailedOperation:
    arg0: address

struct UserPosition:
    drawnShares: uint120
    premiumShares: uint120
    premiumOffsetRay: int200
    suppliedShares: uint120
    dynamicConfigKey: uint32


struct Reserve:
    underlying: address
    hub: address
    assetId: uint16
    decimals: uint8
    collateralRisk: uint24
    flags: uint8
    dynamicConfigKey: uint32

struct DynamicReserveConfig:
    collateralFactor: uint16
    maxLiquidationBonus: uint32
    liquidationFee: uint16

struct LiquidationConfig:
    targetHealthFactor: uint128
    healthFactorForMaxBonus: uint64
    liquidationBonusFactor: uint16

struct UserAccountData:
    riskPremium: uint256
    avgCollateralFactor: uint256
    healthFactor: uint256
    totalCollateralValue: uint256
    totalDebtValueRay: uint256
    activeCollateralCount: uint256
    borrowCount: uint256

struct LiquidateCollateralParams:
    hub: address
    assetId: uint256
    sharesToLiquidate: uint256
    sharesToLiquidator: uint256
    liquidator: address
    receiveShares: bool

struct LiquidateCollateralResult:
    amountRemoved: uint256
    isCollateralPositionEmpty: bool

struct LiquidateDebtParams:
    hub: address
    assetId: uint256
    underlying: address
    reserveId: uint256
    drawnSharesToLiquidate: uint256
    premiumDebtRayToLiquidate: uint256
    drawnIndex: uint256
    liquidator: address

struct LiquidateDebtResult:
    amountRestored: uint256
    premiumDelta: IHub.PremiumDelta
    isDebtPositionEmpty: bool

struct ExecuteLiquidationParams:
    collateralHub: address
    collateralAssetId: uint256
    collateralAssetDecimals: uint256
    collateralReserveId: uint256
    collateralReserveFlags: uint8
    collateralDynConfig: DynamicReserveConfig
    debtHub: address
    debtAssetId: uint256
    debtAssetDecimals: uint256
    debtUnderlying: address
    debtReserveId: uint256
    debtReserveFlags: uint8
    liquidationConfig: LiquidationConfig
    oracle: address
    user: address
    debtToCover: uint256
    healthFactor: uint256
    totalDebtValueRay: uint256
    activeCollateralCount: uint256
    borrowCount: uint256
    liquidator: address
    receiveShares: bool

struct LiquidateUserParams:
    collateralReserveId: uint256
    debtReserveId: uint256
    oracle: address
    user: address
    liquidationConfig: LiquidationConfig
    debtToCover: uint256
    userAccountData: UserAccountData
    liquidator: address
    receiveShares: bool


event LiquidationCall:
    collateralReserveId: indexed(uint256)
    debtReserveId: indexed(uint256)
    user: indexed(address)
    liquidator: address
    receiveShares: bool
    debtAmountRestored: uint256
    drawnSharesLiquidated: uint256
    premiumDelta: IHub.PremiumDelta
    collateralAmountRemoved: uint256
    collateralSharesLiquidated: uint256
    collateralSharesToLiquidator: uint256


IS_TEST: public(constant(bool)) = True

reserves: HashMap[uint256, Reserve]
user_positions: HashMap[address, HashMap[uint256, UserPosition]]
using_as_collateral: HashMap[address, HashMap[uint256, bool]]
is_borrowing: HashMap[address, HashMap[uint256, bool]]
risk_premium: HashMap[address, uint24]
dynamic_configs: HashMap[uint256, HashMap[uint32, DynamicReserveConfig]]
borrower: address
liquidator: address
collateral_reserve_id: uint256
debt_reserve_id: uint256


@deploy
def __init__(borrower_: address, liquidator_: address):
    self.borrower = borrower_
    self.liquidator = liquidator_


@internal
@pure
def _panic_arithmetic():
    raise Errors.Panic(17)


@internal
@pure
def _u120(cast_value: uint256) -> uint120:
    if cast_value > convert(max_value(uint120), uint256):
        raise SafeCastOverflowedUintDowncast(120, cast_value)
    return convert(cast_value, uint120)


@internal
@pure
def _u32(cast_value: uint256) -> uint32:
    if cast_value > convert(max_value(uint32), uint256):
        raise SafeCastOverflowedUintDowncast(32, cast_value)
    return convert(cast_value, uint32)


@internal
@pure
def _calculate_premium_ray(position: UserPosition, drawn_index: uint256) -> uint256:
    return Premium.calculate_premium_ray(
        convert(position.premiumShares, uint256),
        convert(position.premiumOffsetRay, int256),
        drawn_index,
    )


@internal
@pure
def _calculate_premium_delta(
    position: UserPosition,
    drawn_shares_taken: uint256,
    drawn_index: uint256,
    risk_premium_: uint256,
    restored_premium_ray: uint256,
) -> IHub.PremiumDelta:
    premium_debt_ray: uint256 = self._calculate_premium_ray(position, drawn_index)
    if drawn_shares_taken > convert(position.drawnShares, uint256) or restored_premium_ray > premium_debt_ray:
        self._panic_arithmetic()
    remaining_shares: uint256 = convert(position.drawnShares, uint256) - drawn_shares_taken
    product: uint256 = remaining_shares * risk_premium_
    new_shares: uint256 = product // 10**4 + convert(product % 10**4 != 0, uint256)
    new_offset: int256 = convert(new_shares * drawn_index, int256) - convert(premium_debt_ray - restored_premium_ray, int256)
    return IHub.PremiumDelta(
        sharesDelta=convert(new_shares, int256) - convert(position.premiumShares, int256),
        offsetRayDelta=new_offset - convert(position.premiumOffsetRay, int256),
        restoredPremiumRay=restored_premium_ray,
    )


@internal
def _safe_transfer_from(token: address, owner: address, recipient: address, amount: uint256):
    response: Bytes[32] = raw_call(
        token,
        concat(method_id("transferFrom(address,address,uint256)"), convert(owner, bytes32), convert(recipient, bytes32), convert(amount, bytes32)),
        max_outsize=32,
    )
    if len(response) != 0 and not convert(response, bool):
        raise SafeERC20FailedOperation(token)


@external
def setBorrower(new_borrower: address):
    self.borrower = new_borrower


@external
def setLiquidator(new_liquidator: address):
    self.liquidator = new_liquidator


@external
def setCollateralReserveId(reserveId: uint256):
    self.collateral_reserve_id = reserveId


@external
def setCollateralReserveHub(hub: address):
    reserve: Reserve = self.reserves[self.collateral_reserve_id]
    reserve.hub = hub
    self.reserves[self.collateral_reserve_id] = reserve


@external
def setCollateralReserveDecimals(decimals: uint256):
    reserve: Reserve = self.reserves[self.collateral_reserve_id]
    reserve.decimals = convert(decimals, uint8)
    self.reserves[self.collateral_reserve_id] = reserve


@external
def setCollateralReserveAssetId(assetId: uint256):
    reserve: Reserve = self.reserves[self.collateral_reserve_id]
    reserve.assetId = convert(assetId, uint16)
    self.reserves[self.collateral_reserve_id] = reserve


@external
def setCollateralReserveFlags(flags: uint8):
    reserve: Reserve = self.reserves[self.collateral_reserve_id]
    reserve.flags = flags
    self.reserves[self.collateral_reserve_id] = reserve


@external
def setDynamicCollateralConfig(config: DynamicReserveConfig):
    key: uint32 = self.user_positions[self.borrower][self.collateral_reserve_id].dynamicConfigKey
    self.dynamic_configs[self.collateral_reserve_id][key] = config


@external
def setCollateralPositionSuppliedShares(suppliedShares: uint256):
    position: UserPosition = self.user_positions[self.borrower][self.collateral_reserve_id]
    position.suppliedShares = self._u120(suppliedShares)
    self.user_positions[self.borrower][self.collateral_reserve_id] = position


@external
def setCollateralPositionDynamicConfigKey(dynamicConfigKey: uint256):
    position: UserPosition = self.user_positions[self.borrower][self.collateral_reserve_id]
    position.dynamicConfigKey = self._u32(dynamicConfigKey)
    self.user_positions[self.borrower][self.collateral_reserve_id] = position


@external
def setLiquidatorPositionSuppliedShares(liquidator_: address, suppliedShares: uint256):
    position: UserPosition = self.user_positions[liquidator_][self.collateral_reserve_id]
    position.suppliedShares = self._u120(suppliedShares)
    self.user_positions[liquidator_][self.collateral_reserve_id] = position


@external
def setDebtReserveId(reserveId: uint256):
    self.debt_reserve_id = reserveId


@external
def setDebtReserveHub(hub: address):
    reserve: Reserve = self.reserves[self.debt_reserve_id]
    reserve.hub = hub
    self.reserves[self.debt_reserve_id] = reserve


@external
def setDebtReserveDecimals(decimals: uint256):
    reserve: Reserve = self.reserves[self.debt_reserve_id]
    reserve.decimals = convert(decimals, uint8)
    self.reserves[self.debt_reserve_id] = reserve


@external
def setDebtReserveAssetId(assetId: uint256):
    reserve: Reserve = self.reserves[self.debt_reserve_id]
    reserve.assetId = convert(assetId, uint16)
    self.reserves[self.debt_reserve_id] = reserve


@external
def setDebtReserveUnderlying(underlying: address):
    reserve: Reserve = self.reserves[self.debt_reserve_id]
    reserve.underlying = underlying
    self.reserves[self.debt_reserve_id] = reserve


@external
def setDebtReserveFlags(flags: uint8):
    reserve: Reserve = self.reserves[self.debt_reserve_id]
    reserve.flags = flags
    self.reserves[self.debt_reserve_id] = reserve


@external
def setDebtPositionDrawnShares(drawnShares: uint256):
    position: UserPosition = self.user_positions[self.borrower][self.debt_reserve_id]
    position.drawnShares = self._u120(drawnShares)
    self.user_positions[self.borrower][self.debt_reserve_id] = position


@external
def setDebtPositionPremiumShares(premiumShares: uint256):
    position: UserPosition = self.user_positions[self.borrower][self.debt_reserve_id]
    position.premiumShares = self._u120(premiumShares)
    self.user_positions[self.borrower][self.debt_reserve_id] = position


@external
def setDebtPositionPremiumOffsetRay(premiumOffsetRay: int256):
    position: UserPosition = self.user_positions[self.borrower][self.debt_reserve_id]
    position.premiumOffsetRay = convert(premiumOffsetRay, int200)
    self.user_positions[self.borrower][self.debt_reserve_id] = position


@external
def setBorrowerCollateralStatus(reserveId: uint256, status: bool):
    self.using_as_collateral[self.borrower][reserveId] = status


@external
def setBorrowerBorrowingStatus(reserveId: uint256, status: bool):
    self.is_borrowing[self.borrower][reserveId] = status


@external
def setLiquidatorCollateralStatus(reserveId: uint256, status: bool):
    self.using_as_collateral[self.liquidator][reserveId] = status


@external
def setLiquidatorBorrowingStatus(reserveId: uint256, status: bool):
    self.is_borrowing[self.liquidator][reserveId] = status


@external
@view
def getCollateralReserve() -> Reserve:
    return self.reserves[self.collateral_reserve_id]


@external
@view
def getCollateralPosition(user: address) -> UserPosition:
    return self.user_positions[user][self.collateral_reserve_id]


@external
@view
def getDebtReserve() -> Reserve:
    return self.reserves[self.debt_reserve_id]


@external
@view
def getDebtPosition(user: address) -> UserPosition:
    return self.user_positions[user][self.debt_reserve_id]


@external
@view
def getBorrowerCollateralStatus(reserveId: uint256) -> bool:
    return self.using_as_collateral[self.borrower][reserveId]


@external
@view
def getBorrowerBorrowingStatus(reserveId: uint256) -> bool:
    return self.is_borrowing[self.borrower][reserveId]


@external
@view
def getLiquidatorCollateralStatus(reserveId: uint256) -> bool:
    return self.using_as_collateral[self.liquidator][reserveId]


@external
@view
def getLiquidatorBorrowingStatus(reserveId: uint256) -> bool:
    return self.is_borrowing[self.liquidator][reserveId]


@external
@pure
def validateLiquidationCall(params: ILiquidationLogic.ValidateLiquidationCallParams) -> bool:
    LiquidationLogic.validate_liquidation_call(params)
    return True


@external
@pure
def calculateLiquidationBonus(healthFactorForMaxBonus: uint256, liquidationBonusFactor: uint256, healthFactor: uint256, maxLiquidationBonus: uint256) -> uint256:
    return LiquidationLogic.calculate_liquidation_bonus(healthFactorForMaxBonus, liquidationBonusFactor, healthFactor, maxLiquidationBonus)


@external
@pure
def calculateDebtToTargetHealthFactor(params: LiquidationLogic.CalculateDebtToTargetHealthFactorParams) -> uint256:
    return LiquidationLogic.calculate_debt_to_target_health_factor(params)


@external
@pure
def calculateDebtToLiquidate(params: LiquidationLogic.CalculateDebtToLiquidateParams) -> (uint256, uint256):
    return LiquidationLogic.calculate_debt_to_liquidate(params)


@external
@view
def calculateCollateralToLiquidate(params: LiquidationLogic.CalculateCollateralToLiquidateParams) -> uint256:
    return LiquidationLogic.calculate_collateral_to_liquidate(params)


@external
@view
def calculateLiquidationAmounts(params: ILiquidationLogic.CalculateLiquidationAmountsParams) -> ILiquidationLogic.LiquidationAmounts:
    return LiquidationLogic.calculate_liquidation_amounts(params)


@external
@pure
def evaluateDeficit(isCollateralPositionEmpty: bool, isDebtPositionEmpty: bool, activeCollateralCount: uint256, borrowCount: uint256) -> bool:
    return LiquidationLogic.evaluate_deficit(isCollateralPositionEmpty, isDebtPositionEmpty, activeCollateralCount, borrowCount)


@internal
def _liquidate_collateral(user: address, reserve_id: uint256, params: LiquidateCollateralParams) -> LiquidateCollateralResult:
    user_position: UserPosition = self.user_positions[user][reserve_id]
    shares_120: uint120 = self._u120(params.sharesToLiquidate)
    if shares_120 > user_position.suppliedShares:
        self._panic_arithmetic()
    user_position.suppliedShares -= shares_120
    self.user_positions[user][reserve_id] = user_position
    amount_removed: uint256 = staticcall IHub(params.hub).previewRemoveByShares(params.assetId, params.sharesToLiquidate)
    if params.sharesToLiquidator > params.sharesToLiquidate:
        self._panic_arithmetic()
    if params.sharesToLiquidator > 0:
        if params.receiveShares:
            liquidator_position: UserPosition = self.user_positions[params.liquidator][reserve_id]
            liquidator_position.suppliedShares = self._u120(convert(liquidator_position.suppliedShares, uint256) + params.sharesToLiquidator)
            self.user_positions[params.liquidator][reserve_id] = liquidator_position
        else:
            amount_to_liquidator: uint256 = amount_removed
            if params.sharesToLiquidator < params.sharesToLiquidate:
                amount_to_liquidator = staticcall IHub(params.hub).previewRemoveByShares(params.assetId, params.sharesToLiquidator)
            extcall IHub(params.hub).remove(params.assetId, amount_to_liquidator, params.liquidator)
    fee_shares: uint256 = params.sharesToLiquidate - params.sharesToLiquidator
    if fee_shares > 0:
        extcall IHub(params.hub).payFeeShares(params.assetId, fee_shares)
    return LiquidateCollateralResult(amountRemoved=amount_removed, isCollateralPositionEmpty=user_position.suppliedShares == 0)


@external
def liquidateCollateral(params: LiquidateCollateralParams) -> LiquidateCollateralResult:
    return self._liquidate_collateral(self.borrower, self.collateral_reserve_id, params)


@internal
def _liquidate_debt(user: address, storage_reserve_id: uint256, params: LiquidateDebtParams) -> LiquidateDebtResult:
    position: UserPosition = self.user_positions[user][storage_reserve_id]
    premium_delta: IHub.PremiumDelta = self._calculate_premium_delta(
        position,
        params.drawnSharesToLiquidate,
        params.drawnIndex,
        convert(self.risk_premium[user], uint256),
        params.premiumDebtRayToLiquidate,
    )
    drawn_amount: uint256 = WadRayMath.ray_mul_up(params.drawnSharesToLiquidate, params.drawnIndex)
    amount_to_restore: uint256 = drawn_amount + WadRayMath.from_ray_up(params.premiumDebtRayToLiquidate)
    self._safe_transfer_from(params.underlying, params.liquidator, params.hub, amount_to_restore)
    extcall IHub(params.hub).restore(params.assetId, drawn_amount, premium_delta)
    position.premiumShares = convert(convert(position.premiumShares, int256) + premium_delta.sharesDelta, uint120)
    position.premiumOffsetRay = convert(convert(position.premiumOffsetRay, int256) + premium_delta.offsetRayDelta, int200)
    drawn_120: uint120 = self._u120(params.drawnSharesToLiquidate)
    if drawn_120 > position.drawnShares:
        self._panic_arithmetic()
    position.drawnShares -= drawn_120
    debt_empty: bool = position.drawnShares == 0
    if debt_empty:
        self.is_borrowing[user][params.reserveId] = False
    self.user_positions[user][storage_reserve_id] = position
    return LiquidateDebtResult(amountRestored=amount_to_restore, premiumDelta=premium_delta, isDebtPositionEmpty=debt_empty)


@external
def liquidateDebt(params: LiquidateDebtParams) -> LiquidateDebtResult:
    return self._liquidate_debt(self.borrower, self.debt_reserve_id, params)


@internal
def _execute(params: ExecuteLiquidationParams) -> bool:
    collateral_position: UserPosition = self.user_positions[params.user][self.collateral_reserve_id]
    debt_position: UserPosition = self.user_positions[params.user][self.debt_reserve_id]
    drawn_index: uint256 = staticcall IHub(params.debtHub).getAssetDrawnIndex(params.debtAssetId)
    premium_ray: uint256 = self._calculate_premium_ray(debt_position, drawn_index)
    validate_params: ILiquidationLogic.ValidateLiquidationCallParams = ILiquidationLogic.ValidateLiquidationCallParams(
        user=params.user,
        liquidator=params.liquidator,
        collateralReserveFlags=params.collateralReserveFlags,
        debtReserveFlags=params.debtReserveFlags,
        suppliedShares=convert(collateral_position.suppliedShares, uint256),
        drawnShares=convert(debt_position.drawnShares, uint256),
        debtToCover=params.debtToCover,
        collateralFactor=convert(params.collateralDynConfig.collateralFactor, uint256),
        isUsingAsCollateral=self.using_as_collateral[params.user][params.collateralReserveId],
        healthFactor=params.healthFactor,
        receiveShares=params.receiveShares,
    )
    LiquidationLogic.validate_liquidation_call(validate_params)
    amount_params: ILiquidationLogic.CalculateLiquidationAmountsParams = ILiquidationLogic.CalculateLiquidationAmountsParams(
        collateralReserveHub=params.collateralHub,
        collateralReserveAssetId=params.collateralAssetId,
        suppliedShares=convert(collateral_position.suppliedShares, uint256),
        collateralAssetDecimals=params.collateralAssetDecimals,
        collateralAssetPrice=staticcall IAaveOracle(params.oracle).getReservePrice(params.collateralReserveId),
        drawnShares=convert(debt_position.drawnShares, uint256),
        premiumDebtRay=premium_ray,
        drawnIndex=drawn_index,
        totalDebtValueRay=params.totalDebtValueRay,
        debtAssetDecimals=params.debtAssetDecimals,
        debtAssetPrice=staticcall IAaveOracle(params.oracle).getReservePrice(params.debtReserveId),
        debtToCover=params.debtToCover,
        collateralFactor=convert(params.collateralDynConfig.collateralFactor, uint256),
        healthFactorForMaxBonus=convert(params.liquidationConfig.healthFactorForMaxBonus, uint256),
        liquidationBonusFactor=convert(params.liquidationConfig.liquidationBonusFactor, uint256),
        maxLiquidationBonus=convert(params.collateralDynConfig.maxLiquidationBonus, uint256),
        targetHealthFactor=convert(params.liquidationConfig.targetHealthFactor, uint256),
        healthFactor=params.healthFactor,
        liquidationFee=convert(params.collateralDynConfig.liquidationFee, uint256),
    )
    amounts: ILiquidationLogic.LiquidationAmounts = LiquidationLogic.calculate_liquidation_amounts(amount_params)
    collateral_result: LiquidateCollateralResult = self._liquidate_collateral(
        params.user,
        self.collateral_reserve_id,
        LiquidateCollateralParams(
            hub=params.collateralHub,
            assetId=params.collateralAssetId,
            sharesToLiquidate=amounts.collateralSharesToLiquidate,
            sharesToLiquidator=amounts.collateralSharesToLiquidator,
            liquidator=params.liquidator,
            receiveShares=params.receiveShares,
        ),
    )
    debt_result: LiquidateDebtResult = self._liquidate_debt(
        params.user,
        self.debt_reserve_id,
        LiquidateDebtParams(
            hub=params.debtHub,
            assetId=params.debtAssetId,
            underlying=params.debtUnderlying,
            reserveId=params.debtReserveId,
            drawnSharesToLiquidate=amounts.drawnSharesToLiquidate,
            premiumDebtRayToLiquidate=amounts.premiumDebtRayToLiquidate,
            drawnIndex=drawn_index,
            liquidator=params.liquidator,
        ),
    )
    log LiquidationCall(
        collateralReserveId=params.collateralReserveId,
        debtReserveId=params.debtReserveId,
        user=params.user,
        liquidator=params.liquidator,
        receiveShares=params.receiveShares,
        debtAmountRestored=debt_result.amountRestored,
        drawnSharesLiquidated=amounts.drawnSharesToLiquidate,
        premiumDelta=debt_result.premiumDelta,
        collateralAmountRemoved=collateral_result.amountRemoved,
        collateralSharesLiquidated=amounts.collateralSharesToLiquidate,
        collateralSharesToLiquidator=amounts.collateralSharesToLiquidator,
    )
    return LiquidationLogic.evaluate_deficit(
        collateral_result.isCollateralPositionEmpty,
        debt_result.isDebtPositionEmpty,
        params.activeCollateralCount,
        params.borrowCount,
    )


@external
def executeLiquidation(params: ExecuteLiquidationParams) -> bool:
    return self._execute(params)


@external
def liquidateUser(params: LiquidateUserParams) -> bool:
    collateral_reserve: Reserve = self.reserves[params.collateralReserveId]
    debt_reserve: Reserve = self.reserves[params.debtReserveId]
    collateral_position: UserPosition = self.user_positions[params.user][params.collateralReserveId]
    dynamic: DynamicReserveConfig = self.dynamic_configs[params.collateralReserveId][collateral_position.dynamicConfigKey]
    execute_params: ExecuteLiquidationParams = ExecuteLiquidationParams(
        collateralHub=collateral_reserve.hub,
        collateralAssetId=convert(collateral_reserve.assetId, uint256),
        collateralAssetDecimals=convert(collateral_reserve.decimals, uint256),
        collateralReserveId=params.collateralReserveId,
        collateralReserveFlags=collateral_reserve.flags,
        collateralDynConfig=dynamic,
        debtHub=debt_reserve.hub,
        debtAssetId=convert(debt_reserve.assetId, uint256),
        debtAssetDecimals=convert(debt_reserve.decimals, uint256),
        debtUnderlying=debt_reserve.underlying,
        debtReserveId=params.debtReserveId,
        debtReserveFlags=debt_reserve.flags,
        liquidationConfig=params.liquidationConfig,
        oracle=params.oracle,
        user=params.user,
        debtToCover=params.debtToCover,
        healthFactor=params.userAccountData.healthFactor,
        totalDebtValueRay=params.userAccountData.totalDebtValueRay,
        activeCollateralCount=params.userAccountData.activeCollateralCount,
        borrowCount=params.userAccountData.borrowCount,
        liquidator=params.liquidator,
        receiveShares=params.receiveShares,
    )
    return self._execute(execute_params)
