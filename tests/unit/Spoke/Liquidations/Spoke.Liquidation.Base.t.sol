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
    ILiquidityHub collateralHub;
    ILiquidityHub debtHub;
    ISpoke spoke;
    Balance liquidatorDebt;
    Balance liquidatorCollateral;
    Balance treasury;
    Balance userTotalDebt;
    Balance userBaseDebt;
    Balance userPremiumDebt;
    Balance spokeTotalDebt;
    Balance spokeBaseDebt;
    Balance spokePremiumDebt;
    Balance userSuppliedAmount;
    Balance userSuppliedShares;
    Balance spokeSuppliedAmount;
    Balance spokeSuppliedShares;
    Balance deficit;
    Balance totalCollateralInBaseCurrency;
    Balance totalDebtInBaseCurrency;
    Balance[] deficits;
    Balance[] debts;
    DataTypes.DynamicReserveConfig collDynConfig;
    DataTypes.DynamicReserveConfig[] collDynConfigs;
    DataTypes.Reserve[] collateralReserves;
    DataTypes.Reserve[] debtReserves;
    address user;
    uint256 liquidationBonus;
    uint256 liquidationProtocolFee;
    uint256 desiredHf;
    SupplyExchangeRate rate;
    uint256 collToLiq;
    uint256 debtToLiq;
    uint256 liqProtocolFee;
    bool hasDeficit;
    uint256 outstandingDebt;
    uint256 userRp;
    uint256 finalHf;
    uint256 initialHf;
    bool usingAsCollateral;
    uint256 debtReserveIndex;
    uint256 collateralReserveIndex;
    uint256 hfBadDebtThreshold;
    uint256 debtReserveId;
    uint256 collateralReserveId;
    uint256 closeFactor;
  }

  uint256 internal constant MIN_AMOUNT_IN_BASE_CURRENCY = 1e26;

  function setUp() public virtual override {
    super.setUp();
    _deployBorrowableLiquidities(MAX_SUPPLY_AMOUNT);
  }

  /// @notice Deploys max borrowable liquidity for all reserves in spoke1.
  function _deployBorrowableLiquidities(uint256 amount) public {
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _wethReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _wbtcReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _usdyReserveId(spoke1), amount);
  }

  /// @notice Bound liquidation config to full range of possible values
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

  /// @notice Bound liqConfig close factor.
  /// Set non-variable liquidation bonus to simplify calcs for desiredHf.
  function _boundCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorForMaxBonus = 0;

    return liqConfig;
  }

  /// @notice Execute generic liquidation call fuzz test with a desired initial user health factor.
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
    state.collateralReserves = new DataTypes.Reserve[](1);
    state.debtReserves = new DataTypes.Reserve[](1);
    state.spoke = spoke1;

    state.collateralReserves[state.collateralReserveIndex] = state.spoke.getReserve(
      collateralReserveId
    );
    state.debtReserves[state.debtReserveIndex] = state.spoke.getReserve(debtReserveId);

    state.collDynConfig = state.spoke.getDynamicReserveConfig(collateralReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.01e18);
    liquidationProtocolFee = bound(liquidationProtocolFee, 0, 100_00);
    // bound supply amount to max supply amount
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(
        state.spoke,
        state.collateralReserves[state.collateralReserveIndex].reserveId,
        MIN_AMOUNT_IN_BASE_CURRENCY
      ),
      _min(
        _convertBaseCurrencyToAmount(
          state.spoke,
          state.collateralReserves[state.collateralReserveIndex].reserveId,
          MAX_SUPPLY_IN_BASE_CURRENCY
        ),
        MAX_SUPPLY_AMOUNT / 10 // buffer for growth due to interest accrual
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.user = alice;
    state.liquidationProtocolFee = liquidationProtocolFee;

    updateLiquidationConfig(state.spoke, liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationProtocolFee(state.spoke, collateralReserveId, state.liquidationProtocolFee);

    Utils.supplyCollateral({
      spoke: state.spoke,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    _increaseReserveSupplyExchangeRate(
      state.spoke,
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
      state.spoke,
      alice,
      debtReserveId,
      desiredHf
    );
    state.liquidationBonus = _getVariableLiquidationBonus(
      state.spoke,
      collateralReserveId,
      hfAfterBorrow
    );

    state = _getAccountingInfoBeforeLiquidation(state);

    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee,
      ,

    ) = _calculateAvailableCollateralToLiquidate(state, requiredDebtAmount);

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    vm.expectEmit(address(state.spoke));
    emit ISpoke.LiquidationCall(
      state.collateralReserves[state.collateralReserveIndex].underlying,
      state.debtReserves[state.debtReserveIndex].underlying,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state = _getAccountingInfoAfterLiquidation(state);

    return state;
  }

  /// post-liquidation checks
  function _checkLiquidation(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    _assertUserAccountData(state, label);
    _assertProtocolFeeEarned(state, label);
    _assertLiquidationBonusEarned(state, label);
    _assertSupplyExchangeRate(state, label);
    _assertSetUsingAsCollateral(state, label);
    if (state.hasDeficit) {
      _assertBadDebt(state, label);
    } else {
      _assertNoBadDebt(state, label);
    }
    _assertUserRp(state, label);
    _assertSpokeAccounting(state, label);
  }

  function _assertSpokeAccounting(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    // debt asset
    assertApproxEqAbs(
      state.userTotalDebt.balanceChange,
      state.spokeTotalDebt.balanceChange,
      2,
      string.concat('spoke/user total debt accounting ', label)
    );
    assertApproxEqAbs(
      state.userBaseDebt.balanceChange,
      state.spokeBaseDebt.balanceChange,
      1,
      string.concat('spoke/user base debt accounting ', label)
    );
    assertApproxEqAbs(
      state.userPremiumDebt.balanceChange,
      state.spokePremiumDebt.balanceChange,
      1,
      string.concat('spoke/user premium debt accounting ', label)
    );
    // collateral asset
    assertEq(
      state.userSuppliedShares.balanceChange,
      state.spokeSuppliedShares.balanceChange,
      string.concat('spoke/user supplied collateral accounting ', label)
    );
  }

  function _assertUserRp(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    if (state.userSuppliedAmount.balanceAfter > 0 && state.userTotalDebt.balanceAfter > 0) {
      assertEq(
        state.userRp,
        _calculateExpectedUserRP(state.user, state.spoke),
        string.concat('userRp after liq ', label)
      );
    }
  }

  /// assert that the user account data is correct after liquidation
  function _assertUserAccountData(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view virtual {
    if (state.hasDeficit) {
      // if bad debt, HF should be max value and userRp should be 0
      assertEq(state.finalHf, UINT256_MAX, string.concat('HF = 0 if bad debt ', label));
      assertEq(state.userRp, 0, string.concat('userRp = 0 if bad debt ', label));
    } else {
      // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
      if (
        _convertAmountToBaseCurrency(
          state.spoke,
          state.debtReserves[state.debtReserveIndex].reserveId,
          state.userTotalDebt.balanceAfter
        ) >
        MIN_AMOUNT_IN_BASE_CURRENCY &&
        _convertAmountToBaseCurrency(
          state.spoke,
          state.collateralReserves[state.collateralReserveIndex].reserveId,
          state.userSuppliedAmount.balanceAfter
        ) >
        MIN_AMOUNT_IN_BASE_CURRENCY
      ) {
        // ensure HF is lte close factor
        assertLe(
          state.finalHf,
          state.closeFactor,
          string.concat('Health factor <= close factor ', label)
        );
        // should also be close to the desired CF
        assertApproxEqRel(
          state.finalHf,
          state.closeFactor,
          _approxRelFromBps(20),
          'HF matches closeFactor within 0.1%'
        );
      } else {
        // HF should always be lte close factor
        assertLe(
          state.finalHf,
          state.closeFactor,
          string.concat('Health factor <= close factor ', label)
        );
      }
    }
  }

  // todo: utilize treasury accounting to assert protocol fee
  function _assertProtocolFeeEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    uint256 totalLiqBonusAmount = state.userSuppliedAmount.balanceChange -
      state.userSuppliedAmount.balanceChange.percentDivUp(state.liquidationBonus);
    uint256 liqProtocolFeeAmount = hub.convertToSuppliedAssets(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      state.treasury.balanceChange // actual protocol fee shares, from tmp emitted event
    );
    // TODO: resolve precision loss difference
    assertApproxEqAbs(
      liqProtocolFeeAmount,
      totalLiqBonusAmount.percentMulUp(state.liquidationProtocolFee),
      4,
      string.concat('protocol fee amount ', label)
    );
  }

  function _assertLiquidationBonusEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    uint256 totalLiqBonusAmount = state.userSuppliedAmount.balanceChange -
      state.userSuppliedAmount.balanceChange.percentDivDown(state.liquidationBonus);
    uint256 totalCollateralSeized = (state.collToLiq + state.liqProtocolFee);
    uint256 expectedLiqBonusAmount = totalCollateralSeized -
      totalCollateralSeized.percentDivDown(state.liquidationBonus);

    assertApproxEqRel(
      totalLiqBonusAmount,
      expectedLiqBonusAmount,
      _approxRelFromBps(20),
      string.concat('liquidationBonus earned in base currency, rel 20 bps ', label)
    );
  }

  /// check that if user's supplied amount becomes 0, reserve is no longer set usingAsCollateral
  function _assertSetUsingAsCollateral(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    // usingAsCollateral should never be disabled during liquidation
    assertTrue(
      state.usingAsCollateral,
      string.concat('isUsingAsCollateral should be true with remaining collateral ', label)
    );
  }

  /// generic assertions in bad debt scenarios
  function _assertBadDebt(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    // all collateral seized; all debt liquidated and moved to deficit
    assertEq(
      state.userSuppliedShares.balanceAfter,
      0,
      string.concat('supply shares should be 0 ', label)
    );
    assertEq(state.userTotalDebt.balanceAfter, 0, string.concat('debt amount should be 0 ', label));
    assertTrue(state.hasDeficit, string.concat('supply shares & total debt should be 0 ', label));
    (uint256 userRp, , uint256 healthFactor, , ) = state.spoke.getUserAccountData(alice);
    // with no coll/debt remaining, health factor should default to uint256 max
    assertEq(
      healthFactor,
      UINT256_MAX,
      string.concat('health factor should be max after liquidation ', label)
    );
    // with no collateral, user rp is 0
    assertEq(userRp, 0, string.concat('user rp = 0 with no coll ', label));
    uint256 assetAmountOfOneShare = hub.convertToDrawnAssets(
      state.debtReserves[state.debtReserveIndex].assetId,
      WadRayMath.RAY
    ) /
      WadRayMath.RAY +
      1; // add 1 to divUp
    // bad debt should be cleared from user position and moved to deficit
    // precision error is asset equivalent of 1 share
    assertApproxEqAbs(
      state.deficit.balanceChange,
      state.outstandingDebt,
      assetAmountOfOneShare,
      string.concat('deficit added to hub ', label)
    );
  }

  /// generic assertions in non bad debt scenarios
  function _assertNoBadDebt(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    // total debt/collateral in user's position should be > 0
    assertGt(
      state.totalCollateralInBaseCurrency.balanceAfter,
      0,
      string.concat('totalCollateralInBaseCurrency should be > 0 ', label)
    );
    assertGt(
      state.totalDebtInBaseCurrency.balanceAfter,
      0,
      string.concat('totalDebtInBaseCurrency should be > 0 ', label)
    );
    // with collateral/debt remaining, user rp should only be 0 if all coll reserves have liquidity premium == 0
    if (_shouldUserRpBeZero(state.spoke, state.user)) {
      assertEq(state.userRp, 0, string.concat('user rp should be 0 ', label));
    } else {
      assertNotEq(state.userRp, 0, string.concat('user rp should not equal 0 ', label));
    }

    // deficit should remain unchanged
    assertEq(state.deficit.balanceChange, 0, string.concat('deficit should be unchanged ', label));
  }

  /// @dev User's RP should be 0 if all coll reserves have liquidity premium == 0.
  /// @return bool True if user's RP is expected to be 0, False otherwise.
  function _shouldUserRpBeZero(ISpoke spoke, address user) internal view returns (bool) {
    for (uint256 i = 0; i < spoke.reserveCount(); i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(i);
      if (
        reserve.config.liquidityPremium > 0 &&
        spoke.getUserSuppliedShares(reserve.reserveId, user) > 0 &&
        spoke.getUsingAsCollateral(reserve.reserveId, user)
      ) {
        return false;
      }
    }
    return true;
  }

  /**
   * @dev Calculate output from LiquidationLogic.calculateAvailableCollateralToLiquidate.
   * @param state LiquidationTestLocalParams struct containing local params.
   * @param debtToCover Desired amount of debt to cover.
   * @return actualCollateralToLiquidate Amount of actual collateral to liquidate.
   * @return actualDebtToLiquidate Amount of actual debt to liquidate.
   * @return liquidationProtocolFeeAmount Amount of protocol fee (in asset).
   * @return debtToLiquidateInBaseCurrency Amount of debt to liquidate in base currency.
   * @return collateralToLiquidateInBaseCurrency Amount of collateral to liquidate in base currency.
   */
  function _calculateAvailableCollateralToLiquidate(
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  )
    internal
    view
    returns (
      uint256 actualCollateralToLiquidate,
      uint256 actualDebtToLiquidate,
      uint256 liquidationProtocolFeeAmount,
      uint256 debtToLiquidateInBaseCurrency,
      uint256 collateralToLiquidateInBaseCurrency
    )
  {
    IPriceOracle oracle = state.spoke.oracle();
    DataTypes.LiquidationCallLocalVars memory params;

    params.userCollateralBalance = state.spoke.getUserSuppliedAmount(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      alice
    );
    params.collateralAssetUnit =
      10 ** state.collateralReserves[state.collateralReserveIndex].decimals;
    params.collateralReserveId = state.collateralReserves[state.collateralReserveIndex].reserveId;
    params.collateralAssetPrice = oracle.getReservePrice(
      state.collateralReserves[state.collateralReserveIndex].reserveId
    );
    params.debtAssetUnit = 10 ** state.debtReserves[state.debtReserveIndex].decimals;
    params.debtReserveId = state.debtReserves[state.debtReserveIndex].reserveId;
    params.debtAssetPrice = oracle.getReservePrice(
      state.debtReserves[state.debtReserveIndex].reserveId
    );
    params.liquidationBonus = state.liquidationBonus;
    params.liquidationProtocolFee = state.liquidationProtocolFee;

    params.actualDebtToLiquidate = _calculateActualDebtToLiquidate(state, debtToCover);
    return LiquidationLogic.calculateAvailableCollateralToLiquidate(params);
  }

  /// helper to calculate actual collateral to liquidate, replicating LiquidationLogic.calculateActualDebtToLiquidate.
  /// @return actualDebtToLiquidate Amount of actual debt to liquidate.
  function _calculateActualDebtToLiquidate(
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  ) internal view returns (uint256 actualDebtToLiquidate) {
    // find minimum between user's totalDebt of debt asset, debtToCover, and debtToRestoreCloseFactor
    uint256 userTotalDebt = state.userTotalDebt.balanceBefore;
    uint256 debtToRestoreCloseFactor = _calcDebtToRestoreCloseFactor(state.spoke, state);
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

    params.debtAssetUnit = 10 ** state.debtReserves[state.debtReserveIndex].decimals;
    params.debtAssetPrice = oracle.getReservePrice(
      state.debtReserves[state.debtReserveIndex].reserveId
    );

    (, , params.healthFactor, , params.totalDebtInBaseCurrency) = spoke.getUserAccountData(alice);
    // duplicated logic from LiquidationLogic.calculateDebtToRestoreCloseFactor
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.wadify())
      .percentMulDown(params.collateralFactor)
      .fromBps();
    if (params.closeFactor < effectiveLiquidationPenalty) {
      return UINT256_MAX;
    }
    return
      (((params.totalDebtInBaseCurrency * params.debtAssetUnit) *
        (params.closeFactor - params.healthFactor)) /
        ((params.closeFactor - effectiveLiquidationPenalty + 1) * params.debtAssetPrice))
        .dewadifyDown();
  }

  /// @notice Calc user's lowest possible health factor whereby a liqudation can still restore HF to close factor.
  /// for multiple collateral assets
  /// @return healthFactor in WAD
  function _calcLowestHfForBadDebt(
    ISpoke spoke,
    address user,
    uint256 liquidationBonus
  ) internal view returns (uint256) {
    (, uint256 avgCollateralFactor, , , ) = spoke.getUserAccountData(user);
    return _calcLowestHfForBadDebt(avgCollateralFactor.dewadifyDown(), liquidationBonus);
  }

  /// given collateral factor and liquidation bonus, calculate the lowest health factor possible
  /// whereby a liquidation can still restore HF to close factor
  function _calcLowestHfForBadDebt(
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
  function _getAccountingInfoBeforeLiquidation(
    LiquidationTestLocalParams memory state
  ) internal view returns (LiquidationTestLocalParams memory) {
    state.debtReserveId = state.debtReserves[state.debtReserveIndex].reserveId;
    state.collateralReserveId = state.collateralReserves[state.collateralReserveIndex].reserveId;
    state.closeFactor = _getCloseFactor(state.spoke);

    state.collateralHub = state.collateralReserves[state.collateralReserveIndex].hub;
    state.debtHub = state.debtReserves[state.debtReserveIndex].hub;

    (state.userBaseDebt.balanceBefore, state.userPremiumDebt.balanceBefore) = state
      .spoke
      .getUserDebt(state.debtReserves[state.debtReserveIndex].reserveId, state.user);
    state.userTotalDebt.balanceBefore =
      state.userBaseDebt.balanceBefore +
      state.userPremiumDebt.balanceBefore;
    state.liquidatorCollateral.balanceBefore = IERC20(
      state.collateralReserves[state.collateralReserveIndex].underlying
    ).balanceOf(LIQUIDATOR);
    state.liquidatorDebt.balanceBefore = IERC20(
      state.debtReserves[state.debtReserveIndex].underlying
    ).balanceOf(LIQUIDATOR);
    state.userSuppliedAmount.balanceBefore = state.spoke.getUserSuppliedAmount(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );
    state.userSuppliedShares.balanceBefore = state.spoke.getUserSuppliedShares(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );
    state.spokeSuppliedAmount.balanceBefore = state.collateralHub.getSpokeSuppliedAmount(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      address(state.spoke)
    );
    state.spokeSuppliedShares.balanceBefore = state.collateralHub.getSpokeSuppliedShares(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      address(state.spoke)
    );
    state.rate.rateBefore = hub.convertToSuppliedAssets(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      WadRayMathExtended.RAY
    );
    state.deficit.balanceBefore = getDeficit(
      state.debtHub,
      state.debtReserves[state.debtReserveIndex].assetId
    );

    (state.spokeBaseDebt.balanceBefore, state.spokePremiumDebt.balanceBefore) = hub.getSpokeDebt(
      state.debtReserves[state.debtReserveIndex].assetId,
      address(state.spoke)
    );
    state.spokeTotalDebt.balanceBefore =
      state.spokeBaseDebt.balanceBefore +
      state.spokePremiumDebt.balanceBefore;

    (
      ,
      ,
      state.initialHf,
      state.totalCollateralInBaseCurrency.balanceBefore,
      state.totalDebtInBaseCurrency.balanceBefore
    ) = state.spoke.getUserAccountData(state.user);

    // multi reserve accounting
    state.debts = new Balance[](state.debtReserves.length);
    state.deficits = new Balance[](state.debtReserves.length);
    for (uint256 i = 0; i < state.debtReserves.length; i++) {
      state.deficits[i].balanceBefore = getDeficit(
        state.debtReserves[i].hub,
        state.debtReserves[i].assetId
      );
      state.debts[i].balanceBefore = state.spoke.getUserTotalDebt(
        state.debtReserves[i].reserveId,
        state.user
      );
    }

    return state;
  }

  /// @notice Get accounting info after liquidation, in base currency and amount.
  /// @return LiquidationTestLocalParams struct with updated balances.
  /// debt field is total user debt accounting.
  /// treasury balance change is read from emitted event, in shares.
  /// supply field is total user supply accounting.
  /// liquidatorCollateral and liquidatorDebt are the collateral/debt balances of the liquidator.
  /// rate field is the supply exchange rate of the collateral reserve, applied to a RAY.
  function _getAccountingInfoAfterLiquidation(
    LiquidationTestLocalParams memory state
  ) internal returns (LiquidationTestLocalParams memory) {
    // TODO: update when treasury accounting is done
    // read protocol fee from emitted event arg
    state.treasury.balanceChange = _tmpGetProtocolFeeFromLiqEvent();
    state.liquidatorCollateral.balanceAfter = IERC20(
      state.collateralReserves[state.collateralReserveIndex].underlying
    ).balanceOf(LIQUIDATOR);
    state.liquidatorDebt.balanceAfter = IERC20(
      state.debtReserves[state.debtReserveIndex].underlying
    ).balanceOf(LIQUIDATOR);
    (state.userBaseDebt.balanceAfter, state.userPremiumDebt.balanceAfter) = state.spoke.getUserDebt(
      state.debtReserves[state.debtReserveIndex].reserveId,
      state.user
    );
    state.userTotalDebt.balanceAfter =
      state.userBaseDebt.balanceAfter +
      state.userPremiumDebt.balanceAfter;
    state.userSuppliedAmount.balanceAfter = state.spoke.getUserSuppliedAmount(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );
    state.userSuppliedShares.balanceAfter = state.spoke.getUserSuppliedShares(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );
    state.spokeSuppliedAmount.balanceAfter = state.collateralHub.getSpokeSuppliedAmount(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      address(state.spoke)
    );
    state.spokeSuppliedShares.balanceAfter = state.collateralHub.getSpokeSuppliedShares(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      address(state.spoke)
    );
    state.rate.rateAfter = hub.convertToSuppliedAssets(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      WadRayMathExtended.RAY
    );
    state.deficit.balanceAfter = getDeficit(
      state.debtReserves[state.debtReserveIndex].hub,
      state.debtReserves[state.debtReserveIndex].assetId
    );
    (state.spokeBaseDebt.balanceAfter, state.spokePremiumDebt.balanceAfter) = hub.getSpokeDebt(
      state.debtReserves[state.debtReserveIndex].assetId,
      address(state.spoke)
    );
    state.spokeTotalDebt.balanceAfter =
      state.spokeBaseDebt.balanceAfter +
      state.spokePremiumDebt.balanceAfter;

    // balance changes before/after liquidation
    state.liquidatorCollateral.balanceChange = stdMath.delta(
      state.liquidatorCollateral.balanceAfter,
      state.liquidatorCollateral.balanceBefore
    );
    state.liquidatorDebt.balanceChange = stdMath.delta(
      state.liquidatorDebt.balanceAfter,
      state.liquidatorDebt.balanceBefore
    );
    state.userTotalDebt.balanceChange = stdMath.delta(
      state.userTotalDebt.balanceAfter,
      state.userTotalDebt.balanceBefore
    );
    state.userBaseDebt.balanceChange = stdMath.delta(
      state.userBaseDebt.balanceAfter,
      state.userBaseDebt.balanceBefore
    );
    state.userPremiumDebt.balanceChange = stdMath.delta(
      state.userPremiumDebt.balanceAfter,
      state.userPremiumDebt.balanceBefore
    );
    state.spokeTotalDebt.balanceChange = stdMath.delta(
      state.spokeTotalDebt.balanceAfter,
      state.spokeTotalDebt.balanceBefore
    );
    state.spokeBaseDebt.balanceChange = stdMath.delta(
      state.spokeBaseDebt.balanceAfter,
      state.spokeBaseDebt.balanceBefore
    );
    state.spokePremiumDebt.balanceChange = stdMath.delta(
      state.spokePremiumDebt.balanceAfter,
      state.spokePremiumDebt.balanceBefore
    );
    state.userSuppliedAmount.balanceChange = stdMath.delta(
      state.userSuppliedAmount.balanceAfter,
      state.userSuppliedAmount.balanceBefore
    );
    state.userSuppliedShares.balanceChange = stdMath.delta(
      state.userSuppliedShares.balanceAfter,
      state.userSuppliedShares.balanceBefore
    );
    state.spokeSuppliedAmount.balanceChange = stdMath.delta(
      state.spokeSuppliedAmount.balanceAfter,
      state.spokeSuppliedAmount.balanceBefore
    );
    state.spokeSuppliedShares.balanceChange = stdMath.delta(
      state.spokeSuppliedShares.balanceAfter,
      state.spokeSuppliedShares.balanceBefore
    );
    state.deficit.balanceChange = stdMath.delta(
      state.deficit.balanceAfter,
      state.deficit.balanceBefore
    );

    // convert amount to base currency
    state.liquidatorCollateral.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.liquidatorCollateral.balanceChange
    );
    state.liquidatorDebt.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.liquidatorDebt.balanceChange
    );
    state.userTotalDebt.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.debtReserves[state.debtReserveIndex].reserveId,
      state.userTotalDebt.balanceChange
    );
    state.userSuppliedAmount.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.userSuppliedAmount.balanceChange
    );

    state.outstandingDebt = state.userTotalDebt.balanceBefore - state.debtToLiq;
    (
      state.userRp,
      ,
      state.finalHf,
      state.totalCollateralInBaseCurrency.balanceAfter,
      state.totalDebtInBaseCurrency.balanceAfter
    ) = state.spoke.getUserAccountData(state.user);

    state.hasDeficit =
      state.userSuppliedAmount.balanceAfter == 0 &&
      state.userTotalDebt.balanceAfter == 0;

    state.usingAsCollateral = state.spoke.getUsingAsCollateral(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );

    // multi reserve accounting
    for (uint256 i = 0; i < state.debtReserves.length; i++) {
      state.deficits[i].balanceAfter = getDeficit(
        state.debtReserves[i].hub,
        state.debtReserves[i].assetId
      );

      state.deficits[i].balanceChange =
        state.deficits[i].balanceAfter -
        state.deficits[i].balanceBefore;

      state.debts[i].balanceAfter = state.spoke.getUserTotalDebt(
        state.debtReserves[i].reserveId,
        state.user
      );
      state.debts[i].balanceChange = stdMath.delta(
        state.debts[i].balanceAfter,
        state.debts[i].balanceBefore
      );
    }

    return state;
  }

  // increase supply exchange rate on a given reserve
  function _increaseReserveSupplyExchangeRate(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 borrowAmount,
    uint256 skipTime,
    address user
  ) internal {
    // set price to 0 to circumvent borrow validation
    uint256 assetId = spoke.getReserve(collateralReserveId).assetId;
    uint256 initialExRate = hub.convertToSuppliedAssets(assetId, WadRayMathExtended.RAY.wadify()); // wadify to increase precision of ex rate increase
    uint256 initialPrice = oracle1.getReservePrice(collateralReserveId);
    oracle1.setReservePrice(collateralReserveId, 0);
    // user borrows some collateral reserve to inflate collateral supply ex rate
    Utils.borrow({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: user,
      amount: borrowAmount,
      onBehalfOf: user
    });
    oracle1.setReservePrice(collateralReserveId, initialPrice);
    skip(skipTime);
    uint256 finalExRate = hub.convertToSuppliedAssets(assetId, WadRayMathExtended.RAY.wadify()); // wadify to increase precision of ex rate increase
    assertGt(finalExRate, initialExRate);
  }
}
