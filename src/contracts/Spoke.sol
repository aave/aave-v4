// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Multicall} from 'src/misc/Multicall.sol';

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';

// libraries
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

// interfaces
import {IHub} from 'src/interfaces/IHub.sol';
import {ISpokeBase, ISpoke} from 'src/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/interfaces/IAaveOracle.sol';

contract Spoke is ISpoke, Multicall, AccessManaged {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;
  using LiquidationLogic for DataTypes.LiquidationConfig;
  using PositionStatus for DataTypes.PositionStatus;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;
  using MathUtils for uint256;

  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = WadRayMath.WAD;
  uint256 public constant MAX_COLLATERAL_RISK = 1000_00; // 1000.00%

  IAaveOracle public oracle;

  uint256 internal _reserveCount;
  mapping(address user => mapping(uint256 reserveId => DataTypes.UserPosition position))
    internal _userPositions;
  mapping(address user => DataTypes.PositionStatus positionStatus) internal _positionStatus;
  mapping(uint256 reserveId => DataTypes.Reserve reserveData) internal _reserves;
  mapping(address positionManager => DataTypes.PositionManagerConfig) internal _positionManager;
  mapping(uint256 reserveId => mapping(uint16 configKey => DataTypes.DynamicReserveConfig config))
    internal _dynamicConfig; // dictionary of dynamic configs per reserve
  DataTypes.LiquidationConfig internal _liquidationConfig;

  modifier onlyPositionManager(address onBehalfOf) {
    require(_isPositionManager({user: onBehalfOf, manager: msg.sender}), Unauthorized());
    _;
  }

  /**
   * @dev Constructor.
   * @dev The authority should implement the AccessManaged interface to control access.
   * @param authority_ The address of the authority contract which manages permissions.
   */
  constructor(address authority_) AccessManaged(authority_) {
    // todo move to `initialize` when adding upgradeability
    _liquidationConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    emit LiquidationConfigUpdated(_liquidationConfig);
  }

  // /////
  // Governance
  // /////

  function updateOracle(address newOracle) external restricted {
    require(newOracle != address(0), InvalidOracle());
    oracle = IAaveOracle(newOracle);
    emit OracleUpdated(newOracle);
  }

  function updateReservePriceSource(uint256 reserveId, address priceSource) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _updateReservePriceSource(reserveId, priceSource);
  }

  function updateLiquidationConfig(
    DataTypes.LiquidationConfig calldata liquidationConfig
  ) external restricted {
    _validateLiquidationConfig(liquidationConfig);
    _liquidationConfig = liquidationConfig;
    emit LiquidationConfigUpdated(liquidationConfig);
  }

  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    DataTypes.ReserveConfig calldata config,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint256) {
    require(hub != address(0), InvalidHubAddress());

    _validateReserveConfig(config);
    uint256 reserveId = _reserveCount++;
    uint16 dynamicConfigKey; // 0 as first key to use

    require(assetId < IHub(hub).getAssetCount(), AssetNotListed());
    DataTypes.Asset memory asset = IHub(hub).getAsset(assetId);

    _updateReservePriceSource(reserveId, priceSource);

    _reserves[reserveId] = DataTypes.Reserve({
      reserveId: reserveId,
      assetId: assetId,
      config: config,
      dynamicConfigKey: dynamicConfigKey,
      decimals: asset.decimals,
      underlying: asset.underlying,
      hub: IHub(hub)
    });
    _dynamicConfig[reserveId][dynamicConfigKey] = dynamicConfig;

    emit ReserveAdded(reserveId, assetId, hub);
    emit ReserveConfigUpdated(reserveId, config);
    emit DynamicReserveConfigAdded(reserveId, dynamicConfigKey, dynamicConfig);

    return reserveId;
  }

  function updateReserveConfig(
    uint256 reserveId,
    DataTypes.ReserveConfig calldata config
  ) external restricted {
    // TODO: More sophisticated
    require(reserveId < _reserveCount, ReserveNotListed());
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    _validateReserveConfig(config);
    reserve.config = config;
    emit ReserveConfigUpdated(reserveId, config);
  }

  /// @inheritdoc ISpoke
  function addDynamicReserveConfig(
    uint256 reserveId,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint16) {
    require(reserveId < _reserveCount, ReserveNotListed());
    uint16 configKey;
    // @dev overflow is desired, we implicitly invalidate & override stale config
    unchecked {
      configKey = ++_reserves[reserveId].dynamicConfigKey;
    }
    _validateDynamicReserveConfig(dynamicConfig);
    _dynamicConfig[reserveId][configKey] = dynamicConfig;
    emit DynamicReserveConfigAdded(reserveId, configKey, dynamicConfig);
    return configKey;
  }

  /// @inheritdoc ISpoke
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    // @dev sufficient check since min liquidationBonus is 100_00
    require(_dynamicConfig[reserveId][configKey].liquidationBonus != 0, ConfigKeyUninitialized());
    _validateDynamicReserveConfig(dynamicConfig);
    _dynamicConfig[reserveId][configKey] = dynamicConfig;
    emit DynamicReserveConfigUpdated(reserveId, configKey, dynamicConfig);
  }

  /// @inheritdoc ISpoke
  function updatePositionManager(address positionManager, bool active) external restricted {
    _positionManager[positionManager].active = active;
    emit PositionManagerUpdated(positionManager, active);
  }

  // /////
  // Users
  // /////

  /// @inheritdoc ISpokeBase
  function supply(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];

    _validateSupply(reserve);

    uint256 suppliedShares = reserve.hub.add(reserve.assetId, amount, msg.sender);

    userPosition.suppliedShares += suppliedShares;

    emit Supply(reserveId, msg.sender, onBehalfOf, suppliedShares);
  }

  /// @inheritdoc ISpokeBase
  function withdraw(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    uint256 assetId = reserve.assetId;
    IHub hub = reserve.hub;

    // If uint256.max is passed, withdraw all user's supplied assets
    if (amount == type(uint256).max) {
      amount = hub.previewRemoveByShares(assetId, userPosition.suppliedShares);
    }
    _validateWithdraw(reserve, userPosition, amount);

    uint256 withdrawnShares = hub.remove(assetId, amount, msg.sender);

    userPosition.suppliedShares -= withdrawnShares;

    // calc needs new user position, just updating drawn debt is enough
    uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf); // validates HF
    _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);

    emit Withdraw(reserveId, msg.sender, onBehalfOf, withdrawnShares);
  }

  /// @inheritdoc ISpokeBase
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    DataTypes.PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    uint256 assetId = reserve.assetId;
    IHub hub = reserve.hub;

    _validateBorrow(reserve);

    uint256 drawnShares = hub.draw(assetId, amount, msg.sender);

    userPosition.drawnShares += drawnShares;
    if (!positionStatus.isBorrowing(reserveId)) {
      positionStatus.setBorrowing(reserveId, true);
    }

    // calc needs new user position, just updating drawn debt is enough
    uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf); // validates HF
    _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);

    emit Borrow(reserveId, msg.sender, onBehalfOf, drawnShares);
  }

  /// @inheritdoc ISpokeBase
  function repay(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    _validateRepay(reserve);

    DataTypes.ExecuteRepayLocalVars memory vars;
    vars.hub = reserve.hub;
    vars.assetId = reserve.assetId;
    (vars.drawnDebt, vars.premiumDebt, vars.accruedPremium) = _getUserDebt(
      vars.hub,
      vars.assetId,
      userPosition
    );
    (vars.drawnDebtRestored, vars.premiumDebtRestored) = _calculateRestoreAmount(
      vars.drawnDebt,
      vars.premiumDebt,
      amount
    );

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: -int256(userPosition.premiumShares),
      offsetDelta: -int256(userPosition.premiumOffset),
      realizedDelta: int256(vars.accruedPremium) - int256(vars.premiumDebtRestored)
    });
    vars.restoredShares = vars.hub.restore(
      vars.assetId,
      vars.drawnDebtRestored,
      vars.premiumDebtRestored,
      premiumDelta,
      msg.sender
    );

    _settlePremiumDebt(userPosition, premiumDelta);
    userPosition.drawnShares -= vars.restoredShares;
    if (userPosition.drawnShares == 0) {
      _positionStatus[onBehalfOf].setBorrowing(reserveId, false);
    }

    (vars.newUserRiskPremium, , , , ) = _calculateUserAccountData(onBehalfOf);
    _notifyRiskPremiumUpdate(onBehalfOf, vars.newUserRiskPremium);

    emit Repay(reserveId, msg.sender, onBehalfOf, vars.restoredShares); // todo: add premiumDelta
  }

  /// @inheritdoc ISpokeBase
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

    _executeLiquidationCall(
      _reserves[collateralReserveId],
      _reserves[debtReserveId],
      users,
      debtsToCover,
      msg.sender
    );
  }

  /// @inheritdoc ISpoke
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.PositionStatus storage positionStatus = _positionStatus[onBehalfOf];

    // process only if collateral status changes
    if (positionStatus.isUsingAsCollateral(reserveId) == usingAsCollateral) {
      return;
    }

    DataTypes.Reserve storage reserve = _reserves[reserveId];
    _validateSetUsingAsCollateral(reserve, reserveId, usingAsCollateral);

    positionStatus.setUsingAsCollateral(reserveId, usingAsCollateral);

    if (usingAsCollateral) {
      _refreshDynamicConfig(onBehalfOf, reserveId);
    } else {
      // If unsetting, check HF and update user rp
      uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf); // validates HF
      _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);
    }
    emit UsingAsCollateral(reserveId, msg.sender, onBehalfOf, usingAsCollateral);
  }

  /// @inheritdoc ISpoke
  function updateUserRiskPremium(address onBehalfOf) external {
    (uint256 userRiskPremium, , , , ) = _calculateUserAccountData(onBehalfOf);
    bool premiumIncrease = _notifyRiskPremiumUpdate(onBehalfOf, userRiskPremium);

    // check permissions if premium increases and not called by user
    if (premiumIncrease && !_isPositionManager({user: onBehalfOf, manager: msg.sender})) {
      _checkCanCall(msg.sender, msg.data);
    }
  }

  /// @inheritdoc ISpoke
  function updateUserDynamicConfig(address onBehalfOf) external {
    if (!_isPositionManager({user: onBehalfOf, manager: msg.sender})) {
      _checkCanCall(msg.sender, msg.data);
    }
    _refreshDynamicConfig(onBehalfOf);
  }

  /// @inheritdoc ISpoke
  function setUserPositionManager(address positionManager, bool approve) external {
    DataTypes.PositionManagerConfig storage config = _positionManager[positionManager];
    // @dev only allow approval when position manager is active for improved UX
    require(!approve || config.active, InactivePositionManager());
    config.approval[msg.sender] = approve;
    emit UserPositionManagerSet(msg.sender, positionManager, approve);
  }

  /// @inheritdoc ISpoke
  function renouncePositionManagerRole(address onBehalfOf) external {
    _positionManager[msg.sender].approval[onBehalfOf] = false;
    emit UserPositionManagerSet(onBehalfOf, msg.sender, false);
  }

  /// @inheritdoc ISpoke
  function isPositionManager(address user, address positionManager) external view returns (bool) {
    return _isPositionManager(user, positionManager);
  }

  /// @inheritdoc ISpoke
  function isPositionManagerActive(address positionManager) external view returns (bool) {
    return _positionManager[positionManager].active;
  }

  function isUsingAsCollateral(uint256 reserveId, address user) external view returns (bool) {
    return _positionStatus[user].isUsingAsCollateral(reserveId);
  }

  function isBorrowing(uint256 reserveId, address user) external view returns (bool) {
    return _positionStatus[user].isBorrowing(reserveId);
  }

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    DataTypes.UserPosition storage userPosition = _userPositions[user][reserveId];
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    (uint256 drawnDebt, uint256 premiumDebt, ) = _getUserDebt(
      reserve.hub,
      reserve.assetId,
      userPosition
    );
    return (drawnDebt, premiumDebt);
  }

  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256) {
    DataTypes.UserPosition storage userPosition = _userPositions[user][reserveId];
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    (uint256 drawnDebt, uint256 premiumDebt, ) = _getUserDebt(
      reserve.hub,
      reserve.assetId,
      userPosition
    );
    return drawnDebt + premiumDebt;
  }

  /// @dev We do not differentiate between duplicate reserves (assetId) on the same hub
  function getReserveSuppliedAmount(uint256 reserveId) external view returns (uint256) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    return reserve.hub.getSpokeAddedAmount(reserve.assetId, address(this));
  }

  /// @dev We do not differentiate between duplicate reserves (assetId) on the same hub
  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    return reserve.hub.getSpokeAddedShares(reserve.assetId, address(this));
  }

  function getUserSuppliedAmount(uint256 reserveId, address user) public view returns (uint256) {
    return
      _reserves[reserveId].hub.previewRemoveByShares(
        _reserves[reserveId].assetId,
        _userPositions[user][reserveId].suppliedShares
      );
  }

  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256) {
    return _userPositions[user][reserveId].suppliedShares;
  }

  function getReserveCount() external view returns (uint256) {
    return _reserveCount;
  }

  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    return reserve.hub.getSpokeOwed(reserve.assetId, address(this));
  }

  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    (uint256 drawnDebt, uint256 premiumDebt) = reserve.hub.getSpokeOwed(
      reserve.assetId,
      address(this)
    );
    return drawnDebt + premiumDebt;
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
    address user,
    uint256 healthFactor
  ) public view returns (uint256) {
    // if healthFactorForMaxBonus is 0, always returns liquidationBonus
    return
      _liquidationConfig.calculateVariableLiquidationBonus(
        healthFactor,
        _dynamicConfig[reserveId][_userPositions[user][reserveId].configKey].liquidationBonus,
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
    require(!reserve.config.paused, ReservePaused());
    require(!reserve.config.frozen, ReserveFrozen());
  }

  function _validateWithdraw(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage userPosition,
    uint256 amount
  ) internal view {
    require(reserve.underlying != address(0), ReserveNotListed());
    require(!reserve.config.paused, ReservePaused());
    uint256 suppliedAmount = reserve.hub.previewRemoveByShares(
      reserve.assetId,
      userPosition.suppliedShares
    );
    require(amount <= suppliedAmount, InsufficientSupply(suppliedAmount));
  }

  function _validateBorrow(DataTypes.Reserve storage reserve) internal view {
    require(reserve.underlying != address(0), ReserveNotListed());
    require(!reserve.config.paused, ReservePaused());
    require(!reserve.config.frozen, ReserveFrozen());
    require(reserve.config.borrowable, ReserveNotBorrowable(reserve.reserveId));
    // HF checked at the end of borrow action
  }

  // TODO: Place this and LH equivalent in a generic logic library
  function _validateRepay(DataTypes.Reserve storage reserve) internal view {
    require(reserve.underlying != address(0), ReserveNotListed());
    require(!reserve.config.paused, ReservePaused());
    // todo validate user not trying to repay more
    // todo NoExplicitAmountToRepayOnBehalf
  }

  /**
   * @dev Calculates the user's premium debt offset in assets amount from a given share amount.
   * @dev Rounds down to the nearest assets amount.
   * @dev Uses the opposite rounding direction of the debt shares-to-assets conversion to prevent underflow
   * in premium debt.
   * @param hub The liquidity hub of the reserve.
   * @param assetId The identifier of the asset.
   * @param shares The amount of shares to convert to assets amount.
   * @return The amount of assets converted corresponding to user's premium offset.
   */
  function _previewOffset(
    IHub hub,
    uint256 assetId,
    uint256 shares
  ) internal view returns (uint256) {
    return hub.previewDrawByShares(assetId, shares);
  }

  function _updateReservePriceSource(uint256 reserveId, address priceSource) internal {
    require(address(oracle) != address(0), InvalidOracle());
    oracle.setReserveSource(reserveId, priceSource);
    emit ReservePriceSourceUpdated(reserveId, priceSource);
  }

  function _refreshAndValidateUserPosition(address user) internal returns (uint256) {
    // @dev refresh user position dynamic config only on borrow, withdraw, disableUsingAsCollateral
    _refreshDynamicConfig(user); // opt: merge with _calculateUserAccountData
    (uint256 userRiskPremium, , uint256 healthFactor, , ) = _calculateUserAccountData(user);
    require(healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, HealthFactorBelowThreshold());
    return userRiskPremium;
  }

  function _validateReserveConfig(DataTypes.ReserveConfig calldata config) internal pure {
    require(config.collateralRisk <= MAX_COLLATERAL_RISK, InvalidCollateralRisk()); // max 1000.00%
  }

  function _validateDynamicReserveConfig(
    DataTypes.DynamicReserveConfig calldata config
  ) internal pure {
    require(config.collateralFactor <= PercentageMath.PERCENTAGE_FACTOR, InvalidCollateralFactor()); // max 100.00%
    require(config.liquidationBonus >= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidationBonus()); // min 100.00%
    require(
      config.liquidationBonus.percentMulUp(config.collateralFactor) <=
        PercentageMath.PERCENTAGE_FACTOR,
      IncompatibleCollateralFactorAndLiquidationBonus()
    ); // Enforces that at moment loan is taken, there should be enough collateral to cover liquidation
    require(config.liquidationFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidationFee());
  }

  function _validateLiquidationConfig(DataTypes.LiquidationConfig calldata config) internal pure {
    _validateCloseFactor(config.closeFactor);
    require(
      config.liquidationBonusFactor <= PercentageMath.PERCENTAGE_FACTOR,
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
   * @dev Collateral can be disabled if the reserve is frozen.
   * @param reserve The reserve to be set as collateral.
   * @param reserveId The identifier of the reserve.
   * @param usingAsCollateral True if enables the reserve as collateral, false otherwise.
   */
  function _validateSetUsingAsCollateral(
    DataTypes.Reserve storage reserve,
    uint256 reserveId,
    bool usingAsCollateral
  ) internal view {
    require(!reserve.config.paused, ReservePaused());
    // deactivation should be allowed
    require(!usingAsCollateral || !reserve.config.frozen, ReserveFrozen());
  }

  // @dev allows donation on drawn debt
  function _calculateRestoreAmount(
    uint256 drawnDebt,
    uint256 premiumDebt,
    uint256 amount
  ) internal pure returns (uint256, uint256) {
    if (amount >= drawnDebt + premiumDebt) {
      return (drawnDebt, premiumDebt);
    }
    if (amount <= premiumDebt) {
      return (0, amount);
    }
    return (amount - premiumDebt, premiumDebt);
  }

  function _settlePremiumDebt(
    DataTypes.UserPosition storage userPosition,
    DataTypes.PremiumDelta memory premiumDelta
  ) internal {
    userPosition.premiumShares = 0;
    userPosition.premiumOffset = 0;
    userPosition.realizedPremium = userPosition.realizedPremium.add(premiumDelta.realizedDelta);
  }

  function _isPositionManager(address user, address manager) private view returns (bool) {
    if (user == manager) return true;
    DataTypes.PositionManagerConfig storage config = _positionManager[manager];
    return config.active && config.approval[user];
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
    uint256 reserveCount = _reserveCount;
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(
      positionStatus.collateralCount(reserveCount)
    );

    while (vars.reserveId < reserveCount) {
      if (!positionStatus.isUsingAsCollateralOrBorrowing(vars.reserveId)) {
        unchecked {
          ++vars.reserveId;
        }
        continue;
      }

      DataTypes.UserPosition storage userPosition = _userPositions[user][vars.reserveId];
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
      vars.assetId = reserve.assetId;
      IHub hub = reserve.hub;
      vars.assetPrice = oracle.getReservePrice(vars.reserveId);
      unchecked {
        vars.assetUnit = 10 ** reserve.decimals;
      }

      if (positionStatus.isUsingAsCollateral(vars.reserveId)) {
        DataTypes.DynamicReserveConfig storage dynConfig = _dynamicConfig[vars.reserveId][
          userPosition.configKey
        ];
        vars.collateralRisk = reserve.config.collateralRisk;

        vars.userCollateralInBaseCurrency = _getUserBalanceInBaseCurrency(
          userPosition,
          hub,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit
        );

        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        list.add(vars.i, vars.collateralRisk, vars.userCollateralInBaseCurrency);
        vars.avgCollateralFactor += vars.userCollateralInBaseCurrency * dynConfig.collateralFactor;

        unchecked {
          ++vars.i;
        }
      }

      if (positionStatus.isBorrowing(vars.reserveId)) {
        vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
          userPosition,
          hub,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit
        );
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
      : vars.avgCollateralFactor.wadDivDown(vars.totalDebtInBaseCurrency).fromBpsDown(); // HF of 1 -> 1e18

    // divide by total collateral to get avg collateral factor in wad
    vars.avgCollateralFactor = vars.totalCollateralInBaseCurrency == 0
      ? 0
      : vars.avgCollateralFactor.wadDivDown(vars.totalCollateralInBaseCurrency);

    vars.debtCounterInBaseCurrency = vars.totalDebtInBaseCurrency;

    list.sortByKey(); // sort by collateral risk
    vars.i = 0;
    // @dev from this point onwards, `collateralCounterInBaseCurrency` represents running collateral
    // value used in risk premium, `debtCounterInBaseCurrency` represents running outstanding debt
    while (vars.i < list.length() && vars.debtCounterInBaseCurrency > 0) {
      if (vars.debtCounterInBaseCurrency == 0) break;
      (vars.collateralRisk, vars.userCollateralInBaseCurrency) = list.get(vars.i);
      if (vars.userCollateralInBaseCurrency > vars.debtCounterInBaseCurrency) {
        vars.userCollateralInBaseCurrency = vars.debtCounterInBaseCurrency;
      }
      vars.userRiskPremium += vars.userCollateralInBaseCurrency * vars.collateralRisk;
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
    IHub hub,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    (uint256 drawnDebt, uint256 premiumDebt, ) = _getUserDebt(hub, assetId, userPosition);
    return ((drawnDebt + premiumDebt) * assetPrice).wadDivUp(assetUnit);
  }

  function _getUserBalanceInBaseCurrency(
    DataTypes.UserPosition storage userPosition,
    IHub hub,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return
      (hub.previewRemoveByShares(assetId, userPosition.suppliedShares) * assetPrice).wadDivDown(
        assetUnit
      );
  }

  function _getUserDebt(
    IHub hub,
    uint256 assetId,
    DataTypes.UserPosition storage userPosition
  ) internal view returns (uint256, uint256, uint256) {
    uint256 accruedPremium = hub.previewRestoreByShares(assetId, userPosition.premiumShares) -
      userPosition.premiumOffset;
    return (
      hub.previewRestoreByShares(assetId, userPosition.drawnShares),
      userPosition.realizedPremium + accruedPremium,
      accruedPremium
    );
  }

  // todo optimize, merge logic duped borrow/repay, rename
  /**
   * @dev Trigger risk premium update on all drawn reserves of `user`.
   * @param user The address of the user whose risk premium is being updated.
   * @param newUserRiskPremium The new risk premium of the user.
   * @return premiumIncrease True if the risk premium increased, false otherwise.
   */
  function _notifyRiskPremiumUpdate(
    address user,
    uint256 newUserRiskPremium
  ) internal returns (bool) {
    DataTypes.NotifyRiskPremiumUpdateVars memory vars;
    vars.reserveCount = _reserveCount;
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];
    while (vars.reserveId < vars.reserveCount) {
      // todo keep borrowed assets in transient storage/pass through?
      if (positionStatus.isBorrowing(vars.reserveId)) {
        DataTypes.UserPosition storage userPosition = _userPositions[user][vars.reserveId];
        DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
        vars.assetId = reserve.assetId;
        vars.hub = reserve.hub;

        uint256 oldUserPremiumShares = userPosition.premiumShares;
        uint256 oldUserPremiumOffset = userPosition.premiumOffset;
        uint256 accruedUserPremium = vars.hub.previewRestoreByShares(
          vars.assetId,
          oldUserPremiumShares
        ) - oldUserPremiumOffset;

        userPosition.premiumShares = userPosition.drawnShares.percentMulUp(newUserRiskPremium);
        userPosition.premiumOffset = _previewOffset(
          vars.hub,
          vars.assetId,
          userPosition.premiumShares
        );
        userPosition.realizedPremium += accruedUserPremium;

        vars.premiumDelta = DataTypes.PremiumDelta({
          sharesDelta: userPosition.premiumShares.signedSub(oldUserPremiumShares),
          offsetDelta: userPosition.premiumOffset.signedSub(oldUserPremiumOffset),
          realizedDelta: int256(accruedUserPremium)
        });

        if (!vars.premiumIncrease) vars.premiumIncrease = vars.premiumDelta.sharesDelta > 0;

        vars.hub.refreshPremium(vars.assetId, vars.premiumDelta);
        emit RefreshPremiumDebt(vars.reserveId, user, vars.premiumDelta);
      }
      unchecked {
        ++vars.reserveId;
      }
    }
    emit UserRiskPremiumUpdate(user, newUserRiskPremium);

    return vars.premiumIncrease;
  }

  /**
   * @dev Reports deficits for all borrowing reserves of the user.
   * @dev Includes the debt reserve being repaid during liquidation.
   * @param user The address of the user whose deficits are being reported.
   */
  function _reportDeficits(address user) internal {
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];
    uint256 reservesLength = _reserveCount;
    uint256 reserveId;

    while (reserveId < reservesLength) {
      DataTypes.UserPosition storage userPosition = _userPositions[user][reserveId];
      if (positionStatus.isBorrowing(reserveId)) {
        DataTypes.Reserve storage reserve = _reserves[reserveId];
        // validation should already have occurred during liquidation
        IHub hub = reserve.hub;
        uint256 assetId = reserve.assetId;
        (
          uint256 drawnDebtRestored,
          uint256 premiumDebtRestored,
          uint256 accruedPremium
        ) = _getUserDebt(hub, assetId, userPosition);

        DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
          sharesDelta: -int256(userPosition.premiumShares),
          offsetDelta: -int256(userPosition.premiumOffset),
          realizedDelta: int256(accruedPremium) - int256(premiumDebtRestored)
        });
        uint256 deficitShares = hub.reportDeficit(
          assetId,
          drawnDebtRestored,
          premiumDebtRestored,
          premiumDelta
        );
        _settlePremiumDebt(userPosition, premiumDelta);
        userPosition.drawnShares -= deficitShares;
        // newUserRiskPremium is 0 due to no collateral remaining
        // non-zero deficit means user ends up with zero total debt
        positionStatus.setBorrowing(reserve.reserveId, false);
      }
      unchecked {
        ++reserveId;
      }
    }
    emit UserRiskPremiumUpdate(user, 0);
  }

  function _refreshDynamicConfig(address user) internal {
    uint256 reserveCount = _reserveCount;
    uint256 reserveId;
    while (reserveId < reserveCount) {
      if (_positionStatus[user].isUsingAsCollateral(reserveId)) {
        _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
      }
      unchecked {
        ++reserveId;
      }
    }
    emit UserDynamicConfigRefreshedAll(user);
  }

  function _refreshDynamicConfig(address user, uint256 reserveId) internal {
    _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
    emit UserDynamicConfigRefreshedSingle(user, reserveId);
  }

  /**
   * @dev Executes liquidation call across all users in the array, for a given pair of debt/collateral reserves.
   */
  function _executeLiquidationCall(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    address[] memory users,
    uint256[] memory debtsToCover,
    address liquidator
  ) internal {
    require(users.length == debtsToCover.length, UsersAndDebtLengthMismatch());

    IHub collateralReserveHub = collateralReserve.hub;
    IHub debtReserveHub = debtReserve.hub;

    DataTypes.ExecuteLiquidationLocalVars memory vars;

    vars.collateralReserveHub = collateralReserve.hub;
    vars.collateralAssetId = collateralReserve.assetId;
    vars.collateralReserveId = collateralReserve.reserveId;
    vars.collateralUnderlying = collateralReserve.underlying;
    vars.debtReserveHub = debtReserve.hub;
    vars.debtAssetId = debtReserve.assetId;
    vars.debtReserveId = debtReserve.reserveId;
    vars.debtUnderlying = debtReserve.underlying;

    while (vars.i < users.length) {
      vars.user = users[vars.i];
      DataTypes.UserPosition storage userCollateralPosition = _userPositions[vars.user][
        vars.collateralReserveId
      ];
      DataTypes.UserPosition storage userDebtPosition = _userPositions[vars.user][
        vars.debtReserveId
      ];

      (vars.drawnDebt, vars.premiumDebt, vars.accruedPremium) = _getUserDebt(
        vars.debtReserveHub,
        vars.debtAssetId,
        userDebtPosition
      );

      (
        vars.collateralToLiquidate,
        vars.liquidationFeeAmount,
        vars.drawnDebtToLiquidate,
        vars.premiumDebtToLiquidate,
        vars.hasDeficit
      ) = _calculateLiquidationParameters(
        collateralReserve,
        debtReserve,
        vars.user,
        debtsToCover[vars.i],
        vars.drawnDebt,
        vars.premiumDebt
      );

      // expected total withdrawn shares includes liquidation fee
      vars.withdrawnShares = vars.collateralReserveHub.previewRemoveByAssets(
        vars.collateralAssetId,
        vars.liquidationFeeAmount + vars.collateralToLiquidate
      );

      // perform collateral accounting first so that restore donations can not affect collateral shares calcs
      // in case the same reserve is being repaid and liquidated
      userCollateralPosition.suppliedShares -= vars.withdrawnShares;

      // remove collateral, send liquidated collateral directly to liquidator
      vars.liquidatedSuppliedShares = vars.collateralReserveHub.remove(
        vars.collateralAssetId,
        vars.collateralToLiquidate,
        liquidator
      );
      vars.liquidationFeeShares = vars.withdrawnShares - vars.liquidatedSuppliedShares;

      // repay debt
      {
        vars.premiumDelta = DataTypes.PremiumDelta({
          sharesDelta: -int256(userDebtPosition.premiumShares),
          offsetDelta: -int256(userDebtPosition.premiumOffset),
          realizedDelta: int256(vars.accruedPremium) - int256(vars.premiumDebtToLiquidate)
        });
        vars.restoredShares = vars.debtReserveHub.restore(
          vars.debtAssetId,
          vars.drawnDebtToLiquidate,
          vars.premiumDebtToLiquidate,
          vars.premiumDelta,
          liquidator
        );
        // debt accounting
        _settlePremiumDebt(userDebtPosition, vars.premiumDelta);
        userDebtPosition.drawnShares -= vars.restoredShares;
      }

      if (userDebtPosition.drawnShares == 0) {
        _positionStatus[vars.user].setBorrowing(vars.debtReserveId, false);
      }

      if (vars.hasDeficit) {
        _reportDeficits(vars.user);
      } else {
        // new risk premium only needs to be propagated if no deficit exists
        (vars.newUserRiskPremium, , , , ) = _calculateUserAccountData(vars.user);
        _notifyRiskPremiumUpdate(vars.user, vars.newUserRiskPremium);
      }

      vars.totalLiquidationFeeShares += vars.liquidationFeeShares;

      emit LiquidationCall(
        vars.collateralUnderlying,
        vars.debtUnderlying,
        vars.user,
        vars.drawnDebtToLiquidate + vars.premiumDebtToLiquidate,
        vars.collateralToLiquidate,
        liquidator
      );

      unchecked {
        ++vars.i;
      }
    }
    if (vars.totalLiquidationFeeShares > 0) {
      vars.collateralReserveHub.payFee(vars.collateralAssetId, vars.totalLiquidationFeeShares);
    }
  }

  /**
   * @dev Calculates the liquidation parameters for a user being liquidated.
   * @param collateralReserve The collateral reserve being liquidated.
   * @param debtReserve The debt reserve being repaid during liquidation.
   * @param user The address of the user being liquidated.
   * @param debtToCover The amount of debt to cover.
   * @param drawnDebt The drawn debt of the user.
   * @param premiumDebt The premium debt of the user.
   * @return actualCollateralToLiquidate The amount of collateral to liquidate.
   * @return liquidationFeeAmount The amount of protocol fee.
   * @return drawnDebtToLiquidate The amount of drawn debt to repay.
   * @return premiumDebtToLiquidate The amount of premium debt to repay.
   * @return hasDeficit The flag representing if the user will have deficit to report.
   */
  function _calculateLiquidationParameters(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    address user,
    uint256 debtToCover,
    uint256 drawnDebt,
    uint256 premiumDebt
  ) internal view returns (uint256, uint256, uint256, uint256, bool) {
    DataTypes.LiquidationCallLocalVars memory vars;
    vars.collateralReserveId = collateralReserve.reserveId;
    vars.debtReserveId = debtReserve.reserveId;
    vars.userCollateralBalance = getUserSuppliedAmount(vars.collateralReserveId, user);
    vars.totalDebt = drawnDebt + premiumDebt;
    DataTypes.DynamicReserveConfig storage collateralDynConfig = _dynamicConfig[
      vars.collateralReserveId
    ][_userPositions[user][vars.collateralReserveId].configKey];
    vars.collateralFactor = collateralDynConfig.collateralFactor;

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
      user,
      vars.healthFactor
    );
    vars.closeFactor = _liquidationConfig.closeFactor;
    vars.collateralAssetPrice = oracle.getReservePrice(vars.collateralReserveId);
    vars.collateralAssetUnit = 10 ** collateralReserve.decimals;
    vars.liquidationFee = collateralDynConfig.liquidationFee;

    vars.actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate({
      debtToCover: debtToCover,
      params: vars
    });
    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationFeeAmount,
      vars.hasDeficit
    ) = vars.calculateAvailableCollateralToLiquidate();
    (vars.drawnDebtToLiquidate, vars.premiumDebtToLiquidate) = _calculateRestoreAmount(
      drawnDebt,
      premiumDebt,
      vars.actualDebtToLiquidate
    );

    return (
      vars.actualCollateralToLiquidate,
      vars.liquidationFeeAmount,
      vars.drawnDebtToLiquidate,
      vars.premiumDebtToLiquidate,
      vars.hasDeficit
    );
  }
}
