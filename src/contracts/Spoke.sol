// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Multicall} from 'src/misc/Multicall.sol';

// libraries
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

// interfaces
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';

contract Spoke is ISpoke, Multicall {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;
  using LiquidationLogic for DataTypes.LiquidationConfig;

  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = WadRayMath.WAD;
  ILiquidityHub public immutable HUB;
  IPriceOracle public immutable oracle;

  mapping(address user => mapping(uint256 reserveId => DataTypes.UserPosition position))
    internal _userPositions;
  mapping(uint256 reserveId => DataTypes.Reserve reserveData) internal _reserves;
  DataTypes.LiquidationConfig internal _liquidationConfig;
  uint256[] public reservesList; // todo: rm, not needed
  uint256 public reserveCount;

  constructor(address hubAddress, address oracleAddress, uint256 closeFactorValue) {
    require(hubAddress != address(0), InvalidHubAddress());
    require(oracleAddress != address(0), InvalidOracleAddress());
    // close factor is required, but variable liquidation bonus config is not
    _validateCloseFactor(closeFactorValue);

    HUB = ILiquidityHub(hubAddress);
    oracle = IPriceOracle(oracleAddress);
    _liquidationConfig.closeFactor = closeFactorValue;
  }

  // /////
  // Governance
  // /////

  function updateLiquidationConfig(
    DataTypes.LiquidationConfig calldata liquidationConfig
  ) external {
    // TODO: AccessControl
    _validateLiquidationConfig(liquidationConfig);
    _liquidationConfig = liquidationConfig;
    emit LiquidationConfigUpdated(liquidationConfig);
  }

  function addReserve(
    uint256 assetId,
    DataTypes.ReserveConfig calldata config
  ) external returns (uint256) {
    _validateReserveConfig(config);
    address asset = address(HUB.assetsList(assetId)); // will revert on invalid assetId
    uint256 reserveId = reserveCount++;
    // TODO: AccessControl
    reservesList.push(reserveId);
    _reserves[reserveId] = DataTypes.Reserve({
      reserveId: reserveId,
      assetId: assetId,
      asset: asset,
      suppliedShares: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      config: DataTypes.ReserveConfig({
        decimals: config.decimals,
        active: config.active,
        frozen: config.frozen,
        paused: config.paused,
        collateralFactor: config.collateralFactor,
        liquidationBonus: config.liquidationBonus,
        liquidityPremium: config.liquidityPremium,
        borrowable: config.borrowable,
        collateral: config.collateral
      })
    });

    emit ReserveAdded(reserveId, assetId);
    emit ReserveConfigUpdated(reserveId, config);

    return reserveId;
  }

  function updateReserveConfig(
    uint256 reserveId,
    DataTypes.ReserveConfig calldata config
  ) external {
    // TODO: More sophisticated
    _validateReserveConfig(config);
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    require(reserve.asset != address(0), InvalidReserve());
    // TODO: AccessControl
    reserve.config = DataTypes.ReserveConfig({
      decimals: reserve.config.decimals, // decimals remains existing value
      active: config.active,
      frozen: config.frozen,
      paused: config.paused,
      collateralFactor: config.collateralFactor,
      liquidationBonus: config.liquidationBonus,
      liquidityPremium: config.liquidityPremium,
      borrowable: config.borrowable,
      collateral: config.collateral
    });

    emit ReserveConfigUpdated(reserveId, config);
  }

  // /////
  // Users
  // /////

  /// @inheritdoc ISpoke
  function supply(uint256 reserveId, uint256 amount) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[msg.sender][reserveId];

    _validateSupply(reserve, amount);

    uint256 suppliedShares = HUB.add(reserve.assetId, amount, msg.sender);

    userPosition.suppliedShares += suppliedShares;
    reserve.suppliedShares += suppliedShares;

    emit Supply(reserveId, msg.sender, suppliedShares);
  }

  /// @inheritdoc ISpoke
  function withdraw(uint256 reserveId, uint256 amount, address to) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[msg.sender][reserveId];
    uint256 assetId = reserve.assetId;

    // If uint256.max is passed, withdraw all user's supplied assets
    if (amount == type(uint256).max) {
      amount = HUB.convertToSuppliedAssets(assetId, userPosition.suppliedShares);
    }
    _validateWithdraw(reserve, userPosition, amount);

    uint256 userPremiumDrawnShares = userPosition.premiumDrawnShares;
    uint256 userPremiumOffset = userPosition.premiumOffset;
    uint256 accruedPremium = HUB.convertToDrawnAssets(assetId, userPremiumDrawnShares) -
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
      int256(accruedPremium)
    ); // unnecessary but we realize premium debt here
    uint256 withdrawnShares = HUB.remove(assetId, amount, to);

    userPosition.suppliedShares -= withdrawnShares;
    reserve.suppliedShares -= withdrawnShares;

    // calc needs new user position, just updating base debt is enough
    uint256 newUserRiskPremium = _validateUserPosition(msg.sender); // validates HF

    userPremiumDrawnShares = userPosition.premiumDrawnShares = userPosition
      .baseDrawnShares
      .percentMul(newUserRiskPremium);
    userPremiumOffset = userPosition.premiumOffset = HUB.previewOffset(
      assetId,
      userPosition.premiumDrawnShares
    );

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      int256(userPremiumDrawnShares),
      int256(userPremiumOffset),
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
    uint256 assetId = reserve.assetId;

    _validateBorrow(reserve, msg.sender);

    uint256 userPremiumDrawnShares = userPosition.premiumDrawnShares;
    uint256 userPremiumOffset = userPosition.premiumOffset;
    uint256 accruedPremium = HUB.convertToDrawnAssets(assetId, userPremiumDrawnShares) -
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
      int256(accruedPremium)
    ); // unnecessary but we realize premium debt here
    uint256 baseDrawnShares = HUB.draw(assetId, amount, to);

    reserve.baseDrawnShares += baseDrawnShares;
    userPosition.baseDrawnShares += baseDrawnShares;

    // calc needs new user position, just updating base debt is enough
    uint256 newUserRiskPremium = _validateUserPosition(msg.sender); // validates HF

    userPremiumDrawnShares = userPosition.premiumDrawnShares = userPosition
      .baseDrawnShares
      .percentMul(newUserRiskPremium);
    userPremiumOffset = userPosition.premiumOffset = HUB.previewOffset(
      assetId,
      userPosition.premiumDrawnShares
    );

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      int256(userPremiumDrawnShares),
      int256(userPremiumOffset),
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

    (uint256 baseDebt, uint256 premiumDebt) = _getUserDebt(userPosition, assetId);
    (uint256 baseDebtRestored, uint256 premiumDebtRestored) = _calculateRestoreAmount(
      baseDebt,
      premiumDebt,
      amount
    );
    _validateRepay(reserve);

    uint256 userPremiumDrawnShares = userPosition.premiumDrawnShares;
    uint256 userPremiumOffset = userPosition.premiumOffset;
    uint256 userRealizedPremium = userPosition.realizedPremium;

    userPosition.premiumDrawnShares = 0;
    userPosition.premiumOffset = 0;
    userPosition.realizedPremium = premiumDebt - premiumDebtRestored;

    _settlePremiumDebt(
      reserve,
      msg.sender,
      assetId,
      -int256(userPremiumDrawnShares),
      -int256(userPremiumOffset),
      _signedDiff(premiumDebt - premiumDebtRestored, userRealizedPremium)
    ); // we settle premium debt here
    uint256 restoredShares = HUB.restore(
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
      .percentMul(newUserRiskPremium);
    userPremiumOffset = userPosition.premiumOffset = HUB.previewOffset(
      assetId,
      userPosition.premiumDrawnShares
    );

    _refreshPremiumDebt(
      reserve,
      msg.sender,
      assetId,
      int256(userPremiumDrawnShares),
      int256(userPremiumOffset),
      0
    );
    _notifyRiskPremiumUpdate(assetId, msg.sender, newUserRiskPremium);

    emit Repay(reserveId, msg.sender, restoredShares);
  }

  /// @inheritdoc ISpoke
  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[msg.sender][reserveId];

    _validateSetUsingAsCollateral(reserve, userPosition, usingAsCollateral);
    userPosition.usingAsCollateral = usingAsCollateral;

    // consider updating user rp & notify here especially when deactivating collateral

    emit UsingAsCollateral(reserveId, msg.sender, usingAsCollateral);
  }

  /// @inheritdoc ISpoke
  function updateUserRiskPremium(address user) external {
    (uint256 userRiskPremium, , , , ) = _calculateUserAccountData(user);
    bool premiumIncrease = _notifyRiskPremiumUpdate(type(uint256).max, user, userRiskPremium);
    // todo allow authorized caller to increase as well
    require(msg.sender == user || !premiumIncrease, Unauthorized());
    emit UserRiskPremiumUpdate(user, userRiskPremium);
  }

  function getUsingAsCollateral(uint256 reserveId, address user) external view returns (bool) {
    return _userPositions[user][reserveId].usingAsCollateral;
  }

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    return _getUserDebt(_userPositions[user][reserveId], _reserves[reserveId].assetId);
  }

  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getUserDebt(
      _userPositions[user][reserveId],
      _reserves[reserveId].assetId
    );
    return baseDebt + premiumDebt;
  }

  function getReserveSuppliedAmount(uint256 reserveId) external view returns (uint256) {
    return
      HUB.convertToSuppliedAssets(
        _reserves[reserveId].assetId,
        _reserves[reserveId].suppliedShares
      );
  }

  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256) {
    return _reserves[reserveId].suppliedShares;
  }

  function getUserSuppliedAmount(uint256 reserveId, address user) external view returns (uint256) {
    return
      HUB.convertToSuppliedAssets(
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

  function getReservePrice(uint256 reserveId) public view returns (uint256) {
    return oracle.getAssetPrice(_reserves[reserveId].assetId);
  }

  function getLiquidityPremium(uint256 reserveId) public view returns (uint256) {
    return _reserves[reserveId].config.liquidityPremium;
  }

  function getCollateralFactor(uint256 reserveId) public view returns (uint256) {
    return _reserves[reserveId].config.collateralFactor;
  }

  function getVariableLiquidationBonus(
    uint256 reserveId,
    uint256 healthFactor
  ) public view returns (uint256) {
    return
      _liquidationConfig.calculate(
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
    (
      userRiskPremium,
      avgCollateralFactor,
      healthFactor,
      totalCollateralInBaseCurrency,
      totalDebtInBaseCurrency
    ) = _calculateUserAccountData(user);
  }

  // public
  function getReserve(uint256 reserveId) public view returns (DataTypes.Reserve memory) {
    return _reserves[reserveId];
  }

  function getUserPosition(
    uint256 reserveId,
    address user
  ) public view returns (DataTypes.UserPosition memory) {
    return _userPositions[user][reserveId];
  }

  // internal
  function _validateSupply(DataTypes.Reserve storage reserve, uint256 amount) internal view {
    require(reserve.asset != address(0), ReserveNotListed());
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    require(!reserve.config.frozen, ReserveFrozen());
  }

  function _validateWithdraw(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage userPosition,
    uint256 amount
  ) internal view {
    require(reserve.asset != address(0), ReserveNotListed());
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    uint256 suppliedAmount = HUB.convertToSuppliedAssets(
      reserve.assetId,
      userPosition.suppliedShares
    );
    require(amount <= suppliedAmount, InsufficientSupply(suppliedAmount));
  }

  function _validateBorrow(DataTypes.Reserve storage reserve, address userAddress) internal view {
    require(reserve.asset != address(0), ReserveNotListed());
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    require(!reserve.config.frozen, ReserveFrozen());
    require(reserve.config.borrowable, ReserveNotBorrowable(reserve.reserveId));
    // HF checked at the end of borrow action
  }

  // TODO: Place this and LH equivalent in a generic logic library
  function _validateRepay(DataTypes.Reserve storage reserve) internal view {
    require(reserve.asset != address(0), ReserveNotListed());
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    // todo validate user not trying to repay more
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
    int256 realizedPremiumDelta
  ) internal {
    _refresh(
      reserve,
      userAddress,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumDelta
    );
    HUB.refreshPremiumDebt(
      assetId,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumDelta
    );
  }

  function _settlePremiumDebt(
    DataTypes.Reserve storage reserve,
    address userAddress,
    uint256 assetId,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  ) internal {
    _refresh(
      reserve,
      userAddress,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumDelta
    );
    HUB.settlePremiumDebt(
      assetId,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumDelta
    );
  }

  function _refresh(
    DataTypes.Reserve storage reserve,
    address userAddress,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  ) internal {
    reserve.premiumDrawnShares = _add(reserve.premiumDrawnShares, premiumDrawnSharesDelta);
    reserve.premiumOffset = _add(reserve.premiumOffset, premiumOffsetDelta);
    reserve.realizedPremium = _add(reserve.realizedPremium, realizedPremiumDelta);

    emit RefreshPremiumDebt(
      reserve.reserveId,
      userAddress,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumDelta
    );
  }

  function _validateSetUsingAsCollateral(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage userPosition,
    bool usingAsCollateral
  ) internal view {
    require(reserve.config.active, ReserveNotActive());
    require(!reserve.config.paused, ReservePaused());
    require(reserve.config.collateral, ReserveCannotBeUsedAsCollateral(reserve.reserveId));
    // deactivation should be allowed
    require(!usingAsCollateral || !reserve.config.frozen, ReserveFrozen());
  }

  function _usingAsCollateral(
    DataTypes.UserPosition storage userPosition
  ) internal view returns (bool) {
    return userPosition.usingAsCollateral;
  }

  // todo opt: use bitmap
  function _isBorrowing(DataTypes.UserPosition storage userPosition) internal view returns (bool) {
    return userPosition.baseDrawnShares > 0;
  }

  // todo opt: use bitmap
  function _usingAsCollateralOrBorrowing(
    DataTypes.UserPosition storage userPosition
  ) internal view returns (bool) {
    return _usingAsCollateral(userPosition) || _isBorrowing(userPosition);
  }

  /// @dev User rp calc runs until the first of either debt or collateral is exhausted
  /// @return userRiskPremium
  /// @return avgCollateralFactor
  /// @return healthFactor
  /// @return totalCollateralInBaseCurrency
  /// @return totalDebtInBaseCurrency
  function _calculateUserAccountData(
    address userAddress
  ) internal view returns (uint256, uint256, uint256, uint256, uint256) {
    DataTypes.CalculateUserAccountDataVars memory vars;
    uint256 reservesListLength = reservesList.length;

    while (vars.reserveId < reservesListLength) {
      DataTypes.UserPosition storage userPosition = _userPositions[userAddress][vars.reserveId];

      if (!_usingAsCollateralOrBorrowing(userPosition)) {
        unchecked {
          ++vars.reserveId;
        }
        continue;
      }
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
      vars.assetId = reserve.assetId;

      vars.assetPrice = oracle.getAssetPrice(vars.assetId);
      unchecked {
        vars.assetUnit = 10 ** HUB.getAssetConfig(vars.assetId).decimals;
      }

      if (_usingAsCollateral(userPosition)) {
        // @dev opt: this can be extracted by counting number of set bits in a supplied (only) bitmap saving one loop
        unchecked {
          ++vars.collateralReserveCount;
        }
      }

      if (_isBorrowing(userPosition)) {
        vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
          userPosition,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit
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
      DataTypes.UserPosition storage userPosition = _userPositions[userAddress][vars.reserveId];
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
      if (_usingAsCollateral(userPosition)) {
        vars.assetId = reserve.assetId;
        vars.liquidityPremium = reserve.config.liquidityPremium;
        vars.assetPrice = oracle.getAssetPrice(vars.assetId);
        unchecked {
          vars.assetUnit = 10 ** HUB.getAssetConfig(vars.assetId).decimals;
        }
        vars.userCollateralInBaseCurrency = _getUserBalanceInBaseCurrency(
          userPosition,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit
        );

        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        list.add(vars.i, vars.liquidityPremium, vars.userCollateralInBaseCurrency);
        vars.avgCollateralFactor +=
          vars.userCollateralInBaseCurrency *
          reserve.config.collateralFactor;

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
      : vars.avgCollateralFactor.wadDiv(vars.totalCollateralInBaseCurrency).fromBps();

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
    uint256 assetUnit
  ) internal view returns (uint256) {
    (uint256 baseDebt, uint256 premiumDebt) = _getUserDebt(userPosition, assetId);
    return ((baseDebt + premiumDebt) * assetPrice).wadify() / assetUnit;
  }

  function _getUserBalanceInBaseCurrency(
    DataTypes.UserPosition storage userPosition,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return
      (HUB.convertToSuppliedAssets(assetId, userPosition.suppliedShares) * assetPrice).wadify() /
      assetUnit;
  }

  function _getUserDebt(
    DataTypes.UserPosition storage userPosition,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    uint256 accruedPremium = HUB.convertToDrawnAssets(assetId, userPosition.premiumDrawnShares) -
      userPosition.premiumOffset;
    return (
      HUB.convertToDrawnAssets(assetId, userPosition.baseDrawnShares),
      userPosition.realizedPremium + accruedPremium
    );
  }

  // todo rm reserve accounting here & fetch from hub
  function _getReserveDebt(
    DataTypes.Reserve storage reserve
  ) internal view returns (uint256, uint256) {
    uint256 assetId = reserve.assetId;
    uint256 accruedPremium = HUB.convertToDrawnAssets(assetId, reserve.premiumDrawnShares) -
      reserve.premiumOffset;
    return (
      HUB.convertToDrawnAssets(assetId, reserve.baseDrawnShares),
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
    address userAddress,
    uint256 newUserRiskPremium
  ) internal returns (bool) {
    bool premiumIncrease;
    uint256 reserveCount_ = reserveCount;
    uint256 reserveId;
    while (reserveId < reserveCount_) {
      DataTypes.UserPosition storage userPosition = _userPositions[userAddress][reserveId];
      DataTypes.Reserve storage reserve = _reserves[reserveId];
      uint256 assetId = reserve.assetId;
      // todo keep borrowed assets in transient storage/pass through?
      if (_isBorrowing(userPosition) && assetId != assetIdToAvoid) {
        uint256 oldUserPremiumDrawnShares = userPosition.premiumDrawnShares;
        uint256 oldUserPremiumOffset = userPosition.premiumOffset;
        uint256 accruedUserPremium = HUB.convertToDrawnAssets(assetId, oldUserPremiumDrawnShares) -
          oldUserPremiumOffset;

        userPosition.premiumDrawnShares = userPosition.baseDrawnShares.percentMul(
          newUserRiskPremium
        );
        userPosition.premiumOffset = HUB.previewOffset(assetId, userPosition.premiumDrawnShares);
        userPosition.realizedPremium += accruedUserPremium;

        int256 premiumDrawnSharesDelta = _signedDiff(
          userPosition.premiumDrawnShares,
          oldUserPremiumDrawnShares
        );
        if (!premiumIncrease) premiumIncrease = premiumDrawnSharesDelta > 0;

        _refreshPremiumDebt(
          reserve,
          userAddress,
          assetId,
          premiumDrawnSharesDelta,
          _signedDiff(userPosition.premiumOffset, oldUserPremiumOffset),
          int256(accruedUserPremium)
        );
      }
      unchecked {
        ++reserveId;
      }
    }
    return premiumIncrease;
  }

  function _validateUserPosition(address userAddress) internal view returns (uint256) {
    (uint256 userRiskPremium, , uint256 healthFactor, , ) = _calculateUserAccountData(userAddress);
    require(healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, HealthFactorBelowThreshold());
    return userRiskPremium;
  }

  function _validateReserveConfig(DataTypes.ReserveConfig calldata config) internal view {
    require(config.collateralFactor <= PercentageMath.PERCENTAGE_FACTOR, InvalidCollateralFactor()); // max 100.00%
    require(config.liquidationBonus >= PercentageMath.PERCENTAGE_FACTOR, InvalidLiquidationBonus()); // min 100.00%
    require(
      config.liquidityPremium <= PercentageMath.PERCENTAGE_FACTOR * 10,
      InvalidLiquidityPremium()
    ); // max 1000.00%
    require(config.decimals <= HUB.MAX_ALLOWED_ASSET_DECIMALS(), InvalidReserveDecimals());
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

  function _validateLiquidationConfig(DataTypes.LiquidationConfig calldata config) internal pure {
    _validateCloseFactor(config.closeFactor);
    // if liquidationBonusFactor == 0, then variable liquidation bonus will not be applied
    require(
      config.liquidationBonusFactor <= PercentageMath.PERCENTAGE_FACTOR,
      InvalidLiquidationBonusFactor()
    );
    // if healthFactorBonusThreshold == HEALTH_FACTOR_LIQUIDATION_THRESHOLD, then calculate will be undefined
    require(
      config.healthFactorBonusThreshold < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      InvalidHealthFactorBonusThreshold()
    );
  }

  function _validateCloseFactor(uint256 closeFactor) internal pure {
    require(closeFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, InvalidCloseFactor());
  }
}
