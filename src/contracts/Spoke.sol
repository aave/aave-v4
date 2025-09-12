// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Multicall} from 'src/misc/Multicall.sol';

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';
import {Constants} from 'src/libraries/helpers/Constants.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

import {IHub} from 'src/interfaces/IHub.sol';
import {ISpokeBase, ISpoke} from 'src/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/interfaces/IAaveOracle.sol';

contract Spoke is ISpoke, Multicall, AccessManaged, EIP712 {
  using SafeCast for *;
  using WadRayMath for uint256;
  using PercentageMath for *;
  using KeyValueListInMemory for KeyValueListInMemory.List;
  using PositionStatus for *;
  using MathUtils for *;

  IAaveOracle public oracle;

  uint256 internal _reserveCount;
  mapping(address user => mapping(uint256 reserveId => DataTypes.UserPosition position))
    internal _userPositions;
  mapping(address user => DataTypes.PositionStatus positionStatus) internal _positionStatus;
  mapping(uint256 reserveId => DataTypes.Reserve reserveData) internal _reserves;
  mapping(address positionManager => DataTypes.PositionManagerConfig) internal _positionManager;
  mapping(address user => uint256 nonce) internal _nonces;
  mapping(uint256 reserveId => mapping(uint16 configKey => DataTypes.DynamicReserveConfig config))
    internal _dynamicConfig; // dictionary of dynamic configs per reserve
  DataTypes.LiquidationConfig internal _liquidationConfig;
  mapping(address hub => mapping(uint256 assetId => bool exists)) internal _reserveExists;

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
    require(authority_ != address(0), InvalidAddress());
    _liquidationConfig.targetHealthFactor = Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    emit LiquidationConfigUpdate(_liquidationConfig);
  }

  // /////
  // Governance
  // /////

  /// @inheritdoc ISpoke
  function updateOracle(address newOracle) external restricted {
    oracle = IAaveOracle(newOracle);
    require(
      newOracle != address(0) && oracle.DECIMALS() == Constants.ORACLE_DECIMALS,
      InvalidOracle()
    );
    emit OracleUpdate(newOracle);
  }

  function updateReservePriceSource(uint256 reserveId, address priceSource) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _updateReservePriceSource(reserveId, priceSource);
  }

  function updateLiquidationConfig(
    DataTypes.LiquidationConfig calldata config
  ) external restricted {
    require(
      config.targetHealthFactor >= Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD &&
        config.liquidationBonusFactor <= PercentageMath.PERCENTAGE_FACTOR &&
        config.healthFactorForMaxBonus < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      InvalidLiquidationConfig()
    );
    _liquidationConfig = config;
    emit LiquidationConfigUpdate(config);
  }

  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    DataTypes.ReserveConfig calldata config,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint256) {
    require(hub != address(0), InvalidAddress());
    require(!_reserveExists[hub][assetId], ReserveExists());

    _validateReserveConfig(config);
    _validateDynamicReserveConfig(dynamicConfig);
    uint256 reserveId = _reserveCount++;
    uint16 dynamicConfigKey; // 0 as first key to use

    DataTypes.Asset memory asset = IHub(hub).getAsset(assetId);
    require(asset.underlying != address(0), AssetNotListed());

    _updateReservePriceSource(reserveId, priceSource);

    _reserves[reserveId] = DataTypes.Reserve({
      underlying: asset.underlying,
      hub: IHub(hub),
      assetId: assetId.toUint16(),
      decimals: asset.decimals,
      dynamicConfigKey: dynamicConfigKey,
      paused: config.paused,
      frozen: config.frozen,
      borrowable: config.borrowable,
      collateralRisk: config.collateralRisk
    });
    _dynamicConfig[reserveId][dynamicConfigKey] = dynamicConfig;
    _reserveExists[hub][assetId] = true;

    emit AddReserve(reserveId, assetId, hub);
    emit ReserveConfigUpdate(reserveId, config);
    emit AddDynamicReserveConfig(reserveId, dynamicConfigKey, dynamicConfig);

    return reserveId;
  }

  function updateReserveConfig(
    uint256 reserveId,
    DataTypes.ReserveConfig calldata config
  ) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    _validateReserveConfig(config);
    reserve.paused = config.paused;
    reserve.frozen = config.frozen;
    reserve.borrowable = config.borrowable;
    reserve.collateralRisk = config.collateralRisk;
    emit ReserveConfigUpdate(reserveId, config);
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
    emit AddDynamicReserveConfig(reserveId, configKey, dynamicConfig);
    return configKey;
  }

  /// @inheritdoc ISpoke
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    // @dev sufficient check since maxLiquidationBonus is always >= 100_00
    require(
      _dynamicConfig[reserveId][configKey].maxLiquidationBonus != 0,
      ConfigKeyUninitialized()
    );
    _validateDynamicReserveConfig(dynamicConfig);
    _dynamicConfig[reserveId][configKey] = dynamicConfig;
    emit UpdateDynamicReserveConfig(reserveId, configKey, dynamicConfig);
  }

  /// @inheritdoc ISpoke
  function updatePositionManager(address positionManager, bool active) external restricted {
    _positionManager[positionManager].active = active;
    emit UpdatePositionManager(positionManager, active);
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

    userPosition.suppliedShares += suppliedShares.toUint128();

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

    userPosition.suppliedShares -= withdrawnShares.toUint128();

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

    userPosition.drawnShares += drawnShares.toUint128();
    if (!positionStatus.isBorrowing(reserveId)) {
      positionStatus.setBorrowing(reserveId, true);
    }

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

    IHub hub = reserve.hub;
    uint256 assetId = reserve.assetId;
    (uint256 drawnDebtRestored, uint256 premiumDebtRestored, uint256 accruedPremium) = _getUserDebt(
      hub,
      assetId,
      userPosition
    );
    (drawnDebtRestored, premiumDebtRestored) = _calculateRestoreAmount(
      drawnDebtRestored,
      premiumDebtRestored,
      amount
    );

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: -userPosition.premiumShares.toInt256(),
      offsetDelta: -userPosition.premiumOffset.toInt256(),
      realizedDelta: accruedPremium.toInt256() - premiumDebtRestored.toInt256()
    });
    uint256 restoredShares = hub.restore(
      assetId,
      drawnDebtRestored,
      premiumDebtRestored,
      premiumDelta,
      msg.sender
    );

    _settlePremiumDebt(userPosition, premiumDelta.realizedDelta);
    userPosition.drawnShares -= restoredShares.toUint128();
    if (userPosition.drawnShares == 0) {
      _positionStatus[onBehalfOf].setBorrowing(reserveId, false);
    }

    DataTypes.UserAccountData memory userAccountData = _calculateUserAccountData(onBehalfOf);
    _notifyRiskPremiumUpdate(onBehalfOf, userAccountData.userRiskPremium);

    emit Repay(reserveId, msg.sender, onBehalfOf, restoredShares, premiumDelta);
  }

  /// @inheritdoc ISpokeBase
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external {
    DataTypes.UserAccountData memory userAccountData = _calculateUserAccountData(user);
    DataTypes.LiquidateUserParams memory params = DataTypes.LiquidateUserParams({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      oracle: address(oracle),
      user: user,
      debtToCover: debtToCover,
      healthFactor: userAccountData.healthFactor,
      drawnDebt: 0, // populated below
      premiumDebt: 0, // populated below
      accruedPremium: 0, // populated below
      totalDebtInBaseCurrency: userAccountData.totalDebtInBaseCurrency,
      suppliedCollateralsCount: userAccountData.suppliedCollateralsCount,
      borrowedReservesCount: userAccountData.borrowedReservesCount,
      liquidator: msg.sender
    });

    (params.drawnDebt, params.premiumDebt, params.accruedPremium) = _getUserDebt(
      _reserves[debtReserveId].hub,
      _reserves[debtReserveId].assetId,
      _userPositions[user][debtReserveId]
    );

    DataTypes.DynamicReserveConfig storage collateralDynConfig = _dynamicConfig[
      collateralReserveId
    ][_userPositions[user][collateralReserveId].configKey];

    bool isUserInDeficit = LiquidationLogic.liquidateUser(
      _reserves[collateralReserveId],
      _reserves[debtReserveId],
      _userPositions[user][collateralReserveId],
      _userPositions[user][debtReserveId],
      _positionStatus[user],
      _liquidationConfig,
      collateralDynConfig,
      params
    );

    if (isUserInDeficit) {
      _reportDeficit(user);
    } else {
      // new risk premium only needs to be propagated if no deficit exists
      _notifyRiskPremiumUpdate(user, _calculateUserAccountData(user).userRiskPremium);
    }
  }

  /// @inheritdoc ISpoke
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    // process only if collateral status changes
    if (positionStatus.isUsingAsCollateral(reserveId) == usingAsCollateral) return;

    DataTypes.Reserve storage reserve = _reserves[reserveId];
    _validateSetUsingAsCollateral(reserve, usingAsCollateral);

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
    if (!_isPositionManager({user: onBehalfOf, manager: msg.sender})) {
      _checkCanCall(msg.sender, msg.data);
    }
    _notifyRiskPremiumUpdate(onBehalfOf, _calculateUserAccountData(onBehalfOf).userRiskPremium);
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
    _setUserPositionManager({positionManager: positionManager, user: msg.sender, approve: approve});
  }

  /// @inheritdoc ISpoke
  function setUserPositionManagerWithSig(
    address positionManager,
    address user,
    bool approve,
    uint256 deadline,
    bytes memory signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          Constants.SET_USER_POSITION_MANAGER_TYPEHASH,
          positionManager,
          user,
          approve,
          _useNonce(user),
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _setUserPositionManager({positionManager: positionManager, user: user, approve: approve});
  }

  /// @inheritdoc ISpoke
  function useNonce() external {
    _useNonce(msg.sender);
  }

  /// @inheritdoc ISpoke
  function renouncePositionManagerRole(address onBehalfOf) external {
    _positionManager[msg.sender].approval[onBehalfOf] = false;
    emit SetUserPositionManager(onBehalfOf, msg.sender, false);
  }

  /// @inheritdoc ISpoke
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    address underlying = reserve.underlying;
    require(underlying != address(0), ReserveNotListed());
    try
      IERC20Permit(underlying).permit({
        owner: onBehalfOf,
        spender: address(reserve.hub),
        value: value,
        deadline: deadline,
        v: v,
        r: r,
        s: s
      })
    {} catch {}
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

  function getReserveSuppliedAmount(uint256 reserveId) external view returns (uint256) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    return reserve.hub.getSpokeAddedAmount(reserve.assetId, address(this));
  }

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
    DataTypes.UserAccountData memory userAccountData = _calculateUserAccountData(user);
    return userAccountData.userRiskPremium;
  }

  function getHealthFactor(address user) external view returns (uint256) {
    DataTypes.UserAccountData memory userAccountData = _calculateUserAccountData(user);
    return userAccountData.healthFactor;
  }

  function getLiquidationBonus(
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) external view returns (uint256) {
    return
      LiquidationLogic.calculateLiquidationBonus({
        healthFactorForMaxBonus: _liquidationConfig.healthFactorForMaxBonus,
        liquidationBonusFactor: _liquidationConfig.liquidationBonusFactor,
        healthFactor: healthFactor,
        maxLiquidationBonus: _dynamicConfig[reserveId][_userPositions[user][reserveId].configKey]
          .maxLiquidationBonus
      });
  }

  function getLiquidationConfig() external view returns (DataTypes.LiquidationConfig memory) {
    return _liquidationConfig;
  }

  function getUserAccountData(
    address user
  ) external view returns (DataTypes.UserAccountData memory) {
    return _calculateUserAccountData(user);
  }

  function getReserve(uint256 reserveId) external view returns (DataTypes.Reserve memory) {
    return _reserves[reserveId];
  }

  function getReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.ReserveConfig memory) {
    return
      DataTypes.ReserveConfig({
        paused: _reserves[reserveId].paused,
        frozen: _reserves[reserveId].frozen,
        borrowable: _reserves[reserveId].borrowable,
        collateralRisk: _reserves[reserveId].collateralRisk
      });
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

  function nonces(address user) external view returns (uint256) {
    return _nonces[user];
  }

  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  // internal
  function _validateSupply(DataTypes.Reserve storage reserve) internal view {
    require(address(reserve.hub) != address(0), ReserveNotListed());
    require(!reserve.paused, ReservePaused());
    require(!reserve.frozen, ReserveFrozen());
  }

  function _validateWithdraw(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage userPosition,
    uint256 amount
  ) internal view {
    require(address(reserve.hub) != address(0), ReserveNotListed());
    require(!reserve.paused, ReservePaused());
    uint256 suppliedAmount = reserve.hub.previewRemoveByShares(
      reserve.assetId,
      userPosition.suppliedShares
    );
    require(amount <= suppliedAmount, InsufficientSupply(suppliedAmount));
  }

  function _validateBorrow(DataTypes.Reserve storage reserve) internal view {
    require(address(reserve.hub) != address(0), ReserveNotListed());
    require(!reserve.paused, ReservePaused());
    require(!reserve.frozen, ReserveFrozen());
    require(reserve.borrowable, ReserveNotBorrowable());
    // HF checked at the end of borrow action
  }

  function _validateRepay(DataTypes.Reserve storage reserve) internal view {
    require(address(reserve.hub) != address(0), ReserveNotListed());
    require(!reserve.paused, ReservePaused());
  }

  /**
   * @dev Calculates the user's premium debt offset in assets amount from a given share amount.
   * @dev Rounds down to the nearest assets amount. Uses the opposite rounding direction of the
   * debt shares-to-assets conversion to prevent underflow in premium debt.
   */
  function _previewPremiumOffset(
    IHub hub,
    uint256 assetId,
    uint256 shares
  ) internal view returns (uint256) {
    return hub.previewDrawByShares(assetId, shares);
  }

  function _updateReservePriceSource(uint256 reserveId, address priceSource) internal {
    require(address(oracle) != address(0), InvalidAddress());
    oracle.setReserveSource(reserveId, priceSource);
    emit ReservePriceSourceUpdate(reserveId, priceSource);
  }

  function _refreshAndValidateUserPosition(address user) internal returns (uint256) {
    // @dev refresh user position dynamic config only on borrow, withdraw, disableUsingAsCollateral
    DataTypes.UserAccountData memory userAccountData = _calculateAndRefreshUserAccountData(user);
    require(
      userAccountData.healthFactor >= Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      HealthFactorBelowThreshold()
    );
    return userAccountData.userRiskPremium;
  }

  function _validateReserveConfig(DataTypes.ReserveConfig calldata config) internal pure {
    require(config.collateralRisk <= Constants.MAX_COLLATERAL_RISK, InvalidCollateralRisk());
  }

  function _validateDynamicReserveConfig(
    DataTypes.DynamicReserveConfig calldata config
  ) internal pure {
    // Enforce that at moment loan is taken, there should be enough collateral to cover liquidation
    require(
      config.collateralFactor <= PercentageMath.PERCENTAGE_FACTOR &&
        config.maxLiquidationBonus >= PercentageMath.PERCENTAGE_FACTOR &&
        config.maxLiquidationBonus.percentMulUp(config.collateralFactor) <
        PercentageMath.PERCENTAGE_FACTOR,
      InvalidCollateralFactorAndMaxLiquidationBonus()
    );
    require(config.liquidationFee <= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidationFee());
  }

  /**
   * @dev Validates the reserve can be set as collateral.
   * @dev Collateral can be disabled if the reserve is frozen.
   * @param reserve The reserve to be set as collateral.
   * @param usingAsCollateral True if enables the reserve as collateral, false otherwise.
   */
  function _validateSetUsingAsCollateral(
    DataTypes.Reserve storage reserve,
    bool usingAsCollateral
  ) internal view {
    require(address(reserve.hub) != address(0), ReserveNotListed());
    require(!reserve.paused, ReservePaused());
    // deactivation should be allowed
    require(!usingAsCollateral || !reserve.frozen, ReserveFrozen());
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
    int256 realizedDelta
  ) internal {
    userPosition.premiumShares = 0;
    userPosition.premiumOffset = 0;
    userPosition.realizedPremium = userPosition.realizedPremium.add(realizedDelta).toUint128();
  }

  function _isPositionManager(address user, address manager) private view returns (bool) {
    if (user == manager) return true;
    DataTypes.PositionManagerConfig storage config = _positionManager[manager];
    return config.active && config.approval[user];
  }

  function _calculateUserAccountData(
    address user
  ) internal view returns (DataTypes.UserAccountData memory) {
    // SAFETY: function does not modify state when refreshConfig is false
    return _castToView(_calculateAndPotentiallyRefreshUserAccountData)(user, false);
  }

  function _calculateAndRefreshUserAccountData(
    address user
  ) internal returns (DataTypes.UserAccountData memory userAccountData) {
    userAccountData = _calculateAndPotentiallyRefreshUserAccountData(user, true);
    emit RefreshAllUserDynamicConfig(user);
  }

  /**
   * @dev User rp calc runs until the first of either debt or collateral is exhausted
   * @param user address of the user
   * @return userAccountData
   */
  function _calculateAndPotentiallyRefreshUserAccountData(
    address user,
    bool refreshConfig
  ) internal returns (DataTypes.UserAccountData memory userAccountData) {
    IAaveOracle aaveOracle = oracle;
    uint256 reserveCount = _reserveCount;

    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(
      positionStatus.collateralCount(reserveCount)
    );

    uint256 reserveId;
    bool borrowing;
    bool collateral;
    while (true) {
      (reserveId, borrowing, collateral) = positionStatus.next(reserveId, reserveCount);
      if (reserveId == PositionStatus.NOT_FOUND) break;

      DataTypes.UserPosition storage userPosition = _userPositions[user][reserveId];
      DataTypes.Reserve storage reserve = _reserves[reserveId];

      uint256 assetPrice = aaveOracle.getReservePrice(reserveId);
      uint256 assetUnit = uint256(10).uncheckedExp(reserve.decimals);

      if (collateral) {
        uint256 collateralFactor = _dynamicConfig[reserveId][
          refreshConfig
            ? (userPosition.configKey = reserve.dynamicConfigKey)
            : userPosition.configKey
        ].collateralFactor;
        if (collateralFactor > 0) {
          uint256 userCollateralInBaseCurrency = (reserve.hub.previewRemoveByShares(
            reserve.assetId,
            userPosition.suppliedShares
          ) * assetPrice).wadDivDown(assetUnit);

          if (userCollateralInBaseCurrency > 0) {
            userAccountData.totalCollateralInBaseCurrency += userCollateralInBaseCurrency;
            list.add(
              userAccountData.suppliedCollateralsCount,
              reserve.collateralRisk,
              userCollateralInBaseCurrency
            );
            userAccountData.avgCollateralFactor += collateralFactor * userCollateralInBaseCurrency;
            userAccountData.suppliedCollateralsCount = userAccountData
              .suppliedCollateralsCount
              .uncheckedAdd(1);
          }
        }
      }

      if (borrowing) {
        (uint256 drawnDebt, uint256 premiumDebt, ) = _getUserDebt(
          reserve.hub,
          reserve.assetId,
          userPosition
        );
        userAccountData.totalDebtInBaseCurrency +=
          (drawnDebt * assetPrice).wadDivUp(assetUnit) +
          (premiumDebt * assetPrice).wadDivUp(assetUnit);
        userAccountData.borrowedReservesCount = userAccountData.borrowedReservesCount.uncheckedAdd(
          1
        );
      }

      reserveId = reserveId.uncheckedAdd(1);
    }

    // at this point avgCollateralFactor is a weighted sum of collateral scaled by collateralFactor
    // (avgCollateralFactor / totalCollateral) * totalCollateral can be simplified to avgCollateralFactor
    // strip BPS factor from result, because running avgCollateralFactor sum has been scaled by collateralFactor (in BPS) above
    userAccountData.healthFactor = userAccountData.totalDebtInBaseCurrency == 0
      ? type(uint256).max
      : userAccountData
        .avgCollateralFactor
        .wadDivDown(userAccountData.totalDebtInBaseCurrency)
        .fromBpsDown();

    // divide by total collateral to get avg collateral factor in wad
    userAccountData.avgCollateralFactor = userAccountData.totalCollateralInBaseCurrency == 0
      ? 0
      : userAccountData
        .avgCollateralFactor
        .wadDivDown(userAccountData.totalCollateralInBaseCurrency)
        .fromBpsDown();

    uint256 debtCounterInBaseCurrency = userAccountData.totalDebtInBaseCurrency;
    uint256 collateralCounterInBaseCurrency = 0;

    list.sortByKey(); // sort by collateral risk
    uint256 i = 0;
    // @dev from this point onwards, `collateralCounterInBaseCurrency` represents running collateral
    // value used in risk premium, `debtCounterInBaseCurrency` represents running outstanding debt
    while (i < list.length() && debtCounterInBaseCurrency > 0) {
      (uint256 collateralRisk, uint256 userCollateralInBaseCurrency) = list.get(i);
      if (userCollateralInBaseCurrency > debtCounterInBaseCurrency) {
        userCollateralInBaseCurrency = debtCounterInBaseCurrency;
      }
      userAccountData.userRiskPremium += userCollateralInBaseCurrency * collateralRisk;
      collateralCounterInBaseCurrency += userCollateralInBaseCurrency;
      debtCounterInBaseCurrency -= userCollateralInBaseCurrency;
      i = i.uncheckedAdd(1);
    }

    if (collateralCounterInBaseCurrency > 0) {
      userAccountData.userRiskPremium =
        userAccountData.userRiskPremium /
        collateralCounterInBaseCurrency;
    }

    return userAccountData;
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

  /**
   * @dev Trigger risk premium update on all drawn reserves of `user`.
   * @param user The address of the user whose risk premium is being updated.
   * @param newUserRiskPremium The new risk premium of the user.
   */
  function _notifyRiskPremiumUpdate(address user, uint256 newUserRiskPremium) internal {
    uint256 reserveCount = _reserveCount;
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];

    uint256 reserveId;
    while (
      (reserveId = positionStatus.nextBorrowing(reserveId, reserveCount)) !=
      PositionStatus.NOT_FOUND
    ) {
      DataTypes.UserPosition storage userPosition = _userPositions[user][reserveId];
      uint256 assetId = _reserves[reserveId].assetId;
      IHub hub = _reserves[reserveId].hub;

      uint256 oldUserPremiumShares = userPosition.premiumShares;
      uint256 oldUserPremiumOffset = userPosition.premiumOffset;
      uint256 accruedUserPremium = hub.previewRestoreByShares(assetId, oldUserPremiumShares) -
        oldUserPremiumOffset;

      uint256 newPremiumShares = (userPosition.premiumShares = userPosition
        .drawnShares
        .percentMulUp(newUserRiskPremium)
        .toUint128());
      uint256 newPremiumOffset = (userPosition.premiumOffset = _previewPremiumOffset(
        hub,
        assetId,
        userPosition.premiumShares
      ).toUint128());
      userPosition.realizedPremium += accruedUserPremium.toUint128();

      DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
        sharesDelta: newPremiumShares.signedSub(oldUserPremiumShares),
        offsetDelta: newPremiumOffset.signedSub(oldUserPremiumOffset),
        realizedDelta: accruedUserPremium.toInt256()
      });

      hub.refreshPremium(assetId, premiumDelta);
      emit RefreshPremiumDebt(reserveId, user, premiumDelta);
      reserveId = reserveId.uncheckedAdd(1);
    }
    emit UserRiskPremiumUpdate(user, newUserRiskPremium);
  }

  /**
   * @dev Reports deficits for all borrowing reserves of the user.
   * @dev Includes the debt reserve being repaid during liquidation.
   * @param user The address of the user whose deficits are being reported.
   */
  function _reportDeficit(address user) internal {
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];
    uint256 reserveCount = _reserveCount;
    uint256 reserveId;

    while (
      (reserveId = positionStatus.nextBorrowing(reserveId, reserveCount)) !=
      PositionStatus.NOT_FOUND
    ) {
      DataTypes.UserPosition storage userPosition = _userPositions[user][reserveId];
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
        sharesDelta: -userPosition.premiumShares.toInt256(),
        offsetDelta: -userPosition.premiumOffset.toInt256(),
        realizedDelta: accruedPremium.toInt256() - premiumDebtRestored.toInt256()
      });
      uint256 deficitShares = hub.reportDeficit(
        assetId,
        drawnDebtRestored,
        premiumDebtRestored,
        premiumDelta
      );
      _settlePremiumDebt(userPosition, premiumDelta.realizedDelta);
      userPosition.drawnShares -= deficitShares.toUint128();
      // newUserRiskPremium is 0 due to no collateral remaining
      // non-zero deficit means user ends up with zero total debt
      positionStatus.setBorrowing(reserveId, false);

      reserveId = reserveId.uncheckedAdd(1);
    }
    emit UserRiskPremiumUpdate(user, 0);
  }

  function _refreshDynamicConfig(address user) internal {
    uint256 reserveCount = _reserveCount;
    uint256 reserveId;
    DataTypes.PositionStatus storage positionStatus = _positionStatus[user];
    while (
      (reserveId = positionStatus.nextCollateral(reserveId, reserveCount)) !=
      PositionStatus.NOT_FOUND
    ) {
      _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;

      reserveId = reserveId.uncheckedAdd(1);
    }
    emit RefreshAllUserDynamicConfig(user);
  }

  function _refreshDynamicConfig(address user, uint256 reserveId) internal {
    _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
    emit RefreshSingleUserDynamicConfig(user, reserveId);
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('Spoke', '1');
  }

  function _useNonce(address user) internal returns (uint256) {
    unchecked {
      return _nonces[user]++;
    }
  }

  function _castToView(
    function(address, bool) internal returns (DataTypes.UserAccountData memory) fnIn
  )
    internal
    pure
    returns (function(address, bool) internal view returns (DataTypes.UserAccountData memory) fnOut)
  {
    assembly ('memory-safe') {
      fnOut := fnIn
    }
  }

  function _setUserPositionManager(address positionManager, address user, bool approve) internal {
    DataTypes.PositionManagerConfig storage config = _positionManager[positionManager];
    // @dev only allow approval when position manager is active for improved UX
    require(!approve || config.active, InactivePositionManager());
    config.approval[user] = approve;
    emit SetUserPositionManager(user, positionManager, approve);
  }
}
