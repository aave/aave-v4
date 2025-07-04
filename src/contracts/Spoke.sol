// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Multicall} from 'src/misc/Multicall.sol';

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
// libraries
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';
import {PercentageMathExtended} from 'src/libraries/math/PercentageMathExtended.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';

// interfaces
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';

contract Spoke is ISpoke, Multicall, AccessManaged {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMathExtended for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;
  using LiquidationLogic for DataTypes.LiquidationConfig;
  using PositionStatus for DataTypes.PositionStatus;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = WadRayMathExtended.WAD;
  uint256 public constant MAX_LIQUIDITY_PREMIUM = 1000_00; // 1000.00%
  IPriceOracle public immutable oracle;

  mapping(address user => mapping(uint256 reserveId => DataTypes.UserPosition position))
    internal _userPositions;
  mapping(address user => DataTypes.PositionStatus positionStatus) internal _positionStatus;
  mapping(uint256 reserveId => DataTypes.Reserve reserveData) internal _reserves;
  mapping(uint256 reserveId => mapping(uint16 configKey => DataTypes.DynamicReserveConfig config))
    internal _dynamicConfig; // dictionary of dynamic configs per reserve
  DataTypes.LiquidationConfig internal _liquidationConfig;
  uint256[] public reservesList; // todo: rm, not needed
  uint256 public reserveCount;

  /**
   * @dev Constructor.
   * @dev The authority should implement the AccessManaged interface to control access.
   * @param oracleAddress The address of the price oracle contract used for asset valuations.
   * @param authority The address of the authority contract which manages permissions.
   */
  constructor(address oracleAddress, address authority) AccessManaged(authority) {
    require(oracleAddress != address(0), InvalidOracleAddress());

    oracle = IPriceOracle(oracleAddress);
    // todo move to `initialize` when adding upgradeability
    _liquidationConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
  }

  // /////
  // Governance
  // /////

  function updateLiquidationConfig(
    DataTypes.LiquidationConfig calldata liquidationConfig
  ) external restricted {
    _validateLiquidationConfig(liquidationConfig);
    _liquidationConfig = liquidationConfig;
    emit LiquidationConfigUpdated(liquidationConfig);
  }

  function addReserve(
    uint256 assetId,
    address hub,
    DataTypes.ReserveConfig calldata config,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint256) {
    require(hub != address(0), InvalidHubAddress());

    _validateReserveConfig(config);
    uint256 reserveId = reserveCount++;
    uint16 dynamicConfigKey; // 0 as first key to use

    DataTypes.Asset memory asset = ILiquidityHub(hub).getAsset(assetId);
    require(asset.underlying != address(0), AssetNotListed());

    reservesList.push(reserveId);
    _reserves[reserveId] = DataTypes.Reserve({
      reserveId: reserveId,
      assetId: assetId,
      suppliedShares: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      config: config,
      dynamicConfigKey: dynamicConfigKey,
      decimals: asset.decimals,
      underlying: asset.underlying,
      hub: ILiquidityHub(hub)
    });
    _dynamicConfig[reserveId][dynamicConfigKey] = dynamicConfig;

    emit ReserveAdded(reserveId, assetId);
    emit ReserveConfigUpdated(reserveId, config);

    return reserveId;
  }

  function updateReserveConfig(
    uint256 reserveId,
    DataTypes.ReserveConfig calldata config
  ) external restricted {
    // TODO: AccessControl, More sophisticated
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    require(reserve.underlying != address(0), ReserveNotListed());
    _validateReserveConfig(config);
    reserve.config = config;
    emit ReserveConfigUpdated(reserveId, config);
  }

  function updateDynamicReserveConfig(
    uint256 reserveId,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external restricted {
    _validateDynamicReserveConfig(dynamicConfig);
    // TODO: AccessControl, More sophisticated
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    uint16 nextConfigKey;
    // @dev overflow is desired, we implicitly invalidate & override stale config
    unchecked {
      nextConfigKey = ++reserve.dynamicConfigKey;
    }
    // todo opt: concat key to use single lookup
    _dynamicConfig[reserveId][nextConfigKey] = dynamicConfig;
    emit DynamicReserveConfigUpdated(reserveId, nextConfigKey, dynamicConfig);
    // todo emit if stale config overwritten?
  }

  // /////
  // Users
  // /////

  /// @inheritdoc ISpoke
  function supply(uint256 reserveId, uint256 amount) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[msg.sender][reserveId];

    _validateSupply(reserve);

    uint256 suppliedShares = reserve.hub.add(reserve.assetId, amount, msg.sender);

    userPosition.suppliedShares += suppliedShares;
    reserve.suppliedShares += suppliedShares;

    emit Supply(reserveId, msg.sender, suppliedShares);
  }

  /// @inheritdoc ISpoke
  function withdraw(uint256 reserveId, uint256 amount, address to) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[msg.sender][reserveId];
    uint256 assetId = reserve.assetId;
    ILiquidityHub hub = reserve.hub;

    // If uint256.max is passed, withdraw all user's supplied assets
    if (amount == type(uint256).max) {
      amount = hub.convertToSuppliedAssets(assetId, userPosition.suppliedShares);
    }
    _validateWithdraw(reserve, userPosition, amount);

    uint256 userPremiumDrawnShares = userPosition.premiumDrawnShares;
    uint256 userPremiumOffset = userPosition.premiumOffset;
    uint256 accruedPremium = hub.convertToDrawnAssets(assetId, userPremiumDrawnShares) -
      userPremiumOffset; // assets(premiumShares) - offset should never be < 0
    userPosition.premiumDrawnShares = 0;
    userPosition.premiumOffset = 0;
    userPosition.realizedPremium += accruedPremium;

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      -int256(userPremiumDrawnShares),
      -int256(userPremiumOffset),
      accruedPremium,
      0
    ); // unnecessary but we realize premium debt here
    uint256 withdrawnShares = hub.remove(assetId, amount, to);

    userPosition.suppliedShares -= withdrawnShares;
    reserve.suppliedShares -= withdrawnShares;

    // calc needs new user position, just updating base debt is enough
    uint256 newUserRiskPremium = _refreshAndValidateUserPosition(msg.sender); // validates HF

    userPremiumDrawnShares = userPosition.premiumDrawnShares = userPosition
      .baseDrawnShares
      .percentMulUp(newUserRiskPremium);
    userPremiumOffset = userPosition.premiumOffset = hub.previewOffset(
      assetId,
      userPosition.premiumDrawnShares
    );

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      int256(userPremiumDrawnShares),
      int256(userPremiumOffset),
      0,
      0
    );
    _notifyRiskPremiumUpdate(assetId, msg.sender, newUserRiskPremium);

    emit Withdraw(reserveId, msg.sender, withdrawnShares, to);
  }

  /// @inheritdoc ISpoke
  function borrow(uint256 reserveId, uint256 amount, address to) external {
    // TODO: referral code
    // TODO: onBehalfOf with credit delegation
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[msg.sender][reserveId];
    DataTypes.PositionStatus storage positionStatus = _positionStatus[msg.sender];
    uint256 assetId = reserve.assetId;
    ILiquidityHub hub = reserve.hub;

    _validateBorrow(reserve);

    if (!positionStatus.isBorrowing(reserveId)) {
      positionStatus.setBorrowing(reserveId, true);
    }

    uint256 userPremiumDrawnShares = userPosition.premiumDrawnShares;
    uint256 userPremiumOffset = userPosition.premiumOffset;
    uint256 accruedPremium = hub.convertToDrawnAssets(assetId, userPremiumDrawnShares) -
      userPremiumOffset; // assets(premiumShares) - offset should never be < 0
    userPosition.premiumDrawnShares = 0;
    userPosition.premiumOffset = 0;
    userPosition.realizedPremium += accruedPremium;

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      -int256(userPremiumDrawnShares),
      -int256(userPremiumOffset),
      accruedPremium,
      0
    ); // unnecessary but we realize premium debt here
    uint256 baseDrawnShares = hub.draw(assetId, amount, to);

    reserve.baseDrawnShares += baseDrawnShares;
    userPosition.baseDrawnShares += baseDrawnShares;

    // calc needs new user position, just updating base debt is enough
    uint256 newUserRiskPremium = _refreshAndValidateUserPosition(msg.sender); // validates HF

    userPremiumDrawnShares = userPosition.premiumDrawnShares = userPosition
      .baseDrawnShares
      .percentMulUp(newUserRiskPremium);
    userPremiumOffset = userPosition.premiumOffset = hub.previewOffset(
      assetId,
      userPosition.premiumDrawnShares
    );

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      int256(userPremiumDrawnShares),
      int256(userPremiumOffset),
      0,
      0
    );
    _notifyRiskPremiumUpdate(assetId, msg.sender, newUserRiskPremium);

    emit Borrow(reserveId, msg.sender, baseDrawnShares, to);
  }

  /// @inheritdoc ISpoke
  function repay(uint256 reserveId, uint256 amount) external {
    /// @dev TODO: onBehalfOf
    DataTypes.UserPosition storage userPosition = _userPositions[msg.sender][reserveId];
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    uint256 assetId = reserve.assetId;
    ILiquidityHub hub = reserve.hub;

    _validateRepay(reserve);
    (uint256 baseDebt, uint256 premiumDebt) = _getUserDebt(hub, assetId, userPosition);
    (uint256 baseDebtRestored, uint256 premiumDebtRestored) = _calculateRestoreAmount(
      baseDebt,
      premiumDebt,
      amount
    );

    uint256 userPremiumDrawnShares = userPosition.premiumDrawnShares;
    uint256 userPremiumOffset = userPosition.premiumOffset;
    uint256 accruedPremium = premiumDebt - userPosition.realizedPremium;

    userPosition.premiumDrawnShares = 0;
    userPosition.premiumOffset = 0;
    userPosition.realizedPremium = premiumDebt - premiumDebtRestored;

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      -int256(userPremiumDrawnShares),
      -int256(userPremiumOffset),
      accruedPremium,
      premiumDebtRestored
    ); // we settle premium debt here
    uint256 restoredShares = hub.restore(
      assetId,
      baseDebtRestored,
      premiumDebtRestored,
      msg.sender
    ); // we settle base debt here

    reserve.baseDrawnShares -= restoredShares;
    userPosition.baseDrawnShares -= restoredShares;

    (uint256 newUserRiskPremium, , , , ) = _calculateUserAccountData(msg.sender);

    userPremiumDrawnShares = userPosition.premiumDrawnShares = userPosition
      .baseDrawnShares
      .percentMulUp(newUserRiskPremium);
    userPremiumOffset = userPosition.premiumOffset = hub.previewOffset(
      assetId,
      userPosition.premiumDrawnShares
    );

    if (userPosition.baseDrawnShares == 0) {
      _positionStatus[msg.sender].setBorrowing(reserveId, false);
    }

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      int256(userPremiumDrawnShares),
      int256(userPremiumOffset),
      0,
      0
    );
    _notifyRiskPremiumUpdate(assetId, msg.sender, newUserRiskPremium);

    emit Repay(reserveId, msg.sender, restoredShares);
  }

  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external {
    address[] memory users = new address[](1);
    users[0] = user;

    uint256[] memory debtsToCover = new uint256[](1);
    debtsToCover[0] = debtToCover;

    (
      address collateralAsset,
      address debtAsset,
      uint256 debtToLiquidate,
      uint256 collateralToLiquidate
    ) = _executeLiquidationCall(
        _reserves[collateralReserveId],
        _reserves[debtReserveId],
        users,
        debtsToCover,
        msg.sender
      );

    // TODO: emit liq protocol fee shares in event
    emit LiquidationCall(
      collateralAsset,
      debtAsset,
      user,
      debtToLiquidate,
      collateralToLiquidate,
      msg.sender
    );
  }

  /// @inheritdoc ISpoke
  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external {
    DataTypes.PositionStatus storage positionStatus = _positionStatus[msg.sender];

    // process only if collateral status changes
    if (positionStatus.isUsingAsCollateral(reserveId) == usingAsCollateral) {
      return;
    }

    DataTypes.Reserve storage reserve = _reserves[reserveId];
    _validateSetUsingAsCollateral(reserve, reserveId, usingAsCollateral);

    positionStatus.setUsingAsCollateral(reserveId, usingAsCollateral);

    if (usingAsCollateral) {
      _refreshDynamicConfig(msg.sender, reserveId);
    } else {
      // If unsetting, check HF and update user rp
      uint256 newUserRiskPremium = _refreshAndValidateUserPosition(msg.sender); // validates HF
      _notifyRiskPremiumUpdate(type(uint256).max, msg.sender, newUserRiskPremium);
    }
    emit UsingAsCollateral(reserveId, msg.sender, usingAsCollateral);
  }

  /// @inheritdoc ISpoke
  function updateUserRiskPremium(address user) external {
    (uint256 userRiskPremium, , , , ) = _calculateUserAccountData(user);
    bool premiumIncrease = _notifyRiskPremiumUpdate(type(uint256).max, user, userRiskPremium);
    // check permissions if premium increases and not called by user
    if (premiumIncrease && user != msg.sender) {
      _checkCanCall(_msgSender(), _msgData());
    }
    emit UserRiskPremiumUpdate(user, userRiskPremium);
  }

  function getUsingAsCollateral(uint256 reserveId, address user) external view returns (bool) {
    return _positionStatus[user].isUsingAsCollateral(reserveId);
  }

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    return
      _getUserDebt(
        _reserves[reserveId].hub,
        _reserves[reserveId].assetId,
        _userPositions[user][reserveId]
      );
  }

  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getUserDebt(
      _reserves[reserveId].hub,
      _reserves[reserveId].assetId,
      _userPositions[user][reserveId]
    );
    return baseDebt + premiumDebt;
  }

  function getReserveSuppliedAmount(uint256 reserveId) external view returns (uint256) {
    return
      _reserves[reserveId].hub.convertToSuppliedAssets(
        _reserves[reserveId].assetId,
        _reserves[reserveId].suppliedShares
      );
  }

  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256) {
    return _reserves[reserveId].suppliedShares;
  }

  function getUserSuppliedAmount(uint256 reserveId, address user) public view returns (uint256) {
    return
      _reserves[reserveId].hub.convertToSuppliedAssets(
        _reserves[reserveId].assetId,
        _userPositions[user][reserveId].suppliedShares
      );
  }

  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256) {
    return _userPositions[user][reserveId].suppliedShares;
  }

  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getReserveDebt(_reserves[reserveId]);
    return (baseDebt, premiumDebt);
  }

  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getReserveDebt(_reserves[reserveId]);
    return baseDebt + premiumDebt;
  }

  function getReserveRiskPremium(uint256 reserveId) external view returns (uint256) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    return reserve.premiumDrawnShares.rayDiv(reserve.baseDrawnShares); // trailing
  }

  function getUserRiskPremium(address user) external view returns (uint256) {
    (uint256 userRiskPremium, , , , ) = _calculateUserAccountData(user);
    return userRiskPremium;
  }

  function getHealthFactor(address user) external view returns (uint256) {
    (, , uint256 healthFactor, , ) = _calculateUserAccountData(user);
    return healthFactor;
  }

  function getVariableLiquidationBonus(
    uint256 reserveId,
    uint256 healthFactor
  ) public view returns (uint256) {
    // if healthFactorForMaxBonus is 0, always returns liquidationBonus
    return
      _liquidationConfig.calculateVariableLiquidationBonus(
        healthFactor,
        _reserves[reserveId].config.liquidationBonus,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
      );
  }

  function getLiquidationConfig() external view returns (DataTypes.LiquidationConfig memory) {
    return _liquidationConfig;
  }

  function getUserAccountData(
    address user
  )
    external
    view
    returns (
      uint256 userRiskPremium,
      uint256 avgCollateralFactor,
      uint256 healthFactor,
      uint256 totalCollateralInBaseCurrency,
      uint256 totalDebtInBaseCurrency
    )
  {
    // todo separate getter with refreshed config for users trying to incrementally build hf?
    (
      userRiskPremium,
      avgCollateralFactor,
      healthFactor,
      totalCollateralInBaseCurrency,
      totalDebtInBaseCurrency
    ) = _calculateUserAccountData(user);
  }

  function getReserve(uint256 reserveId) external view returns (DataTypes.Reserve memory) {
    return _reserves[reserveId];
  }

  function getReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.ReserveConfig memory) {
    return _reserves[reserveId].config;
  }

  function getDynamicReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.DynamicReserveConfig memory) {
    return _dynamicConfig[reserveId][_reserves[reserveId].dynamicConfigKey];
  }

  function getDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey
  ) external view returns (DataTypes.DynamicReserveConfig memory) {
    // @dev we do not revert if key is unset
    return _dynamicConfig[reserveId][configKey];
  }

  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (DataTypes.UserPosition memory) {
    return _userPositions[user][reserveId];
  }

  // internal
  function _validateSupply(DataTypes.Reserve storage reserve) internal view {
    require(reserve.underlying != address(0), ReserveNotListed());
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    require(!reserve.config.frozen, ReserveFrozen());
  }

  function _validateWithdraw(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage userPosition,
    uint256 amount
  ) internal view {
    require(reserve.underlying != address(0), ReserveNotListed());
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    uint256 suppliedAmount = reserve.hub.convertToSuppliedAssets(
      reserve.assetId,
      userPosition.suppliedShares
    );
    require(amount <= suppliedAmount, InsufficientSupply(suppliedAmount));
  }

  function _validateBorrow(DataTypes.Reserve storage reserve) internal view {
    require(reserve.underlying != address(0), ReserveNotListed());
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    require(!reserve.config.frozen, ReserveFrozen());
    require(reserve.config.borrowable, ReserveNotBorrowable(reserve.reserveId));
    // HF checked at the end of borrow action
  }

  // TODO: Place this and LH equivalent in a generic logic library
  function _validateRepay(DataTypes.Reserve storage reserve) internal view {
    require(reserve.underlying != address(0), ReserveNotListed());
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    // todo validate user not trying to repay more
  }

  function _refreshAndValidateUserPosition(address user) internal returns (uint256) {
    // @dev refresh user position dynamic config only on borrow, withdraw, disableUsingAsCollateral
    _refreshDynamicConfig(user); // opt: merge with _calculateUserAccountData
    (uint256 userRiskPremium, , uint256 healthFactor, , ) = _calculateUserAccountData(user);
    require(healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, HealthFactorBelowThreshold());
    return userRiskPremium;
  }

  function _validateReserveConfig(DataTypes.ReserveConfig calldata config) internal pure {
    require(
      config.liquidationBonus >= PercentageMathExtended.PERCENTAGE_FACTOR,
      InvalidLiquidationBonus()
    ); // min 100.00%
    require(config.liquidityPremium <= MAX_LIQUIDITY_PREMIUM, InvalidLiquidityPremium()); // max 1000.00%
    require(
      config.liquidationFee <= PercentageMathExtended.PERCENTAGE_FACTOR,
      InvalidLiquidationFee()
    );
  }

  function _validateDynamicReserveConfig(
    DataTypes.DynamicReserveConfig calldata config
  ) internal pure {
    require(
      config.collateralFactor <= PercentageMathExtended.PERCENTAGE_FACTOR,
      InvalidCollateralFactor()
    ); // max 100.00%
  }

  function _validateLiquidationConfig(DataTypes.LiquidationConfig calldata config) internal pure {
    _validateCloseFactor(config.closeFactor);
    require(
      config.liquidationBonusFactor <= PercentageMathExtended.PERCENTAGE_FACTOR,
      InvalidLiquidationBonusFactor()
    );
    require(
      config.healthFactorForMaxBonus < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      InvalidHealthFactorForMaxBonus()
    );
  }

  function _validateCloseFactor(uint256 closeFactor) internal pure {
    require(closeFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, InvalidCloseFactor());
  }

  function _validateLiquidationCall(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    address user,
    uint256 debtToCover,
    uint256 totalDebt,
    uint256 healthFactor,
    uint256 collateralFactor
  ) internal view {
    require(debtToCover > 0, InvalidDebtToCover());
    require(
      collateralReserve.underlying != address(0) && debtReserve.underlying != address(0),
      ReserveNotListed()
    );
    require(collateralReserve.config.active && debtReserve.config.active, ReserveNotActive());
    require(!collateralReserve.config.paused && !debtReserve.config.paused, ReservePaused());
    require(healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD, HealthFactorNotBelowThreshold());
    bool isCollateralEnabled = _positionStatus[user].isUsingAsCollateral(
      collateralReserve.reserveId
    ) && collateralFactor != 0;
    require(isCollateralEnabled, CollateralCannotBeLiquidated());
    require(totalDebt > 0, SpecifiedCurrencyNotBorrowedByUser());
  }

  /**
   * @dev Validates the reserve can be set as collateral.
   * @dev Collateral can be disabled if the reserve is frozen but not enabled.
   * @param reserve The reserve to be set as collateral.
   * @param reserveId The identifier of the reserve.
   * @param usingAsCollateral True if enables the reserve as collateral, false otherwise.
   */
  function _validateSetUsingAsCollateral(
    DataTypes.Reserve storage reserve,
    uint256 reserveId,
    bool usingAsCollateral
  ) internal view {
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    require(reserve.config.collateral, ReserveCannotBeUsedAsCollateral(reserveId));
    // deactivation should be allowed
    require(!usingAsCollateral || !reserve.config.frozen, ReserveFrozen());
  }

  // @dev allows donation on base debt
  function _calculateRestoreAmount(
    uint256 baseDebt,
    uint256 premiumDebt,
    uint256 amount
  ) internal pure returns (uint256, uint256) {
    if (amount >= baseDebt + premiumDebt) {
      return (baseDebt, premiumDebt);
    }
    if (amount <= premiumDebt) {
      return (0, amount);
    }
    return (amount - premiumDebt, premiumDebt);
  }

  function _refreshPremiumDebt(
    DataTypes.Reserve storage reserve,
    address userAddress,
    uint256 assetId,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) internal {
    _refresh(
      reserve,
      userAddress,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
    reserve.hub.refreshPremiumDebt(
      assetId,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
  }

  function _refresh(
    DataTypes.Reserve storage reserve,
    address userAddress,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) internal {
    reserve.premiumDrawnShares = _add(reserve.premiumDrawnShares, premiumDrawnSharesDelta);
    reserve.premiumOffset = _add(reserve.premiumOffset, premiumOffsetDelta);
    reserve.realizedPremium = reserve.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    emit RefreshPremiumDebt(
      reserve.reserveId,
      userAddress,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
  }

  /**
   * @dev User rp calc runs until the first of either debt or collateral is exhausted
   * @param user address of the user
   * @return userRiskPremium
   * @return avgCollateralFactor
   * @return healthFactor
   * @return totalCollateralInBaseCurrency
   * @return totalDebtInBaseCurrency
   */
  function _calculateUserAccountData(
    address user
  ) internal view returns (uint256, uint256, uint256, uint256, uint256) {
    DataTypes.CalculateUserAccountDataVars memory vars;
    uint256 reservesListLength = reservesList.length;
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];

    while (vars.reserveId < reservesListLength) {
      DataTypes.UserPosition storage userPosition = _userPositions[user][vars.reserveId];

      if (!positionStatus.isUsingAsCollateralOrBorrowing(vars.reserveId)) {
        unchecked {
          ++vars.reserveId;
        }
        continue;
      }
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
      vars.assetId = reserve.assetId;
      ILiquidityHub hub = reserve.hub;

      vars.assetPrice = oracle.getReservePrice(vars.reserveId);
      unchecked {
        vars.assetUnit = 10 ** reserve.decimals;
      }

      if (positionStatus.isUsingAsCollateral(vars.reserveId)) {
        // @dev opt: this can be extracted by counting number of set bits in a supplied (only) bitmap saving one loop
        unchecked {
          ++vars.collateralReserveCount;
        }
      }

      if (positionStatus.isBorrowing(vars.reserveId)) {
        vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
          userPosition,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit,
          hub
        );
      }

      unchecked {
        ++vars.reserveId;
      }
    }

    // @dev only allocate required memory at the cost of an extra loop
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(vars.collateralReserveCount);
    vars.i = 0;
    vars.reserveId = 0;
    while (vars.reserveId < reservesListLength) {
      DataTypes.UserPosition storage userPosition = _userPositions[user][vars.reserveId];
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
      ILiquidityHub hub = reserve.hub;
      if (positionStatus.isUsingAsCollateral(vars.reserveId)) {
        DataTypes.DynamicReserveConfig storage dynConfig = _dynamicConfig[vars.reserveId][
          userPosition.configKey
        ];

        vars.assetId = reserve.assetId;
        vars.liquidityPremium = reserve.config.liquidityPremium;
        vars.assetPrice = oracle.getReservePrice(vars.reserveId);
        unchecked {
          vars.assetUnit = 10 ** reserve.decimals;
        }
        vars.userCollateralInBaseCurrency = _getUserBalanceInBaseCurrency(
          userPosition,
          vars.assetId,
          hub,
          vars.assetPrice,
          vars.assetUnit
        );

        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        list.add(vars.i, vars.liquidityPremium, vars.userCollateralInBaseCurrency);
        vars.avgCollateralFactor += vars.userCollateralInBaseCurrency * dynConfig.collateralFactor;

        unchecked {
          ++vars.i;
        }
      }

      unchecked {
        ++vars.reserveId;
      }
    }

    // at this point avgCollateralFactor is a weighted sum of collateral scaled by collateralFactor
    // (avgCollateralFactor / totalCollateral) * totalCollateral can be simplified to avgCollateralFactor
    // strip BPS factor from result, because running avgCollateralFactor sum has been scaled by collateralFactor (in BPS) above
    vars.healthFactor = vars.totalDebtInBaseCurrency == 0
      ? type(uint256).max
      : vars.avgCollateralFactor.wadDiv(vars.totalDebtInBaseCurrency).fromBps(); // HF of 1 -> 1e18

    // divide by total collateral to get avg collateral factor in wad
    vars.avgCollateralFactor = vars.totalCollateralInBaseCurrency == 0
      ? 0
      : vars.avgCollateralFactor.wadDiv(vars.totalCollateralInBaseCurrency);

    vars.debtCounterInBaseCurrency = vars.totalDebtInBaseCurrency;

    list.sortByKey(); // sort by liquidity premium
    vars.i = 0;
    // @dev from this point onwards, `collateralCounterInBaseCurrency` represents running collateral
    // value used in risk premium, `debtCounterInBaseCurrency` represents running outstanding debt
    while (vars.i < vars.collateralReserveCount && vars.debtCounterInBaseCurrency > 0) {
      if (vars.debtCounterInBaseCurrency == 0) break;
      (vars.liquidityPremium, vars.userCollateralInBaseCurrency) = list.get(vars.i);
      if (vars.userCollateralInBaseCurrency > vars.debtCounterInBaseCurrency) {
        vars.userCollateralInBaseCurrency = vars.debtCounterInBaseCurrency;
      }
      vars.userRiskPremium += vars.userCollateralInBaseCurrency * vars.liquidityPremium;
      vars.collateralCounterInBaseCurrency += vars.userCollateralInBaseCurrency;
      vars.debtCounterInBaseCurrency -= vars.userCollateralInBaseCurrency;
      unchecked {
        ++vars.i;
      }
    }

    if (vars.collateralCounterInBaseCurrency > 0) {
      vars.userRiskPremium = vars.userRiskPremium / vars.collateralCounterInBaseCurrency;
    }

    return (
      vars.userRiskPremium,
      vars.avgCollateralFactor,
      vars.healthFactor,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency
    );
  }

  function _getUserDebtInBaseCurrency(
    DataTypes.UserPosition storage userPosition,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit,
    ILiquidityHub hub
  ) internal view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getUserDebt(hub, assetId, userPosition);
    return ((baseDebt + premiumDebt) * assetPrice).wadify() / assetUnit;
  }

  function _getUserBalanceInBaseCurrency(
    DataTypes.UserPosition storage userPosition,
    uint256 assetId,
    ILiquidityHub hub,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return
      (hub.convertToSuppliedAssets(assetId, userPosition.suppliedShares) * assetPrice).wadify() /
      assetUnit;
  }

  function _getUserDebt(
    ILiquidityHub hub,
    uint256 assetId,
    DataTypes.UserPosition storage userPosition
  ) internal view returns (uint256, uint256) {
    uint256 accruedPremium = hub.convertToDrawnAssets(assetId, userPosition.premiumDrawnShares) -
      userPosition.premiumOffset;
    return (
      hub.convertToDrawnAssets(assetId, userPosition.baseDrawnShares),
      userPosition.realizedPremium + accruedPremium
    );
  }

  // todo rm reserve accounting here & fetch from hub
  function _getReserveDebt(
    DataTypes.Reserve storage reserve
  ) internal view returns (uint256, uint256) {
    uint256 assetId = reserve.assetId;
    ILiquidityHub hub = reserve.hub;
    uint256 accruedPremium = hub.convertToDrawnAssets(assetId, reserve.premiumDrawnShares) -
      reserve.premiumOffset;
    return (
      hub.convertToDrawnAssets(assetId, reserve.baseDrawnShares),
      reserve.realizedPremium + accruedPremium
    );
  }

  // todo optimize, merge logic duped borrow/repay, rename
  /**
   * @dev Trigger risk premium update on all drawn reserves of `user` except the reserve's corresponding
   * to `assetIdToAvoid` as those are expected to be updated outside of this method.
   */
  function _notifyRiskPremiumUpdate(
    uint256 assetIdToAvoid,
    address user,
    uint256 newUserRiskPremium
  ) internal returns (bool) {
    DataTypes.NotifyRiskPremiumUpdateVars memory vars;
    vars.reserveCount = reserveCount;
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];
    while (vars.reserveId < vars.reserveCount) {
      DataTypes.UserPosition storage userPosition = _userPositions[user][vars.reserveId];
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
      uint256 assetId = reserve.assetId;
      ILiquidityHub hub = reserve.hub;
      // todo keep borrowed assets in transient storage/pass through?
      if (positionStatus.isBorrowing(vars.reserveId) && assetId != assetIdToAvoid) {
        uint256 oldUserPremiumDrawnShares = userPosition.premiumDrawnShares;
        uint256 oldUserPremiumOffset = userPosition.premiumOffset;
        uint256 accruedUserPremium = hub.convertToDrawnAssets(assetId, oldUserPremiumDrawnShares) -
          oldUserPremiumOffset;

        userPosition.premiumDrawnShares = userPosition.baseDrawnShares.percentMulUp(
          newUserRiskPremium
        );
        userPosition.premiumOffset = hub.previewOffset(assetId, userPosition.premiumDrawnShares);
        userPosition.realizedPremium += accruedUserPremium;

        int256 premiumDrawnSharesDelta = _signedDiff(
          userPosition.premiumDrawnShares,
          oldUserPremiumDrawnShares
        );
        if (!vars.premiumIncrease) vars.premiumIncrease = premiumDrawnSharesDelta > 0;

        _refreshPremiumDebt(
          reserve,
          user,
          assetId,
          premiumDrawnSharesDelta,
          _signedDiff(userPosition.premiumOffset, oldUserPremiumOffset),
          accruedUserPremium,
          0
        );
      }
      unchecked {
        ++vars.reserveId;
      }
    }
    return vars.premiumIncrease;
  }

  function _refreshDynamicConfig(address user) internal {
    uint256 reservesListLength = reservesList.length;
    uint256 reserveId;
    while (reserveId < reservesListLength) {
      if (_positionStatus[user].isUsingAsCollateral(reserveId)) {
        _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
      }
      unchecked {
        ++reserveId;
      }
    }
    emit UserDynamicConfigRefreshed(user);
  }

  function _refreshDynamicConfig(address user, uint256 reserveId) internal {
    _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
    emit UserDynamicConfigRefreshed(user, reserveId);
  }

  /// @return collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation.
  /// @return debtAsset The address of the underlying borrowed asset to be repaid with the liquidation.
  /// @return totalDebtToLiquidate The total amount of debt to be repaid.
  /// @return collateralToLiquidate The amount of collateral to liquidate.
  function _executeLiquidationCall(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    address[] memory users,
    uint256[] memory debtsToCover,
    address liquidator
  ) internal returns (address, address, uint256, uint256) {
    uint256 usersLength = users.length;
    require(usersLength == debtsToCover.length, UsersAndDebtLengthMismatch());

    ILiquidityHub collateralReserveHub = collateralReserve.hub;
    ILiquidityHub debtReserveHub = debtReserve.hub;

    DataTypes.ExecuteLiquidationLocalVars memory vars;

    vars.debtReserveId = debtReserve.reserveId;
    vars.collateralReserveId = collateralReserve.reserveId;

    while (vars.i < usersLength) {
      DataTypes.UserPosition storage userCollateralPosition = _userPositions[users[vars.i]][
        collateralReserve.reserveId
      ];
      DataTypes.UserPosition storage userDebtPosition = _userPositions[users[vars.i]][
        debtReserve.reserveId
      ];

      vars.collateralAssetId = collateralReserve.assetId;
      vars.debtAssetId = debtReserve.assetId;

      (vars.baseDebt, vars.premiumDebt) = _getUserDebt(
        debtReserveHub,
        vars.debtAssetId,
        userDebtPosition
      );

      (
        vars.collateralToLiquidate,
        vars.liquidationFeeAmount,
        vars.baseDebtToLiquidate,
        vars.premiumDebtToLiquidate
      ) = _calculateLiquidationParameters(
        collateralReserve,
        debtReserve,
        users[vars.i],
        debtsToCover[vars.i],
        vars.baseDebt,
        vars.premiumDebt
      );

      // settle debt reserve's premium debt
      vars.userPremiumDrawnShares = userDebtPosition.premiumDrawnShares;
      vars.userPremiumOffset = userDebtPosition.premiumOffset;
      vars.userRealizedPremium = userDebtPosition.realizedPremium;

      {
        uint256 accruedPremium = vars.premiumDebt - vars.userRealizedPremium;

        userDebtPosition.premiumDrawnShares = 0;
        userDebtPosition.premiumOffset = 0;
        userDebtPosition.realizedPremium = vars.premiumDebt - vars.premiumDebtToLiquidate;

        _refreshPremiumDebt(
          debtReserve,
          users[vars.i],
          vars.debtAssetId,
          -int256(vars.userPremiumDrawnShares),
          -int256(vars.userPremiumOffset),
          accruedPremium,
          vars.premiumDebtToLiquidate
        ); // settle premium debt
      }

      // todo: rm later to opt
      // optional: settle collateral reserve's premium debt
      vars.userPremiumDrawnShares = userCollateralPosition.premiumDrawnShares;
      vars.userPremiumOffset = userCollateralPosition.premiumOffset;
      vars.userRealizedPremium =
        collateralReserveHub.convertToDrawnAssets(
          vars.collateralAssetId,
          vars.userPremiumDrawnShares
        ) -
        vars.userPremiumOffset; // assets(premiumShares) - offset should never be < 0

      userCollateralPosition.premiumDrawnShares = 0;
      userCollateralPosition.premiumOffset = 0;
      userCollateralPosition.realizedPremium += vars.userRealizedPremium;

      _refreshPremiumDebt(
        collateralReserve,
        users[vars.i],
        vars.collateralAssetId,
        -int256(vars.userPremiumDrawnShares),
        -int256(vars.userPremiumOffset),
        vars.userRealizedPremium,
        0
      ); // unnecessary but settle premium debt here for consistency

      // repay debt
      vars.restoredShares = debtReserveHub.restore(
        vars.debtAssetId,
        vars.baseDebtToLiquidate,
        vars.premiumDebtToLiquidate,
        liquidator
      );

      // debt accounting
      userDebtPosition.baseDrawnShares -= vars.restoredShares;
      vars.totalRestoredShares += vars.restoredShares;

      // expected total withdrawn shares includes liquidation fee
      vars.withdrawnShares = collateralReserveHub.convertToSuppliedSharesUp(
        vars.collateralAssetId,
        vars.liquidationFeeAmount + vars.collateralToLiquidate
      );
      // remove collateral, send liquidated collateral directly to liquidator
      vars.liquidatedSuppliedShares = collateralReserveHub.remove(
        vars.collateralAssetId,
        vars.collateralToLiquidate,
        liquidator
      );
      vars.liquidationFeeShares = vars.withdrawnShares - vars.liquidatedSuppliedShares;

      // collateral accounting
      userCollateralPosition.suppliedShares -= vars.withdrawnShares;

      // TODO: realize bad debt
      (vars.newUserRiskPremium, , , , ) = _calculateUserAccountData(users[vars.i]);

      // refresh debt reserve premium
      vars.userPremiumDrawnShares = userDebtPosition.premiumDrawnShares = userDebtPosition
        .baseDrawnShares
        .percentMulUp(vars.newUserRiskPremium);
      vars.userPremiumOffset = userDebtPosition.premiumOffset = debtReserveHub.previewOffset(
        vars.debtAssetId,
        userDebtPosition.premiumDrawnShares
      );
      vars.totalUserDebtPremiumDrawnSharesDelta += int256(vars.userPremiumDrawnShares);
      vars.totalUserDebtPremiumOffsetDelta += int256(vars.userPremiumOffset);

      _refresh(
        debtReserve,
        users[vars.i],
        int256(vars.userPremiumDrawnShares),
        int256(vars.userPremiumOffset),
        0,
        0
      );

      if (userDebtPosition.baseDrawnShares == 0) {
        DataTypes.PositionStatus storage positionStatus = _positionStatus[users[vars.i]];
        positionStatus.setBorrowing(vars.debtReserveId, false);
      }

      // refresh collateral reserve premium
      vars.userPremiumDrawnShares = userCollateralPosition
        .premiumDrawnShares = userCollateralPosition.baseDrawnShares.percentMulUp(
        vars.newUserRiskPremium
      );
      vars.userPremiumOffset = userCollateralPosition.premiumOffset = collateralReserveHub
        .previewOffset(vars.collateralAssetId, userCollateralPosition.premiumDrawnShares);
      vars.totalUserCollateralPremiumDrawnSharesDelta += int256(vars.userPremiumDrawnShares);
      vars.totalUserCollateralPremiumOffsetDelta += int256(vars.userPremiumOffset);

      _refresh(
        collateralReserve,
        users[vars.i],
        int256(vars.userPremiumDrawnShares),
        int256(vars.userPremiumOffset),
        0,
        0
      );

      _notifyRiskPremiumUpdate(vars.debtAssetId, users[vars.i], vars.newUserRiskPremium);

      vars.totalWithdrawnShares += vars.withdrawnShares;
      vars.totalCollateralToLiquidate += vars.collateralToLiquidate;
      vars.totalLiquidationFeeShares += vars.liquidationFeeShares;
      vars.totalDebtToLiquidate += vars.baseDebtToLiquidate + vars.premiumDebtToLiquidate;

      unchecked {
        ++vars.i;
      }
    }

    if (vars.totalLiquidationFeeShares > 0) {
      collateralReserveHub.payFee(vars.collateralAssetId, vars.totalLiquidationFeeShares);
    }

    // TODO: rm when dupe reserve accounting is rm
    debtReserve.baseDrawnShares -= vars.totalRestoredShares;
    collateralReserve.suppliedShares -= vars.totalWithdrawnShares;

    collateralReserveHub.refreshPremiumDebt(
      vars.debtAssetId,
      vars.totalUserDebtPremiumDrawnSharesDelta,
      vars.totalUserDebtPremiumOffsetDelta,
      0,
      0
    );
    collateralReserveHub.refreshPremiumDebt(
      vars.collateralAssetId,
      vars.totalUserCollateralPremiumDrawnSharesDelta,
      vars.totalUserCollateralPremiumOffsetDelta,
      0,
      0
    );

    return (
      collateralReserve.underlying,
      debtReserve.underlying,
      vars.totalDebtToLiquidate,
      vars.totalCollateralToLiquidate
    );
  }

  /// @return actualCollateralToLiquidate The amount of collateral to liquidate.
  /// @return liquidationFeeAmount The amount of protocol fee.
  /// @return baseDebtToLiquidate The amount of base debt to repay.
  /// @return premiumDebtToLiquidate The amount of premium debt to repay.
  function _calculateLiquidationParameters(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    address user,
    uint256 debtToCover,
    uint256 baseDebt,
    uint256 premiumDebt
  ) internal view returns (uint256, uint256, uint256, uint256) {
    DataTypes.LiquidationCallLocalVars memory vars;
    vars.collateralReserveId = collateralReserve.reserveId;
    vars.debtReserveId = debtReserve.reserveId;
    vars.userCollateralBalance = getUserSuppliedAmount(vars.collateralReserveId, user);
    vars.totalDebt = baseDebt + premiumDebt;
    vars.collateralFactor = _dynamicConfig[vars.collateralReserveId][
      _userPositions[user][vars.collateralReserveId].configKey
    ].collateralFactor;

    (
      ,
      ,
      vars.healthFactor,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency
    ) = _calculateUserAccountData(user);

    _validateLiquidationCall(
      collateralReserve,
      debtReserve,
      user,
      debtToCover,
      vars.totalDebt,
      vars.healthFactor,
      vars.collateralFactor
    );

    vars.debtAssetPrice = oracle.getReservePrice(vars.debtReserveId);
    vars.debtAssetUnit = 10 ** debtReserve.decimals;
    vars.liquidationBonus = getVariableLiquidationBonus(
      vars.collateralReserveId,
      vars.healthFactor
    );
    vars.closeFactor = _liquidationConfig.closeFactor;
    vars.collateralAssetPrice = oracle.getReservePrice(vars.collateralReserveId);
    vars.collateralAssetUnit = 10 ** collateralReserve.decimals;
    vars.liquidationFee = collateralReserve.config.liquidationFee;

    vars.actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate({
      debtToCover: debtToCover,
      params: vars
    });

    (vars.actualCollateralToLiquidate, vars.actualDebtToLiquidate, vars.liquidationFeeAmount) = vars
      .calculateAvailableCollateralToLiquidate();

    (vars.baseDebtToLiquidate, vars.premiumDebtToLiquidate) = _calculateRestoreAmount(
      baseDebt,
      premiumDebt,
      vars.actualDebtToLiquidate
    );

    return (
      vars.actualCollateralToLiquidate,
      vars.liquidationFeeAmount,
      vars.baseDebtToLiquidate,
      vars.premiumDebtToLiquidate
    );
  }

  // handles underflow
  function _add(uint256 a, int256 b) internal pure returns (uint256) {
    if (b >= 0) return a + uint256(b);
    return a - uint256(-b);
  }

  // todo move to MathUtils
  function _signedDiff(uint256 a, uint256 b) internal pure returns (int256) {
    return int256(a) - int256(b); // todo use safeCast when amounts packed to uint112/uint128
  }
}
