// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from 'forge-std/console2.sol';

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
// libraries
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
// interfaces
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';

contract Spoke is ISpoke {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;
  using LiquidationLogic for DataTypes.LiquidationConfig;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
  ILiquidityHub public immutable HUB;
  address internal _treasury;
  IPriceOracle public immutable oracle;

  mapping(address user => mapping(uint256 reserveId => DataTypes.UserPosition position))
    internal _userPositions;
  mapping(uint256 reserveId => DataTypes.Reserve reserveData) internal _reserves;
  DataTypes.LiquidationConfig internal _liquidationConfig;
  uint256[] public reservesList; // todo: rm, not needed
  uint256 public reserveCount;

  constructor(
    address hubAddress,
    address oracleAddress,
    address treasury,
    uint256 closeFactorValue
  ) {
    require(hubAddress != address(0), InvalidHubAddress());
    require(treasury != address(0), InvalidTreasuryAddress());
    require(oracleAddress != address(0), InvalidOracleAddress());
    // close factor is required, but variable liquidation bonus config is not
    _validateCloseFactor(closeFactorValue);

    HUB = ILiquidityHub(hubAddress);
    _liquidationConfig.closeFactor = closeFactorValue;
    _treasury = treasury;
    oracle = IPriceOracle(oracleAddress);
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
        liquidationProtocolFeePercentage: config.liquidationProtocolFeePercentage,
        borrowable: config.borrowable,
        collateral: config.collateral
      })
    });

    emit ReserveAdded(reserveId, assetId);

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
      liquidationProtocolFeePercentage: config.liquidationProtocolFeePercentage,
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
      -int256(userPremiumDrawnShares),
      -int256(userPremiumOffset),
      int256(accruedPremium)
    ); // unnecessary but we settle premium debt here
    uint256 withdrawnShares = HUB.remove(reserve.assetId, amount, to);

    userPosition.suppliedShares -= withdrawnShares;
    reserve.suppliedShares -= withdrawnShares;

    // calc needs new user position, just updating base debt is enough
    uint256 newUserRiskPremium = _validateUserPosition(msg.sender); // validates HF

    userPremiumDrawnShares = userPosition.premiumDrawnShares = userPosition
      .baseDrawnShares
      .percentMul(newUserRiskPremium);
    userPremiumOffset = userPosition.premiumOffset = HUB.convertToDrawnAssets(
      reserve.assetId,
      userPosition.premiumDrawnShares
    );

    _refreshPremiumDebt(reserve, int256(userPremiumDrawnShares), int256(userPremiumOffset), 0);
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
      -int256(userPremiumDrawnShares),
      -int256(userPremiumOffset),
      int256(accruedPremium)
    ); // unnecessary but we settle premium debt here
    uint256 baseDrawnShares = HUB.draw(assetId, amount, to);

    reserve.baseDrawnShares += baseDrawnShares;
    userPosition.baseDrawnShares += baseDrawnShares;

    // calc needs new user position, just updating base debt is enough
    uint256 newUserRiskPremium = _validateUserPosition(msg.sender); // validates HF

    userPremiumDrawnShares = userPosition.premiumDrawnShares = userPosition
      .baseDrawnShares
      .percentMul(newUserRiskPremium);
    userPremiumOffset = userPosition.premiumOffset = HUB.convertToDrawnAssets(
      reserve.assetId,
      userPosition.premiumDrawnShares
    );

    _refreshPremiumDebt(reserve, int256(userPremiumDrawnShares), int256(userPremiumOffset), 0);
    _notifyRiskPremiumUpdate(assetId, msg.sender, newUserRiskPremium);

    emit Borrow(reserveId, msg.sender, baseDrawnShares, to);
  }

  /// @inheritdoc ISpoke
  function repay(uint256 reserveId, uint256 amount) external {
    /// @dev TODO: onBehalfOf
    DataTypes.UserPosition storage userPosition = _userPositions[msg.sender][reserveId];
    DataTypes.Reserve storage reserve = _reserves[reserveId];

    (uint256 baseDebt, uint256 premiumDebt) = _getUserDebt(userPosition, reserve.assetId);
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

    _refreshPremiumDebt(
      reserve,
      -int256(userPremiumDrawnShares),
      -int256(userPremiumOffset),
      _signedDiff(userPosition.realizedPremium, userRealizedPremium)
    ); // we settle premium debt here
    uint256 restoredShares = HUB.restore(
      reserve.assetId,
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
    userPremiumOffset = userPosition.premiumOffset = HUB.convertToDrawnAssets(
      reserve.assetId,
      userPosition.premiumDrawnShares
    );

    _refreshPremiumDebt(reserve, int256(userPremiumDrawnShares), int256(userPremiumOffset), 0);
    _notifyRiskPremiumUpdate(reserve.assetId, msg.sender, newUserRiskPremium);

    emit Repay(reserveId, msg.sender, restoredShares);
  }

  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external {
    (
      address collateralAsset,
      address debtAsset,
      uint256 totalDebtToLiquidate,
      uint256 collateralToLiquidate,
      uint256 liquidationProtocolFeeAmount
    ) = _executeLiquidation(collateralReserveId, debtReserveId, user, debtToCover);

    // transfer to liquidator
    IERC20(collateralAsset).safeTransfer(msg.sender, collateralToLiquidate);
    // transfer to treasury
    if (liquidationProtocolFeeAmount > 0) {
      IERC20(collateralAsset).safeTransfer(_treasury, liquidationProtocolFeeAmount);
    }
    // console.log('emit LC: debt %e coll %e', totalDebtToLiquidate, collateralToLiquidate);
    emit LiquidationCall(
      collateralAsset,
      debtAsset,
      user,
      totalDebtToLiquidate,
      collateralToLiquidate,
      msg.sender
    );
  }

  /// @return collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation.
  /// @return debtAsset The address of the underlying borrowed asset to be repaid with the liquidation.
  /// @return totalDebtToLiquidate The total amount of debt to be repaid.
  /// @return collateralToLiquidate The amount of collateral to liquidate.
  /// @return liquidationProtocolFeeAmount The amount of protocol fee to liquidate.
  function _executeLiquidation(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) internal returns (address, address, uint256, uint256, uint256) {
    DataTypes.Reserve storage collateralReserve = _reserves[collateralReserveId];
    DataTypes.Reserve storage debtReserve = _reserves[debtReserveId];
    DataTypes.UserPosition storage userCollateralPosition = _userPositions[user][
      collateralReserveId
    ];
    DataTypes.UserPosition storage userDebtPosition = _userPositions[user][debtReserveId];

    DataTypes.ExecuteLiquidationLocalVars memory vars;
    vars.collateralAssetId = collateralReserve.assetId;
    vars.debtAssetId = debtReserve.assetId;
    (vars.baseDebt, vars.premiumDebt) = _getUserDebt(userDebtPosition, vars.debtAssetId);

    DataTypes.TempDebug memory debt;
    (debt.rBaseDebt, debt.rPremiumDebt) = _getReserveDebt(debtReserve);
    (debt.assetBaseDebt, debt.assetPremiumDebt) = _getReserveDebt(debtReserve);

    console.log('sp: initial debt %e %e', vars.baseDebt, vars.premiumDebt);
    console.log('sp: init debt reserve %e %e %e %e', debt.rBaseDebt, debt.rPremiumDebt);
    console.log('sp: init asset debt %e %e %e %e', debt.assetBaseDebt, debt.assetPremiumDebt);

    // DataTypes.TempDebug memory coll;
    // (coll.rBaseDebt, coll.rPremiumDebt) = _getReserveDebt(debtReserve);
    // (coll.assetBaseDebt, coll.assetPremiumDebt) = _getReserveDebt(debtReserve);

    // console.log('sp: init debt reserve %e %e %e %e', coll.rBaseDebt, debt.rPremiumDebt);
    // console.log('sp: init asset debt %e %e %e %e', debt.assetBaseDebt, debt.assetPremiumDebt);

    (
      vars.collateralToLiquidate,
      vars.liquidationProtocolFeeAmount,
      vars.baseDebtToLiquidate,
      vars.premiumDebtToLiquidate
    ) = _calculateLiquidationParameters(
      collateralReserve,
      debtReserve,
      // userDebtPosition,
      user,
      debtToCover,
      vars.baseDebt,
      vars.premiumDebt
    );

    // settle debt reserve's premium debt
    vars.userDebtPremiumDrawnShares = userDebtPosition.premiumDrawnShares;
    vars.userDebtPremiumOffset = userDebtPosition.premiumOffset;
    vars.userDebtRealizedPremium = userDebtPosition.realizedPremium;

    userDebtPosition.premiumDrawnShares = 0;
    userDebtPosition.premiumOffset = 0;
    userDebtPosition.realizedPremium = vars.premiumDebt - vars.premiumDebtToLiquidate;

    _refreshPremiumDebt(
      debtReserve,
      -int256(vars.userDebtPremiumDrawnShares),
      -int256(vars.userDebtPremiumOffset),
      _signedDiff(userDebtPosition.realizedPremium, vars.userDebtRealizedPremium)
    );

    // settle collateral reserve's premium debt
    vars.userCollateralPremiumDrawnShares = userCollateralPosition.premiumDrawnShares;
    vars.userCollateralPremiumOffset = userCollateralPosition.premiumOffset;
    vars.accruedCollateralPremium =
      HUB.convertToDrawnAssets(vars.collateralAssetId, vars.userCollateralPremiumDrawnShares) -
      vars.userCollateralPremiumOffset; // assets(premiumShares) - offset should never be < 0

    userCollateralPosition.premiumDrawnShares = 0;
    userCollateralPosition.premiumOffset = 0;
    userCollateralPosition.realizedPremium += vars.accruedCollateralPremium;

    _refreshPremiumDebt(
      collateralReserve,
      -int256(vars.userCollateralPremiumDrawnShares),
      -int256(vars.userCollateralPremiumOffset),
      int256(vars.accruedCollateralPremium)
    ); // unnecessary but we settle premium debt here for consistency

    // (vars.baseDebt, vars.premiumDebt) = _getUserDebt(userDebtPosition, vars.debtAssetId);
    // console.log('sp: debt reserve, after refresh debt %e %e', vars.baseDebt, vars.premiumDebt);

    // (debt.rBaseDebt, debt.rPremiumDebt) = _getReserveDebt(debtReserve);
    // (debt.assetBaseDebt, debt.assetPremiumDebt) = _getReserveDebt(debtReserve);

    // console.log('sp: after debt reserve %e %e %e %e', debt.rBaseDebt, debt.rPremiumDebt);
    // console.log('sp: after asset debt %e %e %e %e', debt.assetBaseDebt, debt.assetPremiumDebt);

    // repay debt
    vars.restoredShares = HUB.restore(
      vars.debtAssetId,
      vars.baseDebtToLiquidate,
      vars.premiumDebtToLiquidate,
      msg.sender
    );

    // debt accounting
    userDebtPosition.baseDrawnShares -= vars.restoredShares;
    debtReserve.baseDrawnShares -= vars.restoredShares;

    // liquidate collateral
    vars.withdrawnShares = HUB.remove(
      collateralReserve.assetId,
      vars.collateralToLiquidate + vars.liquidationProtocolFeeAmount,
      address(this) // must be sent to spoke first before distributing to treasury/liquidator
    );

    // collateral accounting
    userCollateralPosition.suppliedShares -= vars.withdrawnShares;
    collateralReserve.suppliedShares -= vars.withdrawnShares;

    (vars.newUserRiskPremium, , , , ) = _calculateUserAccountData(user);
    // console.log('user rp %e', vars.newUserRiskPremium);

    // refresh debt reserve premium
    vars.userDebtPremiumDrawnShares = userDebtPosition.premiumDrawnShares = userDebtPosition
      .baseDrawnShares
      .percentMul(vars.newUserRiskPremium);
    vars.userDebtPremiumOffset = userDebtPosition.premiumOffset = HUB.convertToDrawnAssets(
      vars.debtAssetId,
      userDebtPosition.premiumDrawnShares
    );
    _refreshPremiumDebt(
      debtReserve,
      int256(vars.userDebtPremiumDrawnShares),
      int256(vars.userDebtPremiumOffset),
      0
    );

    // refresh collateral reserve premium
    vars.userCollateralPremiumDrawnShares = userCollateralPosition
      .premiumDrawnShares = userCollateralPosition.baseDrawnShares.percentMul(
      vars.newUserRiskPremium
    );
    vars.userCollateralPremiumOffset = userCollateralPosition.premiumOffset = HUB
      .convertToDrawnAssets(vars.collateralAssetId, userCollateralPosition.premiumDrawnShares);
    _refreshPremiumDebt(
      collateralReserve,
      int256(vars.userCollateralPremiumDrawnShares),
      int256(vars.userCollateralPremiumOffset),
      0
    );

    _notifyRiskPremiumUpdate(vars.debtAssetId, user, vars.newUserRiskPremium);

    // address collateralAsset = collateralReserve.asset;
    // address debtAsset = debtReserve.asset;

    // // transfer to liquidator
    // IERC20(collateralAsset).safeTransfer(msg.sender, vars.collateralToLiquidate);
    // // transfer to treasury
    // if (vars.liquidationProtocolFeeAmount > 0) {
    //   IERC20(debtAsset).safeTransfer(_treasury, vars.liquidationProtocolFeeAmount);
    // }

    // emit LiquidationCall(
    //   collateralAsset,
    //   debtAsset,
    //   user,
    //   vars.baseDebtToLiquidate + vars.premiumDebtToLiquidate,
    //   vars.collateralToLiquidate,
    //   msg.sender
    // );

    console.log(
      'emit LC: debt %e coll %e fee %e',
      vars.baseDebtToLiquidate + vars.premiumDebtToLiquidate,
      vars.collateralToLiquidate,
      vars.liquidationProtocolFeeAmount
    );
    return (
      collateralReserve.asset,
      debtReserve.asset,
      vars.baseDebtToLiquidate + vars.premiumDebtToLiquidate,
      vars.collateralToLiquidate,
      vars.liquidationProtocolFeeAmount
    );
  }

  /// @return actualCollateralToLiquidate The amount of collateral to liquidate.
  /// @return liquidationProtocolFeeAmount The amount of protocol fee to liquidate.
  /// @return actualBaseDebtToLiquidate The amount of base debt to liquidate.
  /// @return actualPremiumDebtToLiquidate The amount of premium debt to liquidate.
  function _calculateLiquidationParameters(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    // DataTypes.UserPosition storage userDebtPosition,
    address user,
    uint256 debtToCover,
    uint256 baseDebt,
    uint256 premiumDebt
  ) internal returns (uint256, uint256, uint256, uint256) {
    DataTypes.LiquidationCallLocalVars memory vars;
    vars.collateralReserveId = collateralReserve.reserveId;
    vars.debtReserveId = debtReserve.reserveId;
    vars.userCollateralBalance = getUserSuppliedAmount(vars.collateralReserveId, user);

    // (vars.baseDebt, vars.premiumDebt) = _getUserDebt(userDebtPosition, debtReserve.assetId);
    vars.totalDebt = baseDebt + premiumDebt;

    (
      ,
      vars.avgCollateralFactor,
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
      vars.healthFactor
    );

    vars.debtAssetPrice = IPriceOracle(oracle).getAssetPrice(debtReserve.assetId);
    vars.debtAssetUnit = 10 ** debtReserve.config.decimals;
    vars.liquidationBonus = getVariableLiquidationBonus(
      vars.collateralReserveId,
      vars.healthFactor
    );
    console.log('var lb: %e, hf: %e', vars.liquidationBonus, vars.healthFactor);
    vars.closeFactor = _liquidationConfig.closeFactor;
    vars.collateralFactor = collateralReserve.config.collateralFactor;
    // console.log('vars.liquidationBonus %e', vars.liquidationBonus);
    vars.collateralAssetPrice = oracle.getAssetPrice(collateralReserve.assetId);
    vars.collateralAssetUnit = 10 ** collateralReserve.config.decimals;
    // vars.debtAssetUnit = 10 ** debtReserve.config.decimals;
    vars.liquidationProtocolFeePercentage = collateralReserve
      .config
      .liquidationProtocolFeePercentage;

    vars.actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate({
      debtToCover: debtToCover,
      params: vars
    });

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = vars.calculateAvailableCollateralToLiquidate();

    if (
      vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount ==
      vars.userCollateralBalance
    ) {
      _setUsingAsCollateral(vars.collateralReserveId, user, false);
    }

    (vars.baseDebtToLiquidate, vars.premiumDebtToLiquidate) = _calculateRestoreAmount(
      vars.baseDebt,
      vars.premiumDebt,
      vars.actualDebtToLiquidate
    );

    return (
      vars.actualCollateralToLiquidate,
      vars.liquidationProtocolFeeAmount,
      vars.baseDebtToLiquidate,
      vars.premiumDebtToLiquidate
    );
  }

  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external {
    _setUsingAsCollateral(reserveId, msg.sender, usingAsCollateral);
  }

  function getUsingAsCollateral(uint256 reserveId, address user) external view returns (bool) {
    return _userPositions[user][reserveId].usingAsCollateral;
  }

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256) {
    return _getUserDebt(_userPositions[user][reserveId], _reserves[reserveId].assetId);
  }

  function getUserTotalDebt(uint256 reserveId, address user) public view returns (uint256) {
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

  function getUserSuppliedAmount(uint256 reserveId, address user) public view returns (uint256) {
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
    (
      userRiskPremium,
      avgCollateralFactor,
      healthFactor,
      totalCollateralInBaseCurrency,
      totalDebtInBaseCurrency
    ) = _calculateUserAccountData(user);
  }

  function RESERVE_TREASURY_ADDRESS() external view returns (address) {
    return _treasury;
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

  function _validateUserPosition(address userAddress) internal view returns (uint256) {
    (uint256 userRiskPremium, , uint256 healthFactor, , ) = _calculateUserAccountData(userAddress);

    console.log('sp healthFactor %e', healthFactor);

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
    require(
      config.liquidationProtocolFeePercentage <= PercentageMath.PERCENTAGE_FACTOR,
      InvalidLiquidationProtocolFeePercentage()
    );
  }

  function _validateLiquidationConfig(DataTypes.LiquidationConfig calldata config) internal view {
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

  function _validateCloseFactor(uint256 closeFactor) internal view {
    require(closeFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD, InvalidCloseFactor());
  }

  function _validateLiquidationCall(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    address user,
    uint256 debtToCover,
    uint256 totalDebt,
    uint256 healthFactor
  ) internal view {
    uint256 collateralReserveId = collateralReserve.reserveId;
    require(debtToCover > 0, InvalidDebtToCover());
    require(
      collateralReserve.asset != address(0) && debtReserve.asset != address(0),
      ReserveNotListed()
    );
    require(collateralReserve.config.active && debtReserve.config.active, ReserveNotActive());
    require(!collateralReserve.config.paused && !debtReserve.config.paused, ReservePaused());
    require(healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD, HealthFactorNotBelowThreshold());
    bool isCollateralEnabled = _usingAsCollateral(_userPositions[user][collateralReserveId]) &&
      getCollateralFactor(collateralReserveId) != 0;
    require(isCollateralEnabled, CollateralCannotBeLiquidated());
    require(totalDebt > 0, SpecifiedCurrencyNotBorrowedByUser());
  }

  function _calculateRestoreAmount(
    uint256 baseDebt,
    uint256 premiumDebt,
    uint256 amount
  ) internal view returns (uint256, uint256) {
    if (amount == type(uint256).max) {
      return (baseDebt, premiumDebt);
    }
    if (amount <= premiumDebt) {
      return (0, amount);
    }
    // todo ensure `amount` is not greater than total debt?
    return (amount - premiumDebt, premiumDebt);
  }

  function _refreshPremiumDebt(
    DataTypes.Reserve storage reserve,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  ) internal {
    reserve.premiumDrawnShares = _add(reserve.premiumDrawnShares, premiumDrawnSharesDelta);
    reserve.premiumOffset = _add(reserve.premiumOffset, premiumOffsetDelta);
    reserve.realizedPremium = _add(reserve.realizedPremium, realizedPremiumDelta);

    HUB.refreshPremiumDebt(
      reserve.assetId,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumDelta
    );

    emit RefreshPremiumDebt(
      reserve.reserveId,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumDelta
    );
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
      DataTypes.Reserve memory reserve = _reserves[vars.reserveId];
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

    // console.log(
    //   'total debt %e | avg CF %e | total coll %e',
    //   vars.totalDebtInBaseCurrency,
    //   vars.avgCollateralFactor,
    //   vars.totalCollateralInBaseCurrency
    // );

    // at this point avgCollateralFactor is a weighted sum of collateral scaled by collateralFactor
    // (avgCollateralFactor / totalCollateral) * totalCollateral can be simplified to avgCollateralFactor
    // strip BPS factor from result, because running avgCollateralFactor sum has been scaled by collateralFactor (in BPS) above
    vars.healthFactor = vars.totalDebtInBaseCurrency == 0
      ? type(uint256).max
      : vars.avgCollateralFactor.wadDiv(vars.totalDebtInBaseCurrency).fromBps(); // HF of 1 -> 1e18

    // console.log('Sp: avgCF %e', vars.avgCollateralFactor);
    // divide by total collateral to get avg collateral factor in wad
    vars.avgCollateralFactor = vars.totalCollateralInBaseCurrency == 0
      ? 0
      : vars.avgCollateralFactor.wadDiv(vars.totalCollateralInBaseCurrency);

    console.log('hf %e %e', vars.healthFactor, vars.avgCollateralFactor);

    // console.log('Sp: avgCF %e', vars.avgCollateralFactor);

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
    uint256 premiumDebt = userPosition.realizedPremium +
      (HUB.convertToDrawnAssets(assetId, userPosition.premiumDrawnShares) -
        userPosition.premiumOffset);

    // console.log(
    //   'sp user rp %e %e',
    //   userPosition.realizedPremium,
    //   (HUB.convertToDrawnAssets(assetId, userPosition.premiumDrawnShares) -
    //     userPosition.premiumOffset)
    // );
    return (HUB.convertToDrawnAssets(assetId, userPosition.baseDrawnShares), premiumDebt);
  }

  // todo rm reserve accounting here & fetch from hub
  function _getReserveDebt(
    DataTypes.Reserve storage reserve
  ) internal view returns (uint256, uint256) {
    uint256 assetId = reserve.assetId;
    uint256 premiumDebt = reserve.realizedPremium +
      (HUB.convertToDrawnAssets(assetId, reserve.premiumDrawnShares) - reserve.premiumOffset);
    return (HUB.convertToDrawnAssets(assetId, reserve.baseDrawnShares), premiumDebt);
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
  ) internal {
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
        userPosition.premiumOffset = HUB.convertToDrawnAssets(
          assetId,
          userPosition.premiumDrawnShares
        );
        userPosition.realizedPremium += accruedUserPremium;

        _refreshPremiumDebt(
          reserve,
          _signedDiff(userPosition.premiumDrawnShares, oldUserPremiumDrawnShares),
          _signedDiff(userPosition.premiumOffset, oldUserPremiumOffset),
          int256(accruedUserPremium)
        );
      }
      unchecked {
        ++reserveId;
      }
    }
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

  function _setUsingAsCollateral(uint256 reserveId, address user, bool usingAsCollateral) internal {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[user][reserveId];

    _validateSetUsingAsCollateral(reserve, userPosition, usingAsCollateral);
    userPosition.usingAsCollateral = usingAsCollateral;

    // consider updating user rp & notify here especially when deactivating collateral
    emit UsingAsCollateral(reserveId, user, usingAsCollateral);
  }

  // function _calculateActualDebtToLiquidate(
  //   // DataTypes.Reserve storage collateralReserve, // TODO: extract collateralFactor into params
  //   uint256 debtToCover,
  //   address user,
  //   uint256 debtReserveId,
  //   DataTypes.LiquidationCallLocalVars memory params
  // )
  //   internal
  //   view
  //   returns (
  //     // uint256 totalCollateralInBaseCurrency,
  //     // uint256 totalDebtInBaseCurrency,
  //     // uint256 avgCollateralFactor,
  //     // uint256 debtAssetPrice,
  //     // uint256 totalDebt,
  //     // uint256 healthFactor
  //     uint256
  //   )
  // {
  //   DataTypes.CalculateActualDebtToLiquidateLocalVars memory vars;
  //   vars.maxLiquidatableDebt = params.totalDebt;
  //   // vars.closeFactor = _liquidationConfig.closeFactor;

  //   // vars.hfScaledDebt = params.totalDebtInBaseCurrency.wadMul(params.closeFactor); // base currency
  //   // vars.weightedCollateral = (
  //   //   params.totalCollateralInBaseCurrency.wadMul(params.avgCollateralFactor)
  //   // ).fromBps(); // base currency, exact result
  //   // vars.weightedCollateral = (
  //   //   params.totalCollateralInBaseCurrency.percentMul(params.avgCollateralFactor.dewadify())
  //   // ); // base currency, with rounding

  //   // console.log(
  //   //   'vars.weightedCollateral %e %e %e',
  //   //   vars.weightedCollateral,
  //   //   params.totalCollateralInBaseCurrency.wadMul(params.avgCollateralFactor).dewadify()
  //   // );

  //   // console.log(
  //   //   'scaled/weighted %e %e %e',
  //   //   vars.hfScaledDebt,
  //   //   vars.weightedCollateral,
  //   //   params.avgCollateralFactor
  //   // );

  //   vars.liquidationBonusProduct = (params.liquidationBonus.wadify())
  //     .percentMul(params.collateralFactor)
  //     .fromBps(); // convert BPS to WAD;

  //   console.log(
  //     'vars.liquidationBonusProduct %e %e %e',
  //     vars.liquidationBonusProduct,
  //     params.collateralFactor,
  //     params.liquidationBonus
  //   );

  //   // amount of user debt that returns HF to closeFactor, in base currency
  //   // numerator cannot be negative if CF > liq threshold
  //   // check if denominator is negative
  //   vars.liquidationRecoveryDebt = params.closeFactor > vars.liquidationBonusProduct
  //     ? ((params.totalDebtInBaseCurrency.wadMul(params.closeFactor) -
  //       params.totalCollateralInBaseCurrency.percentMul(params.avgCollateralFactor.dewadify())) *
  //       params.debtAssetUnit) / (params.closeFactor - vars.liquidationBonusProduct)
  //     : params.totalDebtInBaseCurrency;

  //   // console.log('try %e  %e', collateralReserve.config.collateralFactor);

  //   // console.log(
  //   //   'vars.totalDebtInBaseCurrency %e %e %e',
  //   //   vars.closeFactor,
  //   //   params.totalDebtInBaseCurrency,
  //   //   params.totalCollateralInBaseCurrency
  //   // );

  //   // console.log(
  //   //   'hfScaledDebt  %e, weightedCollateral %e, maxLiquidatableDebt %e',
  //   //   vars.hfScaledDebt,
  //   //   vars.weightedCollateral,
  //   //   vars.maxLiquidatableDebt
  //   // );

  //   console.log('vars.liquidationRecoveryDebt %e', vars.liquidationRecoveryDebt);

  //   // console.log(
  //   //   'var lb %e',
  //   //   getVariableLiquidationBonus(collateralReserve.reserveId, params.healthFactor)
  //   // );

  //   // console.log(
  //   //   'vars.liquidationRecoveryDebt %e %e %e',
  //   //   params.totalDebtInBaseCurrency,
  //   //   vars.liquidationRecoveryDebt,
  //   //   vars.liquidationRecoveryDebt / params.debtAssetPrice
  //   // );

  //   // if liq recovery debt is bigger, then HF gets bigger, bc more debt is removed.
  //   // more debt removed, so less debt remains
  //   // so in HF denom is lower, making HF calc higher

  //   // convert from base currency to amount
  //   vars.liquidationRecoveryDebt = params.debtAssetPrice == 0
  //     ? type(uint256).max
  //     : vars.liquidationRecoveryDebt / params.debtAssetPrice;

  //   // console.log('vars.liquidationRecoveryDebt %e', vars.liquidationRecoveryDebt);
  //   // console.log('vars.maxLiquidatableDebt %e', vars.maxLiquidatableDebt);

  //   vars.maxLiquidatableDebt = vars.maxLiquidatableDebt > vars.liquidationRecoveryDebt
  //     ? vars.liquidationRecoveryDebt
  //     : vars.maxLiquidatableDebt;

  //   console.log(
  //     'debtToCover, vars.maxLiquidatableDebt %e %e',
  //     debtToCover,
  //     vars.maxLiquidatableDebt,
  //     params.totalDebt
  //   );

  //   vars.actualDebtToLiquidate = debtToCover > vars.maxLiquidatableDebt
  //     ? vars.maxLiquidatableDebt
  //     : debtToCover;

  //   console.log('vars.actualDebtToLiquidate', vars.actualDebtToLiquidate == debtToCover);
  //   return vars.actualDebtToLiquidate;
  // }

  /**
   * @return The maximum collateral amount that is possible to liquidate given all the liquidation config.
   * @return The debt amount to repay with the liquidation.
   * @return The fee amount taken from the liquidation bonus amount to be paid to the protocol.
   */
  function _calculateAvailableCollateralToLiquidate(
    // DataTypes.Reserve memory collateralReserve,
    // DataTypes.Reserve memory debtReserve,
    DataTypes.LiquidationCallLocalVars memory params
  )
    internal
    view
    returns (
      // uint256 actualDebtToLiquidate,
      // uint256 userCollateralBalance,
      // uint256 debtAssetPrice
      uint256,
      uint256,
      uint256
    )
  {
    DataTypes.CalculateAvailableCollateralToLiquidateLocalVars memory vars;
    // vars.collateralAssetPrice = oracle.getAssetPrice(collateralReserve.assetId);
    // vars.collateralAssetUnit = 10 ** collateralReserve.config.decimals;
    // vars.debtAssetUnit = 10 ** debtReserve.config.decimals;
    // vars.liquidationProtocolFeePercentage = collateralReserve
    //   .config
    //   .liquidationProtocolFeePercentage;

    // find collateral amount that corresponds to the debt to cover
    vars.baseCollateral =
      (params.debtAssetPrice * params.actualDebtToLiquidate * params.collateralAssetUnit) /
      (params.collateralAssetPrice * params.debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(params.liquidationBonus);

    if (vars.maxCollateralToLiquidate > params.userCollateralBalance) {
      // back calculate debt amount needed to cover the max allowed collateral
      vars.collateralAmount = params.userCollateralBalance;
      vars.debtAmountNeeded = ((params.collateralAssetPrice *
        vars.collateralAmount *
        params.debtAssetUnit) / (params.debtAssetPrice * params.collateralAssetUnit)).percentDiv(
          params.liquidationBonus
        );

      // console.log('vars.maxCollateralToLiquidate > params.userCollateralBalance');
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate;
      vars.debtAmountNeeded = params.actualDebtToLiquidate;
    }

    // console.log('baseCollateral %e', vars.baseCollateral, params.liquidationBonus);

    if (params.liquidationProtocolFeePercentage != 0) {
      vars.bonusCollateral =
        vars.collateralAmount -
        vars.collateralAmount.percentDiv(params.liquidationBonus);

      vars.liquidationProtocolFeeAmount = vars.bonusCollateral.percentMul(
        params.liquidationProtocolFeePercentage
      );

      console.log(
        'lpfp != 0, %e %e %e',
        vars.collateralAmount,
        vars.debtAmountNeeded,
        vars.liquidationProtocolFeeAmount
      );
      return (
        vars.collateralAmount - vars.liquidationProtocolFeeAmount,
        vars.debtAmountNeeded,
        vars.liquidationProtocolFeeAmount
      );
    } else {
      // console.log('lpfp = 0, %e %e', vars.collateralAmount, vars.debtAmountNeeded);
      return (vars.collateralAmount, vars.debtAmountNeeded, 0);
    }
  }
}
