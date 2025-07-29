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

// interfaces
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/interfaces/IAaveOracle.sol';

contract Spoke is ISpoke, Multicall, AccessManaged {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;
  using LiquidationLogic for DataTypes.LiquidationConfig;
  using PositionStatus for DataTypes.PositionStatus;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = WadRayMath.WAD;
  uint256 public constant MAX_COLLATERAL_RISK = 1000_00; // 1000.00%

  IAaveOracle public oracle;
  uint256[] public reservesList; // todo: rm, not needed

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

    require(assetId < ILiquidityHub(hub).getAssetCount(), AssetNotListed());
    DataTypes.Asset memory asset = ILiquidityHub(hub).getAsset(assetId);

    _updateReservePriceSource(reserveId, priceSource);

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

  /// @inheritdoc ISpoke
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
    reserve.suppliedShares += suppliedShares;

    emit Supply(reserveId, msg.sender, onBehalfOf, suppliedShares);
  }

  /// @inheritdoc ISpoke
  function withdraw(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    uint256 assetId = reserve.assetId;
    ILiquidityHub hub = reserve.hub;

    // If uint256.max is passed, withdraw all user's supplied assets
    if (amount == type(uint256).max) {
      amount = hub.convertToSuppliedAssets(assetId, userPosition.suppliedShares);
    }
    _validateWithdraw(reserve, userPosition, amount);

    uint256 withdrawnShares = hub.remove(assetId, amount, msg.sender);

    userPosition.suppliedShares -= withdrawnShares;
    reserve.suppliedShares -= withdrawnShares;

    // calc needs new user position, just updating base debt is enough
    uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf); // validates HF
    _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);

    emit Withdraw(reserveId, msg.sender, onBehalfOf, withdrawnShares);
  }

  /// @inheritdoc ISpoke
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    DataTypes.PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    uint256 assetId = reserve.assetId;
    ILiquidityHub hub = reserve.hub;

    _validateBorrow(reserve);

    uint256 baseDrawnShares = hub.draw(assetId, amount, msg.sender);

    reserve.baseDrawnShares += baseDrawnShares;
    userPosition.baseDrawnShares += baseDrawnShares;

    if (!positionStatus.isBorrowing(reserveId)) {
      positionStatus.setBorrowing(reserveId, true);
    }

    // calc needs new user position, just updating base debt is enough
    uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf); // validates HF
    _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);

    emit Borrow(reserveId, msg.sender, onBehalfOf, baseDrawnShares);
  }

  /// @inheritdoc ISpoke
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
    (vars.baseDebt, vars.premiumDebt) = _getUserDebt(vars.hub, vars.assetId, userPosition);
    (vars.baseDebtRestored, vars.premiumDebtRestored) = _calculateRestoreAmount(
      vars.baseDebt,
      vars.premiumDebt,
      amount
    );

    _settlePremiumDebt(
      reserve,
      userPosition,
      vars.hub,
      vars.assetId,
      reserveId,
      onBehalfOf,
      vars.premiumDebtRestored
    );
    vars.restoredShares = vars.hub.restore(
      vars.assetId,
      vars.baseDebtRestored,
      vars.premiumDebtRestored,
      msg.sender
    );

    reserve.baseDrawnShares -= vars.restoredShares;
    userPosition.baseDrawnShares -= vars.restoredShares;

    if (userPosition.baseDrawnShares == 0) {
      _positionStatus[onBehalfOf].setBorrowing(reserveId, false);
    }

    (vars.newUserRiskPremium, , , , ) = _calculateUserAccountData(onBehalfOf);
    _notifyRiskPremiumUpdate(onBehalfOf, vars.newUserRiskPremium);

    emit Repay(reserveId, msg.sender, onBehalfOf, vars.restoredShares);
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
      _reserves[reserveId].hub.previewRemoveByShares(
        _reserves[reserveId].assetId,
        _reserves[reserveId].suppliedShares
      );
  }

  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256) {
    return _reserves[reserveId].suppliedShares;
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
    (uint256 baseDebt, uint256 premiumDebt) = _getReserveDebt(_reserves[reserveId]);
    return (baseDebt, premiumDebt);
  }

  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getReserveDebt(_reserves[reserveId]);
    return baseDebt + premiumDebt;
  }

  function getReserveRiskPremium(uint256 reserveId) external view returns (uint256) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    return reserve.premiumDrawnShares.rayDivDown(reserve.baseDrawnShares); // trailing
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
    uint256 suppliedAmount = reserve.hub.convertToSuppliedAssets(
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
    ILiquidityHub hub,
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

  function _settlePremiumDebt(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage userPosition,
    ILiquidityHub hub,
    uint256 assetId,
    uint256 reserveId,
    address user,
    uint256 premiumDebtRestored
  ) internal {
    uint256 userPremiumDrawnShares = userPosition.premiumDrawnShares;
    uint256 userPremiumOffset = userPosition.premiumOffset;
    uint256 accruedPremium = hub.convertToDrawnAssets(assetId, userPremiumDrawnShares) -
      userPremiumOffset; // assets(premiumShares) - offset should never be < 0
    userPosition.premiumDrawnShares = 0;
    userPosition.premiumOffset = 0;
    userPosition.realizedPremium =
      userPosition.realizedPremium +
      accruedPremium -
      premiumDebtRestored;

    _refreshPremiumDebt(
      reserve,
      hub,
      assetId,
      reserveId,
      user,
      -int256(userPremiumDrawnShares),
      -int256(userPremiumOffset),
      accruedPremium,
      premiumDebtRestored
    );
  }

  function _refreshPremiumDebt(
    DataTypes.Reserve storage reserve,
    ILiquidityHub hub,
    uint256 assetId,
    uint256 reserveId,
    address user,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) internal {
    reserve.premiumDrawnShares = _add(reserve.premiumDrawnShares, premiumDrawnSharesDelta);
    reserve.premiumOffset = _add(reserve.premiumOffset, premiumOffsetDelta);
    reserve.realizedPremium = reserve.realizedPremium + realizedPremiumAdded - realizedPremiumTaken;

    emit RefreshPremiumDebt(
      reserveId,
      user,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
    hub.refreshPremiumDebt(
      assetId,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
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
    uint256 reservesListLength = reservesList.length;
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(
      positionStatus.collateralCount(reservesListLength)
    );

    while (vars.reserveId < reservesListLength) {
      if (!positionStatus.isUsingAsCollateralOrBorrowing(vars.reserveId)) {
        unchecked {
          ++vars.reserveId;
        }
        continue;
      }

      DataTypes.UserPosition storage userPosition = _userPositions[user][vars.reserveId];
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
      vars.assetId = reserve.assetId;
      ILiquidityHub hub = reserve.hub;
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
    ILiquidityHub hub,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getUserDebt(hub, assetId, userPosition);
    return ((baseDebt + premiumDebt) * assetPrice).wadDivUp(assetUnit);
  }

  function _getUserBalanceInBaseCurrency(
    DataTypes.UserPosition storage userPosition,
    ILiquidityHub hub,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return
      (hub.convertToSuppliedAssets(assetId, userPosition.suppliedShares) * assetPrice).wadDivDown(
        assetUnit
      );
  }

  function _getUserDebt(
    ILiquidityHub hub,
    uint256 assetId,
    DataTypes.UserPosition storage userPosition
  ) internal view returns (uint256, uint256) {
    uint256 accruedPremium = hub.convertToDrawnAssets(assetId, userPosition.premiumDrawnShares) -
      userPosition.premiumOffset;
    return (
      hub.previewRestoreByShares(assetId, userPosition.baseDrawnShares),
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
      hub.previewRestoreByShares(assetId, reserve.baseDrawnShares),
      reserve.realizedPremium + accruedPremium
    );
  }

  // todo optimize, merge logic duped borrow/repay, rename
  /**
   * @dev Trigger risk premium update on all drawn reserves of `user`.
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

        uint256 oldUserPremiumDrawnShares = userPosition.premiumDrawnShares;
        uint256 oldUserPremiumOffset = userPosition.premiumOffset;
        uint256 accruedUserPremium = vars.hub.convertToDrawnAssets(
          vars.assetId,
          oldUserPremiumDrawnShares
        ) - oldUserPremiumOffset;

        userPosition.premiumDrawnShares = userPosition.baseDrawnShares.percentMulUp(
          newUserRiskPremium
        );
        userPosition.premiumOffset = _previewOffset(
          vars.hub,
          vars.assetId,
          userPosition.premiumDrawnShares
        );
        userPosition.realizedPremium += accruedUserPremium;

        int256 premiumDrawnSharesDelta = _signedDiff(
          userPosition.premiumDrawnShares,
          oldUserPremiumDrawnShares
        );
        if (!vars.premiumIncrease) vars.premiumIncrease = premiumDrawnSharesDelta > 0;

        _refreshPremiumDebt(
          reserve,
          vars.hub,
          vars.assetId,
          vars.reserveId,
          user,
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
    emit UserRiskPremiumUpdate(user, newUserRiskPremium);

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
    emit UserDynamicConfigRefreshedAll(user);
  }

  function _refreshDynamicConfig(address user, uint256 reserveId) internal {
    _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
    emit UserDynamicConfigRefreshedSingle(user, reserveId);
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
      vars.user = users[vars.i];
      DataTypes.UserPosition storage userCollateralPosition = _userPositions[vars.user][
        vars.collateralReserveId
      ];
      DataTypes.UserPosition storage userDebtPosition = _userPositions[vars.user][
        vars.debtReserveId
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
        vars.user,
        debtsToCover[vars.i],
        vars.baseDebt,
        vars.premiumDebt
      );

      // repay debt
      _settlePremiumDebt(
        debtReserve,
        userDebtPosition,
        debtReserveHub,
        vars.debtAssetId,
        vars.debtReserveId,
        vars.user,
        vars.premiumDebtToLiquidate
      );
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
      vars.withdrawnShares = collateralReserveHub.previewRemoveByAssets(
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
      (vars.newUserRiskPremium, , , , ) = _calculateUserAccountData(vars.user);

      if (userDebtPosition.baseDrawnShares == 0) {
        _positionStatus[vars.user].setBorrowing(vars.debtReserveId, false);
      }

      vars.totalUserDebtPremiumDrawnSharesDelta += int256(vars.userPremiumDrawnShares);
      vars.totalUserDebtPremiumOffsetDelta += int256(vars.userPremiumOffset);

      _notifyRiskPremiumUpdate(vars.user, vars.newUserRiskPremium);

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

    debtReserveHub.refreshPremiumDebt(
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
