// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {AccessManagedUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/AccessManagedUpgradeable.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpokeBase, ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title Spoke
/// @author Aave Labs
/// @notice Handles risk configuration & borrowing strategy for reserves and user positions.
/// @dev Each reserve can be associated with a separate hub.
abstract contract Spoke is ISpoke, Multicall, NoncesKeyed, AccessManagedUpgradeable, EIP712 {
  using SafeCast for *;
  using WadRayMath for uint256;
  using PercentageMath for *;
  using KeyValueList for KeyValueList.List;
  using PositionStatusMap for *;
  using MathUtils for *;

  /// @inheritdoc ISpoke
  uint256 public constant MAX_ALLOWED_ASSET_ID = type(uint16).max;

  /// @inheritdoc ISpoke
  uint24 public constant MAX_ALLOWED_COLLATERAL_RISK = 1000_00; // 1000.00%

  /// @inheritdoc ISpoke
  bytes32 public constant SET_USER_POSITION_MANAGER_TYPEHASH =
    // keccak256('SetUserPositionManager(address positionManager,address user,bool approve,uint256 nonce,uint256 deadline)')
    0x758d23a3c07218b7ea0b4f7f63903c4e9d5cbde72d3bcfe3e9896639025a0214;

  /// @inheritdoc ISpoke
  uint64 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD =
    LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;

  /// @inheritdoc ISpoke
  uint256 public constant DUST_DEBT_LIQUIDATION_THRESHOLD =
    LiquidationLogic.DUST_DEBT_LIQUIDATION_THRESHOLD;

  /// @inheritdoc ISpoke
  uint8 public constant ORACLE_DECIMALS = 8;

  /// @inheritdoc ISpoke
  address public immutable ORACLE;

  uint256 internal _reserveCount;
  mapping(address user => mapping(uint256 reserveId => UserPosition)) internal _userPositions;
  mapping(address user => PositionStatus) internal _positionStatus;
  mapping(uint256 reserveId => Reserve) internal _reserves;
  mapping(address positionManager => PositionManagerConfig) internal _positionManager;
  mapping(uint256 reserveId => mapping(uint16 configKey => DynamicReserveConfig))
    internal _dynamicConfig; // dictionary of dynamic configs per reserve
  LiquidationConfig internal _liquidationConfig;
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

  function initialize(address _authority) external virtual;

  /// @inheritdoc ISpoke
  function updateReservePriceSource(uint256 reserveId, address priceSource) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _updateReservePriceSource(reserveId, priceSource);
  }

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
    uint16 dynamicConfigKey; // 0 as first key to use

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
  function addDynamicReserveConfig(
    uint256 reserveId,
    DynamicReserveConfig calldata dynamicConfig
  ) external restricted returns (uint16) {
    require(reserveId < _reserveCount, ReserveNotListed());
    _validateDynamicReserveConfig(dynamicConfig);
    uint16 configKey;
    // @dev overflow is desired, we implicitly invalidate & override stale config
    unchecked {
      configKey = ++_reserves[reserveId].dynamicConfigKey;
    }
    _dynamicConfig[reserveId][configKey] = dynamicConfig;
    emit AddDynamicReserveConfig(reserveId, configKey, dynamicConfig);
    return configKey;
  }

  /// @inheritdoc ISpoke
  function updateDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey,
    DynamicReserveConfig calldata dynamicConfig
  ) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _validateUpdateDynamicReserveConfig(_dynamicConfig[reserveId][configKey], dynamicConfig);
    _dynamicConfig[reserveId][configKey] = dynamicConfig;
    emit UpdateDynamicReserveConfig(reserveId, configKey, dynamicConfig);
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
  ) external onlyPositionManager(onBehalfOf) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
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
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    _validateWithdraw(reserve);
    IHubBase hub = reserve.hub;
    uint256 assetId = reserve.assetId;

    uint256 withdrawAmount = MathUtils.min(
      amount,
      hub.previewRemoveByShares(assetId, userPosition.suppliedShares)
    );
    uint256 withdrawnShares = hub.remove(assetId, withdrawAmount, msg.sender);

    userPosition.suppliedShares -= withdrawnShares.toUint128();

    if (_positionStatus[onBehalfOf].isUsingAsCollateral(reserveId)) {
      uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf);
      _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);
    }

    emit Withdraw(reserveId, msg.sender, onBehalfOf, withdrawnShares);
  }

  /// @inheritdoc ISpokeBase
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    _validateBorrow(reserve);
    IHubBase hub = reserve.hub;

    uint256 drawnShares = hub.draw(reserve.assetId, amount, msg.sender);
    userPosition.drawnShares += drawnShares.toUint128();
    if (!positionStatus.isBorrowing(reserveId)) {
      positionStatus.setBorrowing(reserveId, true);
    }

    uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf);
    _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);

    emit Borrow(reserveId, msg.sender, onBehalfOf, drawnShares);
  }

  /// @inheritdoc ISpokeBase
  function repay(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    _validateRepay(reserve);
    IHubBase hub = reserve.hub;
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

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
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

    UserAccountData memory userAccountData = _calculateUserAccountData(onBehalfOf);
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
    UserAccountData memory userAccountData = _calculateUserAccountData(user);
    LiquidationLogic.LiquidateUserParams memory params = LiquidationLogic.LiquidateUserParams({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      oracle: ORACLE,
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

    DynamicReserveConfig storage collateralDynConfig = _dynamicConfig[collateralReserveId][
      _userPositions[user][collateralReserveId].configKey
    ];

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
    _validateSetUsingAsCollateral(_reserves[reserveId], usingAsCollateral);
    PositionStatus storage positionStatus = _positionStatus[onBehalfOf];

    if (positionStatus.isUsingAsCollateral(reserveId) == usingAsCollateral) return;
    positionStatus.setUsingAsCollateral(reserveId, usingAsCollateral);

    if (usingAsCollateral) {
      _refreshDynamicConfig(onBehalfOf, reserveId);
    } else {
      uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf);
      _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);
    }
    emit SetUsingAsCollateral(reserveId, msg.sender, onBehalfOf, usingAsCollateral);
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
    uint256 newUserRiskPremium = _refreshAndValidateUserPosition(onBehalfOf);
    _notifyRiskPremiumUpdate(onBehalfOf, newUserRiskPremium);
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
    bytes32 hash = _hashTypedData(
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
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, nonce);
    _setUserPositionManager({positionManager: positionManager, user: user, approve: approve});
  }

  /// @inheritdoc ISpoke
  function renouncePositionManagerRole(address onBehalfOf) external {
    if (!_positionManager[msg.sender].approval[onBehalfOf]) return;
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
    Reserve storage reserve = _reserves[reserveId];
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
  function getLiquidationLogic() public pure returns (address) {
    return address(LiquidationLogic);
  }

  /// @inheritdoc ISpoke
  function isPositionManager(address user, address positionManager) external view returns (bool) {
    return _isPositionManager(user, positionManager);
  }

  /// @inheritdoc ISpoke
  function isPositionManagerActive(address positionManager) external view returns (bool) {
    return _positionManager[positionManager].active;
  }

  /// @inheritdoc ISpoke
  function isUsingAsCollateral(uint256 reserveId, address user) external view returns (bool) {
    _getReserve(reserveId);
    return _positionStatus[user].isUsingAsCollateral(reserveId);
  }

  /// @inheritdoc ISpoke
  function isBorrowing(uint256 reserveId, address user) external view returns (bool) {
    _getReserve(reserveId);
    return _positionStatus[user].isBorrowing(reserveId);
  }

  /// @inheritdoc ISpokeBase
  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[user][reserveId];
    (uint256 drawnDebt, uint256 premiumDebt, ) = _getUserDebt(
      reserve.hub,
      reserve.assetId,
      userPosition
    );
    return (drawnDebt, premiumDebt);
  }

  /// @inheritdoc ISpokeBase
  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256) {
    Reserve storage reserve = _getReserve(reserveId);
    UserPosition storage userPosition = _userPositions[user][reserveId];
    (uint256 drawnDebt, uint256 premiumDebt, ) = _getUserDebt(
      reserve.hub,
      reserve.assetId,
      userPosition
    );
    return drawnDebt + premiumDebt;
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

  /// @inheritdoc ISpoke
  function getReserveCount() external view returns (uint256) {
    return _reserveCount;
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
        maxLiquidationBonus: _dynamicConfig[reserveId][_userPositions[user][reserveId].configKey]
          .maxLiquidationBonus
      });
  }

  /// @inheritdoc ISpoke
  function getLiquidationConfig() external view returns (LiquidationConfig memory) {
    return _liquidationConfig;
  }

  /// @inheritdoc ISpoke
  function getUserAccountData(address user) external view returns (UserAccountData memory) {
    return _calculateUserAccountData(user);
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
    uint256 reserveId
  ) external view returns (DynamicReserveConfig memory) {
    Reserve storage reserve = _getReserve(reserveId);
    return _dynamicConfig[reserveId][reserve.dynamicConfigKey];
  }

  /// @inheritdoc ISpoke
  function getDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey
  ) external view returns (DynamicReserveConfig memory) {
    _getReserve(reserveId);
    // @dev we do not revert if key is unset
    return _dynamicConfig[reserveId][configKey];
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
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
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

  function _updateReservePriceSource(uint256 reserveId, address priceSource) internal {
    require(priceSource != address(0), InvalidAddress());
    IAaveOracle(ORACLE).setReserveSource(reserveId, priceSource);
    emit UpdateReservePriceSource(reserveId, priceSource);
  }

  /// @notice Refreshes user dynamic configuration and checks the position is healthy.
  /// @return The user's new risk premium.
  function _refreshAndValidateUserPosition(address user) internal returns (uint256) {
    UserAccountData memory accountData = _calculateAndRefreshUserAccountData(user);
    require(
      accountData.healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      HealthFactorBelowThreshold()
    );
    return accountData.userRiskPremium;
  }

  function _validateReserveConfig(ReserveConfig calldata config) internal pure {
    require(config.collateralRisk <= MAX_ALLOWED_COLLATERAL_RISK, InvalidCollateralRisk());
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

  function _validateSetUsingAsCollateral(
    Reserve storage reserve,
    bool usingAsCollateral
  ) internal view {
    require(address(reserve.hub) != address(0), ReserveNotListed());
    require(!reserve.paused, ReservePaused());
    // can disable as collateral if the reserve is frozen
    require(!usingAsCollateral || !reserve.frozen, ReserveFrozen());
  }

  function _getReserve(uint256 reserveId) internal view returns (Reserve storage) {
    Reserve storage reserve = _reserves[reserveId];
    require(address(reserve.hub) != address(0), ReserveNotListed());
    return reserve;
  }

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

  /// @notice Settles the premium debt by realizing change in premium and resetting premium shares and offset.
  function _settlePremiumDebt(UserPosition storage userPosition, int256 realizedDelta) internal {
    userPosition.premiumShares = 0;
    userPosition.premiumOffset = 0;
    userPosition.realizedPremium = userPosition.realizedPremium.add(realizedDelta).toUint128();
  }

  /// @notice Returns whether `manager` is active & approved positionManager for `user`.
  function _isPositionManager(address user, address manager) private view returns (bool) {
    if (user == manager) return true;
    PositionManagerConfig storage config = _positionManager[manager];
    return config.active && config.approval[user];
  }

  function _calculateUserAccountData(address user) internal view returns (UserAccountData memory) {
    // SAFETY: function does not modify state when refreshConfig is false.
    return _castToView(_calculateAndPotentiallyRefreshUserAccountData)(user, false);
  }

  /// @notice Refreshes the dynamic config and calculates the user account data.
  function _calculateAndRefreshUserAccountData(
    address user
  ) internal returns (UserAccountData memory) {
    UserAccountData memory accountData = _calculateAndPotentiallyRefreshUserAccountData(user, true);
    emit RefreshAllUserDynamicConfig(user);
    return accountData;
  }

  /// @notice Refreshes the dynamic config and calculates the user account data if `refreshConfig` is true.
  /// @dev User RiskPremium calc runs until the first of either debt or collateral is exhausted.
  function _calculateAndPotentiallyRefreshUserAccountData(
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
            ? (userPosition.configKey = reserve.dynamicConfigKey)
            : userPosition.configKey
        ].collateralFactor;
        if (collateralFactor > 0) {
          uint256 suppliedShares = userPosition.suppliedShares;
          if (suppliedShares > 0) {
            // cannot round down to zero
            uint256 userCollateralInBaseCurrency = (reserve.hub.previewRemoveByShares(
              reserve.assetId,
              suppliedShares
            ) * assetPrice).wadDivDown(assetUnit);
            accountData.totalCollateralInBaseCurrency += userCollateralInBaseCurrency;
            collateralInfo.add(
              accountData.suppliedCollateralsCount,
              reserve.collateralRisk,
              userCollateralInBaseCurrency
            );
            accountData.avgCollateralFactor += collateralFactor * userCollateralInBaseCurrency;
            accountData.suppliedCollateralsCount = accountData
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
        // we can simplify since there is no precision loss due to the division here
        accountData.totalDebtInBaseCurrency += ((drawnDebt + premiumDebt) * assetPrice).wadDivUp(
          assetUnit
        );
        accountData.borrowedReservesCount = accountData.borrowedReservesCount.uncheckedAdd(1);
      }
    }

    // at this point avgCollateralFactor is the weighted sum of collateral scaled by collateralFactor
    // (avgCollateralFactor / totalCollateral) * totalCollateral can be simplified to avgCollateralFactor
    // strip BPS factor from result, because running avgCollateralFactor sum has been scaled by collateralFactor (in BPS) above
    accountData.healthFactor = accountData.totalDebtInBaseCurrency == 0
      ? type(uint256).max
      : accountData
        .avgCollateralFactor
        .wadDivDown(accountData.totalDebtInBaseCurrency)
        .fromBpsDown();

    // divide by total collateral to get avg collateral factor in wad
    accountData.avgCollateralFactor = accountData.totalCollateralInBaseCurrency == 0
      ? 0
      : accountData
        .avgCollateralFactor
        .wadDivDown(accountData.totalCollateralInBaseCurrency)
        .fromBpsDown();

    // running debt & collateral values used in risk premium calculation
    uint256 debtCounterInBaseCurrency = accountData.totalDebtInBaseCurrency;
    uint256 collateralCounterInBaseCurrency = 0;

    collateralInfo.sortByKey(); // sort by collateral risk in ASC, collateral value in DESC
    uint256 i = 0;
    while (i < collateralInfo.length() && debtCounterInBaseCurrency > 0) {
      (uint256 collateralRisk, uint256 userCollateralInBaseCurrency) = collateralInfo.get(i);
      userCollateralInBaseCurrency = userCollateralInBaseCurrency.min(debtCounterInBaseCurrency);
      accountData.userRiskPremium += userCollateralInBaseCurrency * collateralRisk;
      collateralCounterInBaseCurrency += userCollateralInBaseCurrency;
      debtCounterInBaseCurrency -= userCollateralInBaseCurrency;
      i = i.uncheckedAdd(1);
    }

    if (collateralCounterInBaseCurrency > 0) {
      accountData.userRiskPremium = accountData.userRiskPremium / collateralCounterInBaseCurrency;
    }

    return accountData;
  }

  /// @return The user's drawn debt.
  /// @return The user's premium debt.
  /// @return The user's accrued premium debt.
  function _getUserDebt(
    IHubBase hub,
    uint256 assetId,
    UserPosition storage userPosition
  ) internal view returns (uint256, uint256, uint256) {
    uint256 accruedPremium = hub.previewRestoreByShares(assetId, userPosition.premiumShares) -
      userPosition.premiumOffset;
    return (
      hub.previewRestoreByShares(assetId, userPosition.drawnShares),
      userPosition.realizedPremium + accruedPremium,
      accruedPremium
    );
  }

  /// @notice Refreshes premium for borrowed reserves of `user` with `newUserRiskPremium`.
  function _notifyRiskPremiumUpdate(address user, uint256 newUserRiskPremium) internal {
    PositionStatus storage positionStatus = _positionStatus[user];

    uint256 reserveId = _reserveCount;
    while ((reserveId = positionStatus.nextBorrowing(reserveId)) != PositionStatusMap.NOT_FOUND) {
      UserPosition storage userPosition = _userPositions[user][reserveId];
      Reserve storage reserve = _reserves[reserveId];
      uint256 assetId = reserve.assetId;
      IHubBase hub = reserve.hub;

      uint256 oldPremiumShares = userPosition.premiumShares;
      uint256 oldPremiumOffset = userPosition.premiumOffset;
      uint256 accruedPremium = hub.previewRestoreByShares(assetId, oldPremiumShares) -
        oldPremiumOffset;

      uint256 newPremiumShares = userPosition.drawnShares.percentMulUp(newUserRiskPremium);
      // uses opposite rounding direction as premiumOffset is virtual debt owed by the protocol
      uint256 newPremiumOffset = hub.previewDrawByShares(assetId, newPremiumShares);

      userPosition.premiumShares = newPremiumShares.toUint128();
      userPosition.premiumOffset = newPremiumOffset.toUint128();
      userPosition.realizedPremium += accruedPremium.toUint128();

      IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
        sharesDelta: newPremiumShares.signedSub(oldPremiumShares),
        offsetDelta: newPremiumOffset.signedSub(oldPremiumOffset),
        realizedDelta: accruedPremium.toInt256()
      });

      hub.refreshPremium(assetId, premiumDelta);
      emit RefreshPremiumDebt(reserveId, user, premiumDelta);
    }
    emit UpdateUserRiskPremium(user, newUserRiskPremium);
  }

  /// @notice Reports deficits for all debt reserves of the user, including the reserve being repaid during liquidation.
  /// @dev Deficit validation should already have occurred during liquidation.
  function _reportDeficit(address user) internal {
    PositionStatus storage positionStatus = _positionStatus[user];
    uint256 reserveId = _reserveCount;

    while ((reserveId = positionStatus.nextBorrowing(reserveId)) != PositionStatusMap.NOT_FOUND) {
      UserPosition storage userPosition = _userPositions[user][reserveId];
      Reserve storage reserve = _reserves[reserveId];
      IHubBase hub = reserve.hub;
      uint256 assetId = reserve.assetId;
      (
        uint256 drawnDebtReported,
        uint256 premiumDebtReported,
        uint256 accruedPremium
      ) = _getUserDebt(hub, assetId, userPosition);

      IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
        sharesDelta: -userPosition.premiumShares.toInt256(),
        offsetDelta: -userPosition.premiumOffset.toInt256(),
        realizedDelta: accruedPremium.toInt256() - premiumDebtReported.toInt256()
      });
      uint256 deficitShares = hub.reportDeficit(
        assetId,
        drawnDebtReported,
        premiumDebtReported,
        premiumDelta
      );
      _settlePremiumDebt(userPosition, premiumDelta.realizedDelta);
      userPosition.drawnShares -= deficitShares.toUint128();
      positionStatus.setBorrowing(reserveId, false);
    }
    // non-zero deficit means user ends up with zero total debt
    emit UpdateUserRiskPremium(user, 0);
  }

  function _refreshDynamicConfig(address user, uint256 reserveId) internal {
    _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
    emit RefreshSingleUserDynamicConfig(user, reserveId);
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('Spoke', '1');
  }

  function _setUserPositionManager(address positionManager, address user, bool approve) internal {
    PositionManagerConfig storage config = _positionManager[positionManager];
    // only allow approval when position manager is active for improved UX
    require(!approve || config.active, InactivePositionManager());
    config.approval[user] = approve;
    emit SetUserPositionManager(user, positionManager, approve);
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
