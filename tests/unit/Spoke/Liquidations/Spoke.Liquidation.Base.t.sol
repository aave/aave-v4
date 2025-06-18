// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract SpokeLiquidationBase is SpokeBase {
  using WadRayMathExtended for uint256;
  using PercentageMathExtended for uint256;

  struct Balance {
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint256 balanceChange;
    uint256 baseChange;
  }

  struct ConvertedValues {
    uint256 base;
    uint256 amount;
  }

  struct SupplyExchangeRate {
    uint256 rateBefore;
    uint256 rateAfter;
  }

  struct LiquidationTestLocalParams {
    Balance liquidatorDebt;
    Balance liquidatorCollateral;
    Balance user;
    Balance treasury;
    Balance collateral;
    Balance debt;
    Balance supply;
    Balance supplyShares;
    uint256 liquidationBonus;
    uint256 collateralAssetId;
    uint256 debtAssetId;
    uint256 liquidationProtocolFee;
    DataTypes.DynamicReserveConfig collDynConfig;
    DataTypes.Reserve collateralReserve;
    DataTypes.Reserve debtReserve;
    DataTypes.DynamicReserveConfig[] collDynConfigs;
    DataTypes.Reserve[] collateralReserves;
    DataTypes.Reserve[] debtReserves;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 desiredHf;
    SupplyExchangeRate rate;
    uint256 collToLiq;
    uint256 debtToLiq;
    uint256 liqProtocolFee;
  }

  uint256 internal constant MIN_AMOUNT_IN_BASE_CURRENCY = 1e26;

  function setUp() public virtual override {
    super.setUp();
    _addBorrowableLiquidity(MAX_SUPPLY_AMOUNT);
  }

  /// @notice Deploys max borrowable liquidity for all reserves in spoke1.
  function _addBorrowableLiquidity(uint256 amount) public {
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _wethReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _wbtcReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _usdyReserveId(spoke1), amount);
  }

  /// bound liquidation config to full range of possible values
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    );
    liqConfig.healthFactorForMaxBonus = bound(
      liqConfig.healthFactorForMaxBonus,
      0.01e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    return liqConfig;
  }

  /// execute generic liquidation call fuzz test with a desired initial user health factor
  /// @param desiredHf Desired user health factor prior to liquidation.
  function _execLiqCallFuzzTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFee,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);
    state.collDynConfig = spoke1.getDynamicReserveConfig(collateralReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.01e18);
    liquidationProtocolFee = bound(liquidationProtocolFee, 0, 100_00);
    // bound supply amount to max supply amount
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, MIN_AMOUNT_IN_BASE_CURRENCY),
      _min(
        _convertBaseCurrencyToAmount(state.collateralReserve.assetId, MAX_SUPPLY_IN_BASE_CURRENCY),
        MAX_SUPPLY_AMOUNT
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.liquidationProtocolFee = liquidationProtocolFee;

    spoke1.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFee(spoke1, collateralReserveId, state.liquidationProtocolFee);

    if (!spoke1.getUsingAsCollateral(collateralReserveId, alice)) {
      Utils.supplyCollateral({
        spoke: spoke1,
        reserveId: collateralReserveId,
        user: alice,
        amount: supplyAmount,
        onBehalfOf: alice
      });
    } else {
      Utils.supply({
        spoke: spoke1,
        reserveId: collateralReserveId,
        user: alice,
        amount: supplyAmount,
        onBehalfOf: alice
      });
    }

    _increaseCollateralReserveSupplyExchangeRate(
      state.collateralReserve.assetId,
      collateralReserveId,
      supplyAmount / 2,
      skipTime,
      bob
    );

    vm.assume(
      _getRequiredDebtAmountForLtHf(spoke1, alice, debtReserveId, desiredHf) <= MAX_SUPPLY_AMOUNT
    );
    // borrow some amount of debt reserve to end up below hf threshold
    (uint256 hfAfterBorrow, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );
    state.liquidationBonus = spoke1.getVariableLiquidationBonus(collateralReserveId, hfAfterBorrow);

    state = _getAccountingInfoBeforeLiq(state);

    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee
    ) = _calculateAvailableCollateralToLiquidate(spoke1, state, requiredDebtAmount);

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationCall(
      state.collateralReserve.asset,
      state.debtReserve.asset,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state = _getAccountingInfoAfterLiq(state);

    // with a close factor, it is impossible to liquidate all debt
    assertTrue(
      stdMath.delta(state.debt.balanceAfter, state.debt.balanceBefore) < requiredDebtAmount
    );

    return state;
  }

  function _checkLiquidation(
    LiquidationTestLocalParams memory state,
    ISpoke spoke,
    string memory label
  ) internal view {
    _assertUserAccountData(state, spoke, label);
    _assertProtocolFeeEarned(state, label);
    _assertLiquidationBonusEarned(state, label);
    _assertSupplyExchangeRate(state, label);
    _assertSetUsingAsCollateral(spoke, alice, state, label);
  }

  /// assert that the user account data is correct after liquidation
  function _assertUserAccountData(
    LiquidationTestLocalParams memory state,
    ISpoke spoke,
    string memory label
  ) internal view virtual {
    (uint256 userRp, , uint256 finalHf, , ) = spoke1.getUserAccountData(alice);

    // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
    if (
      _convertAmountToBaseCurrency(state.debtReserve.assetId, state.debt.balanceAfter) >
      MIN_AMOUNT_IN_BASE_CURRENCY &&
      _convertAmountToBaseCurrency(state.collateralReserve.assetId, state.supply.balanceAfter) >
      MIN_AMOUNT_IN_BASE_CURRENCY
    ) {
      // ensure HF is lte close factor
      assertLe(
        finalHf,
        _getCloseFactor(spoke),
        string.concat('Health factor <= close factor ', label)
      );
      // should also be close to the desired CF
      assertApproxEqRel(
        finalHf,
        _getCloseFactor(spoke),
        _approxRelFromBps(20),
        'HF matches closeFactor within 0.1%'
      );
    } else if (state.supply.balanceAfter == 0 && state.debt.balanceAfter > 0) {
      // if bad debt, HF should be 0 and userRp should be 0
      assertEq(finalHf, 0, string.concat('HF = 0 if bad debt ', label));
      assertEq(userRp, 0, string.concat('userRp = 0 if bad debt ', label));
    } else {
      // HF should always be lte close factor
      assertLe(
        finalHf,
        _getCloseFactor(spoke),
        string.concat('Health factor <= close factor ', label)
      );
    }
  }

  // todo: utilize treasury accounting to assert protocol fee
  function _assertProtocolFeeEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    uint256 totalLiqBonusAmount = state.supply.balanceChange -
      state.supply.balanceChange.percentDivUp(state.liquidationBonus);
    uint256 liqProtocolFeeAmount = hub.convertToSuppliedAssets(
      state.collateralReserve.assetId,
      state.treasury.balanceChange // actual protocol fee shares, from tmp emitted event
    );
    // TODO: resolve precision loss difference
    assertApproxEqAbs(
      liqProtocolFeeAmount,
      totalLiqBonusAmount.percentMulUp(state.liquidationProtocolFee),
      3,
      string.concat('protocol fee amount ', label)
    );
  }

  function _assertLiquidationBonusEarned(
    LiquidationTestLocalParams memory state,
    // ConvertedValues memory totalLiqBonus,
    string memory label
  ) internal pure {
    uint256 totalLiqBonusAmount = state.supply.balanceChange -
      state.supply.balanceChange.percentDivDown(state.liquidationBonus);

    uint256 totalCollateralSeized = (state.collToLiq + state.liqProtocolFee);
    // liquidationBonus == PERCENTAGE_FACTOR represents liq bonus being 0
    uint256 expectedLiqBonusAmount = state.liquidationBonus != PercentageMath.PERCENTAGE_FACTOR
      ? totalCollateralSeized - totalCollateralSeized.percentDivDown(state.liquidationBonus)
      : 0;

    assertApproxEqRel(
      totalLiqBonusAmount,
      expectedLiqBonusAmount,
      _approxRelFromBps(20),
      string.concat('liquidationBonus earned in base currency, rel 20 bps ', label)
    );
  }

  /// check that if user's supplied amount becomes 0, reserve is no longer set usingAsCollateral
  function _assertSetUsingAsCollateral(
    ISpoke spoke,
    address user,
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    if (state.supplyShares.balanceAfter == 0) {
      assertFalse(
        spoke.getUsingAsCollateral(state.collateralReserve.reserveId, user),
        string.concat('isUsingAsCollateral should be false with no collateral ', label)
      );
    } else {
      assertTrue(
        spoke.getUsingAsCollateral(state.collateralReserve.reserveId, user),
        string.concat('isUsingAsCollateral should be true with remaining collateral ', label)
      );
    }
  }

  /// @notice Calculate output from LiquidationLogic.calculateAvailableCollateralToLiquidate.
  /// @param spoke Spoke contract.
  /// @param state LiquidationTestLocalParams struct containing local params.
  /// @param debtToCover Desired amount of debt to cover.
  /// @return actualCollateralToLiquidate Amount of actual collateral to liquidate.
  /// @return actualDebtToLiquidate Amount of actual debt to liquidate.
  /// @return liquidationProtocolFeeAmount Amount of protocol fee (in asset).
  function _calculateAvailableCollateralToLiquidate(
    ISpoke spoke,
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  )
    internal
    view
    returns (
      uint256 actualCollateralToLiquidate,
      uint256 actualDebtToLiquidate,
      uint256 liquidationProtocolFeeAmount
    )
  {
    DataTypes.LiquidationCallLocalVars memory params;

    params.userCollateralBalance = spoke.getUserSuppliedAmount(
      state.collateralReserve.reserveId,
      alice
    );
    params.collateralAssetUnit = 10 ** state.collateralReserve.config.decimals;
    params.collateralReserveId = state.collateralReserve.reserveId;
    params.collateralAssetPrice = oracle.getAssetPrice(state.collateralReserve.assetId);

    params.debtAssetUnit = 10 ** state.debtReserve.config.decimals;
    params.debtReserveId = state.debtReserve.reserveId;
    params.debtAssetPrice = oracle.getAssetPrice(state.debtReserve.assetId);

    params.liquidationBonus = state.liquidationBonus;
    params.liquidationProtocolFee = state.liquidationProtocolFee;

    params.actualDebtToLiquidate = _calculateActualDebtToLiquidate(spoke, state, debtToCover);

    return LiquidationLogic.calculateAvailableCollateralToLiquidate(params);
  }

  /// helper to calculate actual collateral to liquidate, replicating LiquidationLogic.calculateActualDebtToLiquidate.
  /// @return actualDebtToLiquidate Amount of actual debt to liquidate.
  function _calculateActualDebtToLiquidate(
    ISpoke spoke,
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  ) internal view returns (uint256 actualDebtToLiquidate) {
    // find minimum between user's totalDebt of debt asset, debtToCover, and debtToRestoreCloseFactor
    uint256 userTotalDebt = state.debt.balanceBefore;
    uint256 debtToRestoreCloseFactor = _calcDebtToRestoreCloseFactor(spoke, state);

    return _min(_min(userTotalDebt, debtToCover), debtToRestoreCloseFactor);
  }

  /// @notice Calculate amount of debt to liquidate to restore HF to close factor.
  /// @return debtToRestoreCloseFactor Amount of debt to liquidate to restore HF to close factor.
  function _calcDebtToRestoreCloseFactor(
    ISpoke spoke,
    LiquidationTestLocalParams memory state
  ) internal view returns (uint256 debtToRestoreCloseFactor) {
    DataTypes.LiquidationCallLocalVars memory params;

    params.liquidationBonus = state.liquidationBonus;
    params.collateralFactor = state.collDynConfig.collateralFactor;
    params.closeFactor = _getCloseFactor(spoke);

    params.debtAssetUnit = 10 ** state.debtReserve.config.decimals;
    params.debtAssetPrice = oracle.getAssetPrice(state.debtReserve.assetId);

    (, , params.healthFactor, , params.totalDebtInBaseCurrency) = spoke.getUserAccountData(alice);

    // duplicated logic from LiquidationLogic.calculateDebtToRestoreCloseFactor
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.wadify())
      .percentMulDown(params.collateralFactor)
      .fromBps();
    if (params.closeFactor < effectiveLiquidationPenalty) {
      return type(uint256).max;
    }
    return
      (((params.totalDebtInBaseCurrency * params.debtAssetUnit) *
        (params.closeFactor - params.healthFactor)) /
        ((params.closeFactor - effectiveLiquidationPenalty + 1) * params.debtAssetPrice))
        .dewadify();
  }

  /// @notice Calc user's lowest possible health factor whereby a liqudation can still restore HF to close factor.
  /// @return healthFactor in WAD
  function _calcLowestHfToRestoreCloseFactor(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 liquidationBonus
  ) internal view returns (uint256) {
    return
      _calcLowestHfForCloseFactorFromCollateralFactor(
        _getCollateralFactor(spoke, collateralReserveId),
        liquidationBonus
      );
  }

  /// given collateral factor and liquidation bonus, calculate the lowest health factor possible
  /// whereby a liquidation can still restore HF to close factor
  function _calcLowestHfForCloseFactorFromCollateralFactor(
    uint256 collateralFactor,
    uint256 liquidationBonus
  ) internal pure returns (uint256 healthFactor) {
    healthFactor = uint256(HEALTH_FACTOR_LIQUIDATION_THRESHOLD)
      .percentMulUp(collateralFactor)
      .percentMulUp(liquidationBonus);
  }

  /// @notice Convert 1 asset amount to equivalent amount in another asset.
  /// @notice Will contain precision loss due to conversion split into two steps.
  /// @return Converted amount of toAsset.
  function _convertAssetAmount(
    uint256 assetId,
    uint256 amount,
    uint256 toAssetId
  ) internal view returns (uint256) {
    return _convertBaseCurrencyToAmount(toAssetId, _convertAmountToBaseCurrency(assetId, amount));
  }

  /// assert that supply ex rate after liquidation is greater than or equal to before
  /// ex rate can increase due to shares rounding on withdraw
  function _assertSupplyExchangeRate(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    assertGe(
      state.rate.rateAfter,
      state.rate.rateBefore,
      string.concat('Supply exchange rate should be gte before ', label)
    );
  }

  // TODO: rm when treasury accounting is complete
  function _tmpGetProtocolFeeFromLiqEvent()
    internal
    returns (uint256 liquidationProtocolFeeAmount)
  {
    Vm.Log[] memory entries = vm.getRecordedLogs();

    // TmpLiquidationFee is next to last event emitted
    liquidationProtocolFeeAmount = uint256(entries[entries.length - 2].topics[1]);
  }

  /// @notice Get accounting info before liquidation, in base currency and amount.
  /// @return LiquidationTestLocalParams struct with updated balances.
  /// debt field is total user debt accounting.
  /// supply field is total user supply accounting.
  /// liquidatorCollateral and liquidatorDebt are the collateral/debt balances of the liquidator.
  /// rate field is the supply exchange rate of the collateral reserve, applied to a RAY.
  function _getAccountingInfoBeforeLiq(
    LiquidationTestLocalParams memory state
  ) internal view returns (LiquidationTestLocalParams memory) {
    state.debt.balanceBefore = spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice);
    state.liquidatorCollateral.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    state.liquidatorDebt.balanceBefore = IERC20(state.debtReserve.asset).balanceOf(LIQUIDATOR);
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(
      state.collateralReserve.reserveId,
      alice
    );
    state.supplyShares.balanceBefore = spoke1.getUserSuppliedShares(
      state.collateralReserve.reserveId,
      alice
    );
    state.rate.rateBefore = hub.convertToSuppliedAssets(
      state.collateralReserve.assetId,
      WadRayMathExtended.RAY
    );

    return state;
  }

  /// @notice Get accounting info after liquidation, in base currency and amount.
  /// @return LiquidationTestLocalParams struct with updated balances.
  /// debt field is total user debt accounting.
  /// treasury balance change is read from emitted event, in shares.
  /// supply field is total user supply accounting.
  /// liquidatorCollateral and liquidatorDebt are the collateral/debt balances of the liquidator.
  /// rate field is the supply exchange rate of the collateral reserve, applied to a RAY.
  function _getAccountingInfoAfterLiq(
    LiquidationTestLocalParams memory state
  ) internal returns (LiquidationTestLocalParams memory) {
    // TODO: update when treasury accounting is done
    // read protocol fee from emitted event arg
    state.treasury.balanceChange = _tmpGetProtocolFeeFromLiqEvent();
    state.liquidatorCollateral.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    state.liquidatorDebt.balanceAfter = IERC20(state.debtReserve.asset).balanceOf(LIQUIDATOR);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice);
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(
      state.collateralReserve.reserveId,
      alice
    );
    state.supplyShares.balanceAfter = spoke1.getUserSuppliedShares(
      state.collateralReserve.reserveId,
      alice
    );
    state.rate.rateAfter = hub.convertToSuppliedAssets(
      state.collateralReserve.assetId,
      WadRayMathExtended.RAY
    );

    // balance changes before/after liquidation
    state.liquidatorCollateral.balanceChange = stdMath.delta(
      state.liquidatorCollateral.balanceAfter,
      state.liquidatorCollateral.balanceBefore
    );
    state.liquidatorDebt.balanceChange = stdMath.delta(
      state.liquidatorDebt.balanceAfter,
      state.liquidatorDebt.balanceBefore
    );
    state.debt.balanceChange = stdMath.delta(state.debt.balanceAfter, state.debt.balanceBefore);
    state.supply.balanceChange = stdMath.delta(
      state.supply.balanceAfter,
      state.supply.balanceBefore
    );
    state.supplyShares.balanceChange = stdMath.delta(
      state.supplyShares.balanceAfter,
      state.supplyShares.balanceBefore
    );

    // convert amount to base currency
    state.liquidatorCollateral.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.liquidatorCollateral.balanceChange
    );
    state.liquidatorDebt.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.liquidatorDebt.balanceChange
    );
    state.debt.baseChange = _convertAmountToBaseCurrency(
      state.debtReserve.assetId,
      state.debt.balanceChange
    );
    state.supply.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.supply.balanceChange
    );

    return state;
  }

  function _increaseCollateralReserveSupplyExchangeRate(
    uint256 assetId,
    uint256 collateralReserveId,
    uint256 borrowAmount,
    uint256 skipTime,
    address user
  ) internal {
    // set price to 0 to circumvent borrow validation
    uint256 initialPrice = oracle.getAssetPrice(assetId);
    oracle.setAssetPrice(assetId, 0);
    // user borrows some collateral reserve to inflate collateral supply ex rate
    Utils.borrow({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: user,
      amount: borrowAmount,
      onBehalfOf: user
    });
    oracle.setAssetPrice(assetId, initialPrice);
    skip(skipTime);
  }
}
