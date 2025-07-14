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
    uint256 liquidationFee;
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
    uint256 liquidationFeeAmount;
    uint256 liquidationFeeShares;
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
    uint256 liquidationFee,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);
    state.collDynConfig = _getUserDynConfig(spoke1, alice, collateralReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMathExtended.PERCENTAGE_FACTOR.percentDivDown(state.collDynConfig.collateralFactor)
    );
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.01e18);
    liquidationFee = bound(liquidationFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
    // bound supply amount to max supply amount
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(spoke1, collateralReserveId, MIN_AMOUNT_IN_BASE_CURRENCY),
      _min(
        _convertBaseCurrencyToAmount(spoke1, collateralReserveId, MAX_SUPPLY_IN_BASE_CURRENCY),
        MAX_SUPPLY_AMOUNT
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.liquidationFee = liquidationFee;

    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationFee(spoke1, collateralReserveId, state.liquidationFee);

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

    _borrowWithoutHfCheck({
      spoke: spoke1,
      user: bob,
      reserveId: collateralReserveId,
      debtAmount: supplyAmount / 2
    });
    skip(skipTime);

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
    state.liquidationBonus = spoke1.getVariableLiquidationBonus(
      collateralReserveId,
      alice,
      hfAfterBorrow
    );

    state = _getAccountingInfoBeforeLiq(state);

    // Get alice's dynamic config key before liquidation
    DynamicConfig[] memory configKeysBefore = _getUserDynConfigKeys(spoke1, alice);

    (
      state.collToLiq,
      state.debtToLiq,
      state.liquidationFeeAmount
    ) = _calculateAvailableCollateralToLiquidate(spoke1, state, requiredDebtAmount);

    state.liquidationFeeShares =
      hub.convertToSuppliedSharesUp(
        state.collateralReserve.assetId,
        state.collToLiq + state.liquidationFeeAmount
      ) -
      hub.convertToSuppliedSharesUp(state.collateralReserve.assetId, state.collToLiq);

    if (collateralReserveId != debtReserveId) {
      vm.expectCall(
        address(hub),
        abi.encodeWithSelector(
          hub.payFee.selector,
          state.collateralReserve.assetId,
          state.liquidationFeeShares
        ),
        state.liquidationFeeShares > 0 ? 1 : 0
      );
    } else {
      // precision loss can occur when coll and debt reserve are the same
      // during a restore action that includes donation
      vm.expectCall(
        address(hub),
        abi.encodeWithSelector(hub.payFee.selector),
        state.liquidationFeeShares > 0 ? 1 : 0
      );
    }

    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationCall(
      state.collateralReserve.underlying,
      state.debtReserve.underlying,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state = _getAccountingInfoAfterLiq(state);

    // Validate alice's dynamic config key unchanged after liquidation
    assertEq(_getUserDynConfigKeys(spoke1, alice), configKeysBefore);

    // with a close factor, it is impossible to liquidate all debt unless deficit is reported
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
    _assertLiquidationFeeEarned(state, label);
    _assertLiquidationBonusEarned(state, label);
    _assertSupplyExchangeRate(state, label);
    _assertSetUsingAsCollateral(spoke, alice, state, label);
    _assertRemainingSpokeCollateral(state, spoke, label);
  }

  function _assertRemainingSpokeCollateral(
    LiquidationTestLocalParams memory state,
    ISpoke spoke,
    string memory label
  ) internal view {
    assertEq(
      IERC20(state.collateralReserve.underlying).balanceOf(address(spoke)),
      0,
      string.concat('no spoke collateral underlying should remain ', label)
    );
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
      _convertAmountToBaseCurrency(spoke, state.debtReserve.reserveId, state.debt.balanceAfter) >
      MIN_AMOUNT_IN_BASE_CURRENCY &&
      _convertAmountToBaseCurrency(
        spoke,
        state.collateralReserve.reserveId,
        state.supply.balanceAfter
      ) >
      MIN_AMOUNT_IN_BASE_CURRENCY
    ) {
      // ensure HF is lte close factor
      assertLe(
        finalHf,
        _getCloseFactor(spoke),
        string.concat('Health factor <= close factor ', label)
      );
      uint256 bpsError = 20;
      // should also be close to the desired CF
      assertApproxEqRel(
        finalHf,
        _getCloseFactor(spoke),
        _approxRelFromBps(bpsError),
        string.concat('HF matches closeFactor within ', vm.toString(bpsError), ' bps')
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

  function _assertLiquidationFeeEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    uint256 totalLiqBonusAmount = state.supply.balanceChange -
      state.supply.balanceChange.percentDivUp(state.liquidationBonus);
    uint256 liquidationFeeAmount = state.treasury.balanceChange;
    // TODO: resolve precision loss difference
    assertApproxEqAbs(
      liquidationFeeAmount,
      totalLiqBonusAmount.percentMulUp(state.liquidationFee),
      2,
      string.concat('protocol fee amount ', label)
    );
  }

  function _assertLiquidationBonusEarned(
    LiquidationTestLocalParams memory state,
    // ConvertedValues memory totalLiqBonus,
    string memory label
  ) internal view {
    uint256 totalLiqBonusAmount = state.supply.balanceChange -
      state.supply.balanceChange.percentDivDown(state.liquidationBonus);

    uint256 totalCollateralSeized = (state.collToLiq + state.liquidationFeeAmount);
    // liquidationBonus == PERCENTAGE_FACTOR represents liq bonus being 0
    uint256 expectedLiqBonusAmount = state.liquidationBonus != PercentageMath.PERCENTAGE_FACTOR
      ? totalCollateralSeized - totalCollateralSeized.percentDivDown(state.liquidationBonus)
      : 0;

    if (
      _convertAmountToBaseCurrency(spoke1, state.collateralReserveId, totalLiqBonusAmount) >
      MIN_AMOUNT_IN_BASE_CURRENCY
    ) {
      assertApproxEqRel(
        totalLiqBonusAmount,
        expectedLiqBonusAmount,
        _approxRelFromBps(1),
        string.concat('liquidationBonus earned in base currency, rel 20 bps ', label)
      );
    } else {
      assertApproxEqAbs(
        totalLiqBonusAmount,
        expectedLiqBonusAmount,
        1,
        string.concat('liquidationBonus earned in base currency, eq abs 1 ', label)
      );
    }
  }

  function _assertSetUsingAsCollateral(
    ISpoke spoke,
    address user,
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    // uingAsCollateral should remain True after liquidation
    assertTrue(
      spoke.getUsingAsCollateral(state.collateralReserve.reserveId, user),
      string.concat('isUsingAsCollateral should remain true ', label)
    );
  }

  /// @notice Calculate output from LiquidationLogic.calculateAvailableCollateralToLiquidate.
  /// @param spoke Spoke contract.
  /// @param state LiquidationTestLocalParams struct containing local params.
  /// @param debtToCover Desired amount of debt to cover.
  /// @return actualCollateralToLiquidate Amount of actual collateral to liquidate.
  /// @return actualDebtToLiquidate Amount of actual debt to liquidate.
  /// @return liquidationFeeAmount Amount of protocol fee (in asset).
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
      uint256 liquidationFeeAmount
    )
  {
    IPriceOracle oracle = spoke.oracle();
    DataTypes.LiquidationCallLocalVars memory params;

    params.userCollateralBalance = spoke.getUserSuppliedAmount(
      state.collateralReserve.reserveId,
      alice
    );
    params.collateralAssetUnit = 10 ** state.collateralReserve.decimals;
    params.collateralReserveId = state.collateralReserve.reserveId;
    params.collateralAssetPrice = oracle.getReservePrice(state.collateralReserve.reserveId);

    params.debtAssetUnit = 10 ** state.debtReserve.decimals;
    params.debtReserveId = state.debtReserve.reserveId;
    params.debtAssetPrice = oracle.getReservePrice(state.debtReserve.reserveId);

    params.liquidationBonus = state.liquidationBonus;
    params.liquidationFee = state.liquidationFee;

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
    IPriceOracle oracle = spoke.oracle();
    DataTypes.LiquidationCallLocalVars memory params;

    params.liquidationBonus = state.liquidationBonus;
    params.collateralFactor = state.collDynConfig.collateralFactor;
    params.closeFactor = _getCloseFactor(spoke);

    params.debtAssetUnit = 10 ** state.debtReserve.decimals;
    params.debtAssetPrice = oracle.getReservePrice(state.debtReserve.reserveId);

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
        .dewadifyDown();
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

  /// @notice Get accounting info before liquidation, in base currency and amount.
  /// @return LiquidationTestLocalParams struct with updated balances.
  /// debt field is total user debt accounting.
  /// supply field is total user supply accounting.
  /// liquidatorCollateral and liquidatorDebt are the collateral/debt balances of the liquidator.
  /// rate field is the supply exchange rate of the collateral reserve, applied to a RAY.
  function _getAccountingInfoBeforeLiq(
    LiquidationTestLocalParams memory state
  ) internal view returns (LiquidationTestLocalParams memory) {
    state.collateralAssetId = state.collateralReserve.assetId;
    state.debtAssetId = state.debtReserve.assetId;

    state.debt.balanceBefore = spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice);
    state.liquidatorCollateral.balanceBefore = IERC20(state.collateralReserve.underlying).balanceOf(
      LIQUIDATOR
    );
    state.liquidatorDebt.balanceBefore = IERC20(state.debtReserve.underlying).balanceOf(LIQUIDATOR);
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
    state.treasury.balanceBefore = hub.getSpokeSuppliedAmount(
      state.collateralReserve.assetId,
      _getFeeReceiver(state.collateralReserve.assetId)
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
    state.treasury.balanceAfter = hub.getSpokeSuppliedAmount(
      state.collateralReserve.assetId,
      _getFeeReceiver(state.collateralReserve.assetId)
    );
    state.liquidatorCollateral.balanceAfter = IERC20(state.collateralReserve.underlying).balanceOf(
      LIQUIDATOR
    );
    state.liquidatorDebt.balanceAfter = IERC20(state.debtReserve.underlying).balanceOf(LIQUIDATOR);
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
    state.treasury.balanceChange = stdMath.delta(
      state.treasury.balanceAfter,
      state.treasury.balanceBefore
    );

    // convert amount to base currency
    state.liquidatorCollateral.baseChange = _convertAmountToBaseCurrency(
      spoke1,
      state.collateralReserve.reserveId,
      state.liquidatorCollateral.balanceChange
    );
    state.liquidatorDebt.baseChange = _convertAmountToBaseCurrency(
      spoke1,
      state.collateralReserve.reserveId,
      state.liquidatorDebt.balanceChange
    );
    state.debt.baseChange = _convertAmountToBaseCurrency(
      spoke1,
      state.debtReserve.reserveId,
      state.debt.balanceChange
    );
    state.supply.baseChange = _convertAmountToBaseCurrency(
      spoke1,
      state.collateralReserve.reserveId,
      state.supply.balanceChange
    );

    return state;
  }
}
