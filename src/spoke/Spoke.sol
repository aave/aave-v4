// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {AccessManagedUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/AccessManagedUpgradeable.sol';
import {SafeTransferLib} from 'src/dependencies/solady/SafeTransferLib.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {UserPositionDebt} from 'src/spoke/libraries/UserPositionDebt.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpokeBase, ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title Spoke
/// @author Aave Labs
/// @notice Handles risk configuration & borrowing strategy for reserves and user positions.
/// @dev Each reserve can be associated with a separate Hub.
abstract contract Spoke is ISpoke, Multicall, NoncesKeyed, AccessManagedUpgradeable, EIP712 {
  using SafeCast for *;
  using SafeTransferLib for address;
  using WadRayMath for *;
  using PercentageMath for *;
  using KeyValueList for KeyValueList.List;
  using PositionStatusMap for *;
  using MathUtils for *;
  using LiquidationLogic for *;
  using UserPositionDebt for ISpoke.UserPosition;

  /// @inheritdoc ISpoke
  bytes32 public constant SET_USER_POSITION_MANAGER_TYPEHASH =
    // keccak256('SetUserPositionManager(address positionManager,address user,bool approve,uint256 nonce,uint256 deadline)')
    0x758d23a3c07218b7ea0b4f7f63903c4e9d5cbde72d3bcfe3e9896639025a0214;

  /// @inheritdoc ISpoke
  address public immutable ORACLE;

  /// @dev The maximum allowed value for an asset identifier (inclusive).
  uint256 internal constant MAX_ALLOWED_ASSET_ID = type(uint16).max;

  /// @dev The maximum allowed collateral risk value for a reserve, expressed in BPS (e.g. 100_00 is 100.00%).
  uint24 internal constant MAX_ALLOWED_COLLATERAL_RISK = 1000_00;

  /// @dev The maximum allowed value for a dynamic configuration key (inclusive).
  uint256 internal constant MAX_ALLOWED_DYNAMIC_CONFIG_KEY = type(uint24).max;

  /// @dev The minimum health factor below which a position is considered unhealthy and subject to liquidation.
  /// @dev Expressed in WAD (18 decimals) (e.g. 1e18 is 1.00).
  uint64 internal constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD =
    LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;

  /// @dev The maximum amount considered as dust for a user's collateral and debt balances after a liquidation.
  /// @dev Expressed in USD with 26 decimals.
  uint256 internal constant DUST_LIQUIDATION_THRESHOLD =
    LiquidationLogic.DUST_LIQUIDATION_THRESHOLD;

  /// @dev The number of decimals used by the oracle.
  uint8 internal constant ORACLE_DECIMALS = 8;

  /// @dev Number of reserves listed in the Spoke.
  uint256 internal _reserveCount;

  /// @dev Map of user addresses and reserve identifiers to user positions.
  mapping(address user => mapping(uint256 reserveId => UserPosition)) internal _userPositions;

  /// @dev Map of user addresses to their position status.
  mapping(address user => PositionStatus) internal _positionStatus;

  /// @dev Map of reserve identifiers to their Reserve data.
  mapping(uint256 reserveId => Reserve) internal _reserves;

  /// @dev Map of position manager addresses to their configuration data.
  mapping(address positionManager => PositionManagerConfig) internal _positionManager;

  /// @dev Map of reserve identifiers and dynamic configuration keys to the dynamic configuration data.
  mapping(uint256 reserveId => mapping(uint24 dynamicConfigKey => DynamicReserveConfig))
    internal _dynamicConfig;

  /// @dev Liquidation configuration for the Spoke.
  LiquidationConfig internal _liquidationConfig;

  /// @dev Map of hub addresses and asset identifiers to whether the reserve exists.
  mapping(address hub => mapping(uint256 assetId => bool)) internal _reserveExists;

  /// @notice Modifier that checks if the caller is an approved positionManager for `onBehalfOf`.
  modifier onlyPositionManager(address onBehalfOf) {
    require(_isPositionManager({user: onBehalfOf, manager: msg.sender}), Unauthorized());
    _;
  }

  /// @dev Constructor.
  /// @param oracle_ The address of the AaveOracle contract.
  constructor(address oracle_) {
    require(IAaveOracle(oracle_).DECIMALS() == ORACLE_DECIMALS, InvalidOracleDecimals());
    ORACLE = oracle_;
  }

  /// @dev To be overridden by the inheriting Spoke instance contract.
  function initialize(address authority) external virtual;

  /// @inheritdoc ISpoke
  function updateLiquidationConfig(LiquidationConfig calldata config) external restricted {
    require(
      config.targetHealthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD &&
        config.liquidationBonusFactor <= PercentageMath.PERCENTAGE_FACTOR &&
        config.healthFactorForMaxBonus < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      InvalidLiquidationConfig()
    );
    _liquidationConfig = config;
    emit UpdateLiquidationConfig(config);
  }

  /// @inheritdoc ISpoke
  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    ReserveConfig calldata config,
    DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint256) {
    require(hub != address(0), InvalidAddress());
    require(assetId <= MAX_ALLOWED_ASSET_ID, InvalidAssetId());
    require(!_reserveExists[hub][assetId], ReserveExists());

    _validateReserveConfig(config);
    _validateDynamicReserveConfig(dynamicConfig);
    uint256 reserveId = _reserveCount++;
    uint24 dynamicConfigKey; // 0 as first key to use

    (address underlying, uint8 decimals) = IHubBase(hub).getAssetUnderlyingAndDecimals(assetId);
    require(underlying != address(0), AssetNotListed());

    _updateReservePriceSource(reserveId, priceSource);

    _reserves[reserveId] = Reserve({
      underlying: underlying,
      hub: IHubBase(hub),
      assetId: assetId.toUint16(),
      decimals: decimals,
      dynamicConfigKey: dynamicConfigKey,
      paused: config.paused,
      frozen: config.frozen,
      borrowable: config.borrowable,
      collateralRisk: config.collateralRisk
    });
    _dynamicConfig[reserveId][dynamicConfigKey] = dynamicConfig;
    _reserveExists[hub][assetId] = true;

    emit AddReserve(reserveId, assetId, hub);
    emit UpdateReserveConfig(reserveId, config);
    emit AddDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicConfig);

    return reserveId;
  }

  /// @inheritdoc ISpoke
  function updateReserveConfig(
    uint256 reserveId,
    ReserveConfig calldata config
  ) external restricted {
    Reserve storage reserve = _getReserve(reserveId);
    _validateReserveConfig(config);
    reserve.paused = config.paused;
    reserve.frozen = config.frozen;
    reserve.borrowable = config.borrowable;
    reserve.collateralRisk = config.collateralRisk;
    emit UpdateReserveConfig(reserveId, config);
  }

  /// @inheritdoc ISpoke
  function updateReservePriceSource(uint256 reserveId, address priceSource) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _updateReservePriceSource(reserveId, priceSource);
  }

  /// @inheritdoc ISpoke
  function addDynamicReserveConfig(
    uint256 reserveId,
    DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint24) {
    require(reserveId < _reserveCount, ReserveNotListed());
    uint24 dynamicConfigKey = _reserves[reserveId].dynamicConfigKey;
    require(dynamicConfigKey < MAX_ALLOWED_DYNAMIC_CONFIG_KEY, MaximumDynamicConfigKeyReached());
    _validateDynamicReserveConfig(dynamicConfig);
    dynamicConfigKey = dynamicConfigKey.uncheckedAdd(1).toUint24();
    _reserves[reserveId].dynamicConfigKey = dynamicConfigKey;
    _dynamicConfig[reserveId][dynamicConfigKey] = dynamicConfig;
    emit AddDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicConfig);
    return dynamicConfigKey;
  }

  /// @inheritdoc ISpoke
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint24 dynamicConfigKey,
    DynamicReserveConfig calldata dynamicConfig
  ) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _validateUpdateDynamicReserveConfig(_dynamicConfig[reserveId][dynamicConfigKey], dynamicConfig);
    _dynamicConfig[reserveId][dynamicConfigKey] = dynamicConfig;
    emit UpdateDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicConfig);
  }

  /// @inheritdoc ISpoke
  function updatePositionManager(address positionManager, bool active) external restricted {
    _positionManager[positionManager].active = active;
    emit UpdatePositionManager(positionManager, active);
  }

  /// @inheritdoc ISpokeBase
  function supply(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    _validateSupply(reserve);

    reserve.underlying.safeTransferFrom(msg.sender, address(reserve.hub), amount);
    uint256 suppliedShares = reserve.hub.add(reserve.assetId, amount);
    userPosition.suppliedShares += suppliedShares.toUint120();

    emit Supply(reserveId, msg.sender, onBehalfOf, suppliedShares, amount);

    return (suppliedShares, amount);
  }

  /// @inheritdoc ISpokeBase
  function withdraw(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    _validateWithdraw(reserve);
    IHubBase hub = reserve.hub;
    uint256 assetId = reserve.assetId;

    uint256 withdrawnAmount = MathUtils.min(
      amount,
      hub.previewRemoveByShares(assetId, userPosition.suppliedShares)
    );
    uint256 withdrawnShares = hub.remove(assetId, withdrawnAmount, msg.sender);

    userPosition.suppliedShares -= withdrawnShares.toUint120();

    if (_positionStatus[onBehalfOf].isUsingAsCollateral(reserveId)) {
      uint256 newRiskPremium = _refreshAndValidateUserAccountData(onBehalfOf).riskPremium;
      _notifyRiskPremiumUpdate(onBehalfOf, newRiskPremium);
    }

    emit Withdraw(reserveId, msg.sender, onBehalfOf, withdrawnShares, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ISpokeBase
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    _validateBorrow(reserve);
    IHubBase hub = reserve.hub;

    uint256 drawnShares = hub.draw(reserve.assetId, amount, msg.sender);
    userPosition.drawnShares += drawnShares.toUint120();
    if (!positionStatus.isBorrowing(reserveId)) {
      positionStatus.setBorrowing(reserveId, true);
    }

    uint256 newRiskPremium = _refreshAndValidateUserAccountData(onBehalfOf).riskPremium;
    _notifyRiskPremiumUpdate(onBehalfOf, newRiskPremium);

    emit Borrow(reserveId, msg.sender, onBehalfOf, drawnShares, amount);

    return (drawnShares, amount);
  }

  /// @inheritdoc ISpokeBase
  function repay(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    _validateRepay(reserve);

    uint256 drawnIndex = reserve.hub.getAssetDrawnIndex(reserve.assetId);
    (uint256 drawnDebtRestored, uint256 premiumDebtRayRestored) = userPosition.getDebt(drawnIndex);

    (drawnDebtRestored, premiumDebtRayRestored) = _calculateRestoreAmount(
      drawnDebtRestored,
      premiumDebtRayRestored,
      amount
    );

    IHubBase.PremiumDelta memory premiumDelta = userPosition.getPremiumDelta({
      drawnIndex: drawnIndex,
      riskPremium: 0,
      restoredPremiumRay: premiumDebtRayRestored
    });

    uint256 totalDebtRestored = drawnDebtRestored + premiumDelta.restoredPremiumRay.fromRayUp();
    reserve.underlying.safeTransferFrom(msg.sender, address(reserve.hub), totalDebtRestored);
    uint256 restoredShares = reserve.hub.restore(reserve.assetId, drawnDebtRestored, premiumDelta);

    userPosition.applyPremiumDelta(premiumDelta);
    userPosition.drawnShares -= restoredShares.toUint120();
    if (userPosition.drawnShares == 0) {
      PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
      positionStatus.setBorrowing(reserveId, false);
    }

    _notifyRiskPremiumUpdate(onBehalfOf, _calculateUserAccountData(onBehalfOf).riskPremium);

    emit Repay(reserveId, msg.sender, onBehalfOf, restoredShares, totalDebtRestored, premiumDelta);

    return (restoredShares, totalDebtRestored);
  }

  /// @inheritdoc ISpokeBase
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) external {
    Reserve storage collateralReserve = _getReserve(collateralReserveId);
    Reserve storage debtReserve = _getReserve(debtReserveId);
    DynamicReserveConfig storage collateralDynConfig = _dynamicConfig[collateralReserveId][
      _userPositions[user][collateralReserveId].dynamicConfigKey
    ];
    UserAccountData memory userAccountData = _calculateUserAccountData(user);

    uint256 drawnIndex = debtReserve.hub.getAssetDrawnIndex(debtReserve.assetId);
    (uint256 drawnDebt, uint256 premiumDebtRay) = _userPositions[user][debtReserveId].getDebt(
      drawnIndex
    );

    LiquidationLogic.LiquidateUserParams memory params = LiquidationLogic.LiquidateUserParams({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      oracle: ORACLE,
      user: user,
      debtToCover: debtToCover,
      healthFactor: userAccountData.healthFactor,
      drawnDebt: drawnDebt,
      premiumDebtRay: premiumDebtRay,
      drawnIndex: drawnIndex,
      totalDebtValue: userAccountData.totalDebtValue,
      activeCollateralCount: userAccountData.activeCollateralCount,
      borrowedCount: userAccountData.borrowedCount,
      liquidator: msg.sender,
      receiveShares: receiveShares
    });

    bool isUserInDeficit = LiquidationLogic.liquidateUser(
      collateralReserve,
      debtReserve,
      _userPositions,
      _positionStatus,
      _liquidationConfig,
      collateralDynConfig,
      params
    );

    uint256 newRiskPremium = 0;
    if (isUserInDeficit) {
      _reportDeficit(user);
    } else {
      newRiskPremium = _calculateUserAccountData(user).riskPremium;
    }
    _notifyRiskPremiumUpdate(user, newRiskPremium);
  }

  /// @inheritdoc ISpoke
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    _validateSetUsingAsCollateral(_getReserve(reserveId), usingAsCollateral);
    PositionStatus storage positionStatus = _positionStatus[onBehalfOf];

    if (positionStatus.isUsingAsCollateral(reserveId) == usingAsCollateral) {
      return;
    }
    positionStatus.setUsingAsCollateral(reserveId, usingAsCollateral);

    if (usingAsCollateral) {
      _refreshDynamicConfig(onBehalfOf, reserveId);
    } else {
      uint256 newRiskPremium = _refreshAndValidateUserAccountData(onBehalfOf).riskPremium;
      _notifyRiskPremiumUpdate(onBehalfOf, newRiskPremium);
    }

    emit SetUsingAsCollateral(reserveId, msg.sender, onBehalfOf, usingAsCollateral);
  }

  /// @inheritdoc ISpoke
  function updateUserRiskPremium(address onBehalfOf) external {
    if (!_isPositionManager({user: onBehalfOf, manager: msg.sender})) {
      _checkCanCall(msg.sender, msg.data);
    }
    uint256 newRiskPremium = _calculateUserAccountData(onBehalfOf).riskPremium;
    _notifyRiskPremiumUpdate(onBehalfOf, newRiskPremium);
  }

  /// @inheritdoc ISpoke
  function updateUserDynamicConfig(address onBehalfOf) external {
    if (!_isPositionManager({user: onBehalfOf, manager: msg.sender})) {
      _checkCanCall(msg.sender, msg.data);
    }
    uint256 newRiskPremium = _refreshAndValidateUserAccountData(onBehalfOf).riskPremium;
    _notifyRiskPremiumUpdate(onBehalfOf, newRiskPremium);
  }

  /// @inheritdoc ISpoke
  function setUserPositionManager(address positionManager, bool approve) external {
    _setUserPositionManager({positionManager: positionManager, user: msg.sender, approve: approve});
  }

  /// @inheritdoc ISpoke
  function setUserPositionManagerWithSig(
    address positionManager,
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(
      keccak256(
        abi.encode(
          SET_USER_POSITION_MANAGER_TYPEHASH,
          positionManager,
          user,
          approve,
          nonce,
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());
    _useCheckedNonce(user, nonce);
    _setUserPositionManager({positionManager: positionManager, user: user, approve: approve});
  }

  /// @inheritdoc ISpoke
  function renouncePositionManagerRole(address onBehalfOf) external {
    if (!_positionManager[msg.sender].approval[onBehalfOf]) {
      return;
    }
    _positionManager[msg.sender].approval[onBehalfOf] = false;
    emit SetUserPositionManager(onBehalfOf, msg.sender, false);
  }

  /// @inheritdoc ISpoke
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external {
    Reserve storage reserve = _reserves[reserveId];
    address underlying = reserve.underlying;
    require(underlying != address(0), ReserveNotListed());
    try
      IERC20Permit(underlying).permit({
        owner: onBehalfOf,
        spender: address(this),
        value: value,
        deadline: deadline,
        v: permitV,
        r: permitR,
        s: permitS
      })
    {} catch {}
  }

  /// @inheritdoc ISpoke
  function getLiquidationConfig() external view returns (LiquidationConfig memory) {
    return _liquidationConfig;
  }

  /// @inheritdoc ISpoke
  function getReserveCount() external view returns (uint256) {
    return _reserveCount;
  }

  /// @inheritdoc ISpokeBase
  function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return reserve.hub.getSpokeAddedAssets(reserve.assetId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return reserve.hub.getSpokeAddedShares(reserve.assetId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return reserve.hub.getSpokeOwed(reserve.assetId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return reserve.hub.getSpokeTotalOwed(reserve.assetId, address(this));
  }

  /// @inheritdoc ISpoke
  function getReserve(uint256 reserveId) external view returns (Reserve memory) {
    return _getReserve(reserveId);
  }

  /// @inheritdoc ISpoke
  function getReserveConfig(uint256 reserveId) external view returns (ReserveConfig memory) {
    Reserve storage reserve = _getReserve(reserveId);
    return
      ReserveConfig({
        paused: reserve.paused,
        frozen: reserve.frozen,
        borrowable: reserve.borrowable,
        collateralRisk: reserve.collateralRisk
      });
  }

  /// @inheritdoc ISpoke
  function getDynamicReserveConfig(
    uint256 reserveId,
    uint24 dynamicConfigKey
  ) external view returns (DynamicReserveConfig memory) {
    _getReserve(reserveId);
    return _dynamicConfig[reserveId][dynamicConfigKey];
  }

  /// @inheritdoc ISpoke
  function getUserReserveStatus(
    uint256 reserveId,
    address user
  ) external view returns (bool, bool) {
    _getReserve(reserveId);
    PositionStatus storage positionStatus = _positionStatus[user];
    return (positionStatus.isUsingAsCollateral(reserveId), positionStatus.isBorrowing(reserveId));
  }

  /// @inheritdoc ISpokeBase
  function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    return
      reserve.hub.previewRemoveByShares(
        reserve.assetId,
        _userPositions[user][reserveId].suppliedShares
      );
  }

  /// @inheritdoc ISpokeBase
  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256) {
    _getReserve(reserveId);
    return _userPositions[user][reserveId].suppliedShares;
  }

  /// @inheritdoc ISpokeBase
  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[user][reserveId];
    (uint256 drawnDebt, uint256 premiumDebtRay) = userPosition.getDebt(
      reserve.hub,
      reserve.assetId
    );
    return (drawnDebt, premiumDebtRay.fromRayUp());
  }

  /// @inheritdoc ISpokeBase
  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[user][reserveId];
    (uint256 drawnDebt, uint256 premiumDebtRay) = userPosition.getDebt(
      reserve.hub,
      reserve.assetId
    );
    return (drawnDebt + premiumDebtRay.fromRayUp());
  }

  /// @inheritdoc ISpokeBase
  function getUserPremiumDebtRay(uint256 reserveId, address user) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[user][reserveId];
    (, uint256 premiumDebtRay) = userPosition.getDebt(reserve.hub, reserve.assetId);
    return premiumDebtRay;
  }

  /// @inheritdoc ISpoke
  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (UserPosition memory) {
    _getReserve(reserveId);
    return _userPositions[user][reserveId];
  }

  /// @inheritdoc ISpoke
  function getLiquidationBonus(
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) external view returns (uint256) {
    _getReserve(reserveId);
    return
      LiquidationLogic.calculateLiquidationBonus({
        healthFactorForMaxBonus: _liquidationConfig.healthFactorForMaxBonus,
        liquidationBonusFactor: _liquidationConfig.liquidationBonusFactor,
        healthFactor: healthFactor,
        maxLiquidationBonus: _dynamicConfig[reserveId][
          _userPositions[user][reserveId].dynamicConfigKey
        ].maxLiquidationBonus
      });
  }

  /// @inheritdoc ISpoke
  function getUserAccountData(address user) external view returns (UserAccountData memory) {
    // SAFETY: function does not modify state when `refreshConfig` is false.
    return _castToView(_processUserAccountData)(user, false);
  }

  /// @inheritdoc ISpoke
  function isPositionManagerActive(address positionManager) external view returns (bool) {
    return _positionManager[positionManager].active;
  }

  /// @inheritdoc ISpoke
  function isPositionManager(address user, address positionManager) external view returns (bool) {
    return _isPositionManager(user, positionManager);
  }

  /// @inheritdoc ISpoke
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  /// @inheritdoc ISpoke
  function getLiquidationLogic() external pure returns (address) {
    return address(LiquidationLogic);
  }

  function _updateReservePriceSource(uint256 reserveId, address priceSource) internal {
    require(priceSource != address(0), InvalidAddress());
    IAaveOracle(ORACLE).setReserveSource(reserveId, priceSource);
    emit UpdateReservePriceSource(reserveId, priceSource);
  }

  function _setUserPositionManager(address positionManager, address user, bool approve) internal {
    PositionManagerConfig storage config = _positionManager[positionManager];
    // only allow approval when position manager is active for improved UX
    require(!approve || config.active, InactivePositionManager());
    config.approval[user] = approve;
    emit SetUserPositionManager(user, positionManager, approve);
  }

  /// @notice Calculates and validates the user account data.
  /// @dev It refreshes the dynamic config before calculation.
  /// @dev It checks that the health factor is above the liquidation threshold.
  function _refreshAndValidateUserAccountData(
    address user
  ) internal returns (UserAccountData memory) {
    UserAccountData memory accountData = _processUserAccountData(user, true);
    emit RefreshAllUserDynamicConfig(user);
    require(
      accountData.healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      HealthFactorBelowThreshold()
    );
    return accountData;
  }

  /// @notice Calculates the user account data with the current user dynamic config.
  function _calculateUserAccountData(address user) internal returns (UserAccountData memory) {
    return _processUserAccountData(user, false); // does not modify state
  }

  /// @notice Process the user account data and updates dynamic config of the user if `refreshConfig` is true.
  function _processUserAccountData(
    address user,
    bool refreshConfig
  ) internal returns (UserAccountData memory accountData) {
    PositionStatus storage positionStatus = _positionStatus[user];

    uint256 reserveId = _reserveCount;
    KeyValueList.List memory collateralInfo = KeyValueList.init(
      positionStatus.collateralCount(reserveId)
    );
    bool borrowing;
    bool collateral;
    while (true) {
      (reserveId, borrowing, collateral) = positionStatus.next(reserveId);
      if (reserveId == PositionStatusMap.NOT_FOUND) break;

      UserPosition storage userPosition = _userPositions[user][reserveId];
      Reserve storage reserve = _reserves[reserveId];

      uint256 assetPrice = IAaveOracle(ORACLE).getReservePrice(reserveId);
      uint256 assetUnit = MathUtils.uncheckedExp(10, reserve.decimals);

      if (collateral) {
        uint256 collateralFactor = _dynamicConfig[reserveId][
          refreshConfig
            ? (userPosition.dynamicConfigKey = reserve.dynamicConfigKey)
            : userPosition.dynamicConfigKey
        ].collateralFactor;
        if (collateralFactor > 0) {
          uint256 suppliedShares = userPosition.suppliedShares;
          if (suppliedShares > 0) {
            // cannot round down to zero
            uint256 userCollateralValue = (reserve.hub.previewRemoveByShares(
              reserve.assetId,
              suppliedShares
            ) * assetPrice).wadDivDown(assetUnit);
            accountData.totalCollateralValue += userCollateralValue;
            collateralInfo.add(
              accountData.activeCollateralCount,
              reserve.collateralRisk,
              userCollateralValue
            );
            accountData.avgCollateralFactor += collateralFactor * userCollateralValue;
            accountData.activeCollateralCount = accountData.activeCollateralCount.uncheckedAdd(1);
          }
        }
      }

      if (borrowing) {
        (uint256 drawnDebt, uint256 premiumDebtRay) = userPosition.getDebt(
          reserve.hub,
          reserve.assetId
        );
        // we can simplify since there is no precision loss due to the division here
        accountData.totalDebtValue += ((drawnDebt + premiumDebtRay.fromRayUp()) * assetPrice)
          .wadDivUp(assetUnit);
        accountData.borrowedCount = accountData.borrowedCount.uncheckedAdd(1);
      }
    }

    if (accountData.totalDebtValue > 0) {
      // at this point, `avgCollateralFactor` is the collateral-weighted sum (scaled by `collateralFactor` in BPS)
      // health factor uses this directly for simplicity
      // the division by `totalCollateralValue` to compute the weighted average is done later
      accountData.healthFactor = accountData
        .avgCollateralFactor
        .wadDivDown(accountData.totalDebtValue)
        .fromBpsDown();
    } else {
      accountData.healthFactor = type(uint256).max;
    }

    if (accountData.totalCollateralValue > 0) {
      accountData.avgCollateralFactor = accountData
        .avgCollateralFactor
        .wadDivDown(accountData.totalCollateralValue)
        .fromBpsDown();
    }

    // sort by collateral risk in ASC, collateral value in DESC
    collateralInfo.sortByKey();

    // runs until either the collateral or debt is exhausted
    uint256 debtValueLeftToCover = accountData.totalDebtValue;

    for (uint256 index = 0; index < collateralInfo.length(); ++index) {
      if (debtValueLeftToCover == 0) {
        break;
      }

      (uint256 collateralRisk, uint256 userCollateralValue) = collateralInfo.get(index);
      userCollateralValue = userCollateralValue.min(debtValueLeftToCover);
      accountData.riskPremium += userCollateralValue * collateralRisk;
      debtValueLeftToCover = debtValueLeftToCover.uncheckedSub(userCollateralValue);
    }

    if (debtValueLeftToCover < accountData.totalDebtValue) {
      accountData.riskPremium /= accountData.totalDebtValue.uncheckedSub(debtValueLeftToCover);
    }

    return accountData;
  }

  function _refreshDynamicConfig(address user, uint256 reserveId) internal {
    _userPositions[user][reserveId].dynamicConfigKey = _reserves[reserveId].dynamicConfigKey;
    emit RefreshSingleUserDynamicConfig(user, reserveId);
  }

  /// @notice Refreshes premium for borrowed reserves of `user` with `newRiskPremium`.
  /// @dev Skips the refresh if the user risk premium remains zero.
  function _notifyRiskPremiumUpdate(address user, uint256 newRiskPremium) internal {
    PositionStatus storage positionStatus = _positionStatus[user];
    if (newRiskPremium == 0 && !positionStatus.hasPositiveRiskPremium) {
      return;
    }
    positionStatus.hasPositiveRiskPremium = newRiskPremium > 0;

    uint256 reserveId = _reserveCount;
    while ((reserveId = positionStatus.nextBorrowing(reserveId)) != PositionStatusMap.NOT_FOUND) {
      UserPosition storage userPosition = _userPositions[user][reserveId];
      Reserve storage reserve = _reserves[reserveId];
      uint256 assetId = reserve.assetId;
      IHubBase hub = reserve.hub;
      uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

      IHubBase.PremiumDelta memory premiumDelta = userPosition.getPremiumDelta({
        drawnIndex: drawnIndex,
        riskPremium: newRiskPremium,
        restoredPremiumRay: 0
      });

      hub.refreshPremium(assetId, premiumDelta);
      userPosition.applyPremiumDelta(premiumDelta);
      emit RefreshPremiumDebt(reserveId, user, premiumDelta);
    }
    emit UpdateUserRiskPremium(user, newRiskPremium);
  }

  /// @notice Reports deficits for all debt reserves of the user, including the reserve being repaid during liquidation.
  /// @dev Deficit validation should already have occurred during liquidation.
  /// @dev It clears the user position, setting drawn debt, premium debt, and risk premium to zero.
  function _reportDeficit(address user) internal {
    PositionStatus storage positionStatus = _positionStatus[user];

    uint256 reserveId = _reserveCount;
    while ((reserveId = positionStatus.nextBorrowing(reserveId)) != PositionStatusMap.NOT_FOUND) {
      UserPosition storage userPosition = _userPositions[user][reserveId];
      Reserve storage reserve = _reserves[reserveId];
      IHubBase hub = reserve.hub;
      uint256 assetId = reserve.assetId;
      uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);
      (uint256 drawnDebtReported, uint256 premiumDebtRay) = userPosition.getDebt(drawnIndex);

      IHubBase.PremiumDelta memory premiumDelta = userPosition.getPremiumDelta({
        drawnIndex: drawnIndex,
        riskPremium: 0,
        restoredPremiumRay: premiumDebtRay
      });

      uint256 deficitShares = hub.reportDeficit(assetId, drawnDebtReported, premiumDelta);
      userPosition.applyPremiumDelta(premiumDelta);
      userPosition.drawnShares -= deficitShares.toUint120();
      positionStatus.setBorrowing(reserveId, false);

      emit ReportDeficit(reserveId, user, deficitShares, premiumDelta);
    }
  }

  function _getReserve(uint256 reserveId) internal view returns (Reserve storage) {
    Reserve storage reserve = _reserves[reserveId];
    require(address(reserve.hub) != address(0), ReserveNotListed());
    return reserve;
  }

  /// @dev CollateralFactor of historical config keys cannot be 0, which allows liquidations to proceed.
  function _validateUpdateDynamicReserveConfig(
    DynamicReserveConfig storage currentConfig,
    DynamicReserveConfig calldata newConfig
  ) internal view {
    // sufficient check since maxLiquidationBonus is always >= 100_00
    require(currentConfig.maxLiquidationBonus > 0, ConfigKeyUninitialized());
    require(newConfig.collateralFactor > 0, InvalidCollateralFactor());
    _validateDynamicReserveConfig(newConfig);
  }

  function _validateSupply(Reserve storage reserve) internal view {
    require(!reserve.paused, ReservePaused());
    require(!reserve.frozen, ReserveFrozen());
  }

  function _validateWithdraw(Reserve storage reserve) internal view {
    require(!reserve.paused, ReservePaused());
  }

  function _validateBorrow(Reserve storage reserve) internal view {
    require(!reserve.paused, ReservePaused());
    require(!reserve.frozen, ReserveFrozen());
    require(reserve.borrowable, ReserveNotBorrowable());
    // health factor is checked at the end of borrow action
  }

  function _validateRepay(Reserve storage reserve) internal view {
    require(!reserve.paused, ReservePaused());
  }

  function _validateSetUsingAsCollateral(
    Reserve storage reserve,
    bool usingAsCollateral
  ) internal view {
    require(!reserve.paused, ReservePaused());
    // can disable as collateral if the reserve is frozen
    require(!usingAsCollateral || !reserve.frozen, ReserveFrozen());
  }

  /// @notice Returns whether `manager` is active & approved positionManager for `user`.
  function _isPositionManager(address user, address manager) internal view returns (bool) {
    if (user == manager) return true;
    PositionManagerConfig storage config = _positionManager[manager];
    return config.active && config.approval[user];
  }

  function _validateReserveConfig(ReserveConfig calldata config) internal pure {
    require(config.collateralRisk <= MAX_ALLOWED_COLLATERAL_RISK, InvalidCollateralRisk());
  }

  /// @dev Enforces compatible `maxLiquidationBonus` and `collateralFactor` so at the moment debt is created
  /// there is enough collateral to cover liquidation.
  function _validateDynamicReserveConfig(DynamicReserveConfig calldata config) internal pure {
    require(
      config.collateralFactor < PercentageMath.PERCENTAGE_FACTOR &&
        config.maxLiquidationBonus >= PercentageMath.PERCENTAGE_FACTOR &&
        config.maxLiquidationBonus.percentMulUp(config.collateralFactor) <
        PercentageMath.PERCENTAGE_FACTOR,
      InvalidCollateralFactorAndMaxLiquidationBonus()
    );
    require(config.liquidationFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidationFee());
  }

  /// @dev Calculates the drawn debt and premium debt to restore for the given amount.
  /// @param drawnDebt The maximum amount of drawn debt that can be restored.
  /// @param premiumDebtRay The maximum amount of premium debt that can be restored, expressed in asset units and scaled by RAY.
  /// @param amount The amount to restore.
  /// @return The amount of drawn debt to restore, expressed in asset units.
  /// @return The amount of premium debt to restore, expressed in asset units and scaled by RAY.
  function _calculateRestoreAmount(
    uint256 drawnDebt,
    uint256 premiumDebtRay,
    uint256 amount
  ) internal pure returns (uint256, uint256) {
    uint256 premiumDebt = premiumDebtRay.fromRayUp();
    if (amount >= drawnDebt + premiumDebt) {
      return (drawnDebt, premiumDebtRay);
    }

    if (amount < premiumDebt) {
      // amount.toRay() cannot overflow here
      return (0, amount.toRay());
    }

    return (amount - premiumDebt, premiumDebtRay);
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('Spoke', '1');
  }

  function _castToView(
    function(address, bool) internal returns (UserAccountData memory) fnIn
  )
    internal
    pure
    returns (function(address, bool) internal view returns (UserAccountData memory) fnOut)
  {
    assembly ('memory-safe') {
      fnOut := fnIn
    }
  }
}
