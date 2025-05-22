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
    ISpoke spoke;
    address user;
    Balance liquidatorDebt;
    Balance liquidatorCollateral;
    Balance treasury;
    Balance totalDebt;
    Balance baseDebt;
    Balance premiumDebt;
    Balance supply;
    Balance supplyShares;
    Balance deficit;
    uint256 liquidationBonus;
    uint256 liquidationProtocolFeePercentage;
    DataTypes.Reserve[] collateralReserves;
    DataTypes.Reserve[] debtReserves;
    uint256 desiredHf;
    SupplyExchangeRate rate;
    uint256 collToLiq;
    uint256 debtToLiq;
    uint256 liqProtocolFee;
    bool hasDeficit;
    uint256 outstandingDebt;
    uint256 userRp;
    uint256 finalHf;
    uint256 finalTotalCollateralInBaseCurrency;
    uint256 finalTotalDebtInBaseCurrency;
    uint256 initialHf;
    uint256 initialTotalCollateralInBaseCurrency;
    uint256 initialTotalDebtInBaseCurrency;
    bool usingAsCollateral;
    uint256 debtReserveIndex;
    uint256 collateralReserveIndex;
    Balance[] deficits;
    Balance[] debts;
  }

  uint256 internal constant MIN_AMOUNT_IN_BASE_CURRENCY = 1e26;

  function setUp() public virtual override {
    super.setUp();
    _deployBorrowableLiquidities(MAX_SUPPLY_AMOUNT * 10); // additional liquidity buffer for if collateral reserve == debt reserve
  }

  /// @notice Deploys max borrowable liquidity for all reserves in spoke1.
  function _deployBorrowableLiquidities(uint256 amount) public {
    _deployLiquidity(spoke1, _daiReserveId(spoke1), amount);
    _deployLiquidity(spoke1, _wethReserveId(spoke1), amount);
    _deployLiquidity(spoke1, _wbtcReserveId(spoke1), amount);
    _deployLiquidity(spoke1, _usdxReserveId(spoke1), amount);
    _deployLiquidity(spoke1, _usdyReserveId(spoke1), amount);
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
    liqConfig.healthFactorBonusThreshold = bound(
      liqConfig.healthFactorBonusThreshold,
      0.01e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    return liqConfig;
  }

  /// bound liqConfig close factor
  /// set constant liquidation bonus to simplify calcs for desiredHf
  function _boundCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );

    // set constant liquidation bonus to simplify calcs for desiredHf
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorBonusThreshold = 0;

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
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);
    state.debtReserves = new DataTypes.Reserve[](1);

    state.collateralReserves[state.collateralReserveIndex] = spoke1.getReserve(collateralReserveId);
    state.debtReserves[state.debtReserveIndex] = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.01e18);
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    // bound supply amount to max supply amount
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(
        state.collateralReserves[state.collateralReserveIndex].assetId,
        MIN_AMOUNT_IN_BASE_CURRENCY
      ),
      _min(
        _convertBaseCurrencyToAmount(
          state.collateralReserves[state.collateralReserveIndex].assetId,
          MAX_SUPPLY_IN_BASE_CURRENCY
        ),
        MAX_SUPPLY_AMOUNT
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.spoke = spoke1;
    state.user = alice;
    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    console.log(' fuzz inputs');
    console.log('  liqConfig.closeFactor %e', liqConfig.closeFactor);
    console.log('  liqConfig.healthFactorBonusThreshold %e', liqConfig.healthFactorBonusThreshold);
    console.log('  liqConfig.liquidationBonusFactor %e', liqConfig.liquidationBonusFactor);
    console.log('  liqBonus %e', liqBonus);
    console.log('  desiredHf %e', desiredHf);
    console.log('  supplyAmount %e', supplyAmount);
    console.log('  skipTime %e', skipTime);
    console.log('  liquidationProtocolFeePercentage %e', liquidationProtocolFeePercentage);
    console.log('  collateralReserveId %e', collateralReserveId);
    console.log('  debtReserveId %e', debtReserveId);

    state.spoke.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      state.spoke,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );

    Utils.supplyCollateral({
      spoke: state.spoke,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    _increaseCollateralReserveSupplyExchangeRate(
      state.spoke,
      collateralReserveId,
      supplyAmount / 2,
      skipTime,
      bob
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

    console.log('test: requiredDebtAmount %e', requiredDebtAmount);

    state = _getAccountingInfoBeforeLiq(state);

    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee,

    ) = _calculateAvailableCollateralToLiquidate(state.spoke, state, requiredDebtAmount);

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    vm.expectEmit(address(state.spoke));
    emit ISpoke.LiquidationCall(
      state.collateralReserves[state.collateralReserveIndex].asset,
      state.debtReserves[state.debtReserveIndex].asset,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state = _getAccountingInfoAfterLiq(state);

    return state;
  }

  /// post-liquidation checks
  function _checkLiquidation(
    LiquidationTestLocalParams memory state,
    ISpoke spoke,
    string memory label
  ) internal view {
    _assertUserAccountData(spoke, state, label);
    _assertProtocolFeeEarned(state, label);
    _assertLiquidationBonusEarned(state, label);
    _assertSupplyExchangeRate(state, label);
    _assertSetUsingAsCollateral(spoke, state, label);
    if (state.hasDeficit) {
      _assertBadDebt(spoke, state, label);
    } else {
      _assertNoBadDebt(spoke, state, label);
    }
  }

  /// assert that the user account data is correct after liquidation
  function _assertUserAccountData(
    ISpoke spoke,
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
          state.debtReserves[state.debtReserveIndex].assetId,
          state.totalDebt.balanceAfter
        ) >
        MIN_AMOUNT_IN_BASE_CURRENCY &&
        _convertAmountToBaseCurrency(
          state.collateralReserves[state.collateralReserveIndex].assetId,
          state.supply.balanceAfter
        ) >
        MIN_AMOUNT_IN_BASE_CURRENCY
      ) {
        // ensure HF is lte close factor
        assertLe(
          state.finalHf,
          _getCloseFactor(spoke),
          string.concat('Health factor <= close factor ', label)
        );
        // should also be close to the desired CF
        assertApproxEqRel(
          state.finalHf,
          _getCloseFactor(spoke),
          _approxRelFromBps(20),
          'HF matches closeFactor within 0.1%'
        );
      } else {
        // HF should always be lte close factor
        assertLe(
          state.finalHf,
          _getCloseFactor(spoke),
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
    uint256 totalLiqBonusAmount = state.supply.balanceChange -
      state.supply.balanceChange.percentDivUp(state.liquidationBonus);
    uint256 liqProtocolFeeAmount = hub.convertToSuppliedAssets(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      state.treasury.balanceChange // actual protocol fee shares, from tmp emitted event
    );
    // TODO: resolve precision loss difference
    assertApproxEqAbs(
      liqProtocolFeeAmount,
      totalLiqBonusAmount.percentMulUp(state.liquidationProtocolFeePercentage),
      3,
      string.concat('protocol fee amount ', label)
    );
  }

  function _assertLiquidationBonusEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    uint256 totalLiqBonusAmount = state.supply.balanceChange -
      state.supply.balanceChange.percentDivDown(state.liquidationBonus);

    uint256 totalCollateralSeized = (state.collToLiq + state.liqProtocolFee);
    uint256 expectedLiqBonusAmount = totalCollateralSeized -
      totalCollateralSeized.percentDivDown(state.liquidationBonus);

    console.log(
      'state.liquidationBonus %e state.supply.balanceChange %e',
      state.liquidationBonus,
      state.supply.balanceChange
    );
    console.log('totalLiqBonusAmount %e', totalLiqBonusAmount);
    console.log('expectedLiqBonusAmount %e', expectedLiqBonusAmount);

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
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    if (state.supplyShares.balanceAfter == 0) {
      assertFalse(
        state.usingAsCollateral,
        string.concat('isUsingAsCollateral should be false with no collateral ', label)
      );
    } else {
      assertTrue(
        state.usingAsCollateral,
        string.concat('isUsingAsCollateral should be true with remaining collateral ', label)
      );
    }
  }

  function _assertBadDebt(
    ISpoke spoke,
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    // all collateral seized; all debt liquidated and moved to deficit
    assertEq(
      state.supplyShares.balanceAfter,
      0,
      string.concat('supply shares should be 0 ', label)
    );
    assertEq(state.totalDebt.balanceAfter, 0, string.concat('debt amount should be 0 ', label));
    assertTrue(state.hasDeficit, string.concat('supply shares & total debt should be 0 ', label));
    (uint256 userRp, , uint256 healthFactor, , ) = spoke.getUserAccountData(alice);
    // with no coll/debt remaining, health factor should default to uint256 max
    assertEq(
      healthFactor,
      UINT256_MAX,
      string.concat('health factor should be max after liquidation ', label)
    );
    // with no collateral, user rp is 0
    assertEq(userRp, 0, string.concat('user rp = 0 with no coll ', label));
    // bad debt should be cleared from user position and moved to deficit
    assertEq(
      state.deficit.balanceChange,
      state.outstandingDebt,
      string.concat('deficit added to hub ', label)
    );
  }

  function _assertNoBadDebt(
    ISpoke spoke,
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    // total debt/collateral in user's position should be > 0
    assertGt(
      state.finalTotalCollateralInBaseCurrency,
      0,
      string.concat('totalCollateralInBaseCurrency should be > 0 ', label)
    );
    assertGt(
      state.finalTotalDebtInBaseCurrency,
      0,
      string.concat('totalDebtInBaseCurrency should be > 0 ', label)
    );
    // with collateral/debt remaining, user rp is not 0
    assertNotEq(state.userRp, 0, string.concat('user rp = 0 with no coll ', label));
    // deficit should remain unchanged
    assertEq(state.deficit.balanceChange, 0, string.concat('deficit should be unchanged ', label));
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
      uint256 liquidationProtocolFeeAmount,
      uint256 collateralToLiquidateInBaseCurrency
    )
  {
    DataTypes.LiquidationCallLocalVars memory params;

    params.userCollateralBalance = spoke.getUserSuppliedAmount(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      alice
    );
    params.collateralAssetUnit =
      10 ** state.collateralReserves[state.collateralReserveIndex].config.decimals;
    params.collateralReserveId = state.collateralReserves[state.collateralReserveIndex].reserveId;
    params.collateralAssetPrice = oracle.getAssetPrice(
      state.collateralReserves[state.collateralReserveIndex].assetId
    );

    params.debtAssetUnit = 10 ** state.debtReserves[state.debtReserveIndex].config.decimals;
    params.debtReserveId = state.debtReserves[state.debtReserveIndex].reserveId;
    params.debtAssetPrice = oracle.getAssetPrice(
      state.debtReserves[state.debtReserveIndex].assetId
    );

    params.liquidationBonus = state.liquidationBonus;
    params.liquidationProtocolFeePercentage = state.liquidationProtocolFeePercentage;

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
    uint256 userTotalDebt = state.totalDebt.balanceBefore;
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
    params.collateralFactor = state
      .collateralReserves[state.collateralReserveIndex]
      .config
      .collateralFactor;
    params.closeFactor = _getCloseFactor(spoke);

    params.debtAssetUnit = 10 ** state.debtReserves[state.debtReserveIndex].config.decimals;
    params.debtAssetPrice = oracle.getAssetPrice(
      state.debtReserves[state.debtReserveIndex].assetId
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
        .dewadify();
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
    return
      _calcLowestHfForCloseFactorFromCollateralFactor(
        avgCollateralFactor.dewadify(),
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
    (state.baseDebt.balanceBefore, state.premiumDebt.balanceBefore) = state.spoke.getUserDebt(
      state.debtReserves[state.debtReserveIndex].reserveId,
      state.user
    );
    state.totalDebt.balanceBefore = state.baseDebt.balanceBefore + state.premiumDebt.balanceBefore;
    state.liquidatorCollateral.balanceBefore = IERC20(
      state.collateralReserves[state.collateralReserveIndex].asset
    ).balanceOf(LIQUIDATOR);
    state.liquidatorDebt.balanceBefore = IERC20(state.debtReserves[state.debtReserveIndex].asset)
      .balanceOf(LIQUIDATOR);
    state.supply.balanceBefore = state.spoke.getUserSuppliedAmount(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );
    state.supplyShares.balanceBefore = state.spoke.getUserSuppliedShares(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );
    state.rate.rateBefore = hub.convertToSuppliedAssets(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      WadRayMathExtended.RAY
    );
    state.deficit.balanceBefore = hub.getDeficit(
      state.debtReserves[state.debtReserveIndex].assetId
    );

    (
      ,
      ,
      state.initialHf,
      state.initialTotalCollateralInBaseCurrency,
      state.initialTotalDebtInBaseCurrency
    ) = state.spoke.getUserAccountData(state.user);

    // multi reserve accounting
    state.debts = new Balance[](state.debtReserves.length);
    state.deficits = new Balance[](state.debtReserves.length);
    for (uint256 i = 0; i < state.debtReserves.length; i++) {
      state.deficits[i].balanceBefore = hub.getDeficit(state.debtReserves[i].assetId);
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
  function _getAccountingInfoAfterLiq(
    LiquidationTestLocalParams memory state
  ) internal returns (LiquidationTestLocalParams memory) {
    // TODO: update when treasury accounting is done
    // read protocol fee from emitted event arg
    state.treasury.balanceChange = _tmpGetProtocolFeeFromLiqEvent();
    state.liquidatorCollateral.balanceAfter = IERC20(
      state.collateralReserves[state.collateralReserveIndex].asset
    ).balanceOf(LIQUIDATOR);
    state.liquidatorDebt.balanceAfter = IERC20(state.debtReserves[state.debtReserveIndex].asset)
      .balanceOf(LIQUIDATOR);
    (state.baseDebt.balanceAfter, state.premiumDebt.balanceAfter) = state.spoke.getUserDebt(
      state.debtReserves[state.debtReserveIndex].reserveId,
      state.user
    );
    state.totalDebt.balanceAfter = state.baseDebt.balanceAfter + state.premiumDebt.balanceAfter;
    state.supply.balanceAfter = state.spoke.getUserSuppliedAmount(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );
    state.supplyShares.balanceAfter = state.spoke.getUserSuppliedShares(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );
    state.rate.rateAfter = hub.convertToSuppliedAssets(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      WadRayMathExtended.RAY
    );
    state.deficit.balanceAfter = hub.getDeficit(state.debtReserves[state.debtReserveIndex].assetId);

    // balance changes before/after liquidation
    state.liquidatorCollateral.balanceChange = _absDiff(
      state.liquidatorCollateral.balanceAfter,
      state.liquidatorCollateral.balanceBefore
    );
    state.liquidatorDebt.balanceChange = _absDiff(
      state.liquidatorDebt.balanceAfter,
      state.liquidatorDebt.balanceBefore
    );
    state.totalDebt.balanceChange = _absDiff(
      state.totalDebt.balanceAfter,
      state.totalDebt.balanceBefore
    );
    state.supply.balanceChange = _absDiff(state.supply.balanceAfter, state.supply.balanceBefore);
    state.supplyShares.balanceChange = _absDiff(
      state.supplyShares.balanceAfter,
      state.supplyShares.balanceBefore
    );
    state.deficit.balanceChange = _absDiff(state.deficit.balanceAfter, state.deficit.balanceBefore);

    // convert amount to base currency
    state.liquidatorCollateral.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      state.liquidatorCollateral.balanceChange
    );
    state.liquidatorDebt.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      state.liquidatorDebt.balanceChange
    );
    state.totalDebt.baseChange = _convertAmountToBaseCurrency(
      state.debtReserves[state.debtReserveIndex].assetId,
      state.totalDebt.balanceChange
    );
    state.supply.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserves[state.collateralReserveIndex].assetId,
      state.supply.balanceChange
    );

    state.outstandingDebt = state.totalDebt.balanceBefore - state.debtToLiq;
    (
      state.userRp,
      ,
      state.finalHf,
      state.finalTotalCollateralInBaseCurrency,
      state.finalTotalDebtInBaseCurrency
    ) = state.spoke.getUserAccountData(state.user);

    state.hasDeficit =
      state.finalTotalCollateralInBaseCurrency == 0 &&
      state.finalTotalDebtInBaseCurrency == 0;

    state.usingAsCollateral = state.spoke.getUsingAsCollateral(
      state.collateralReserves[state.collateralReserveIndex].reserveId,
      state.user
    );

    // multi reserve accounting
    for (uint256 i = 0; i < state.debtReserves.length; i++) {
      state.deficits[i].balanceAfter = hub.getDeficit(state.debtReserves[i].assetId);

      state.deficits[i].balanceChange =
        state.deficits[i].balanceAfter -
        state.deficits[i].balanceBefore;

      state.debts[i].balanceAfter = state.spoke.getUserTotalDebt(
        state.debtReserves[i].reserveId,
        state.user
      );
      state.debts[i].balanceChange = _absDiff(
        state.debts[i].balanceAfter,
        state.debts[i].balanceBefore
      );
    }

    return state;
  }

  function _increaseCollateralReserveSupplyExchangeRate(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 borrowAmount,
    uint256 skipTime,
    address user
  ) internal {
    uint256 assetId = spoke.getReserve(collateralReserveId).assetId;
    uint256 initialExRate = hub.convertToSuppliedAssets(assetId, WadRayMathExtended.RAY.wadify());
    // mock price to 0 to circumvent borrow validation
    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
      abi.encode(0)
    );
    // user borrows some collateral reserve to inflate collateral supply ex rate
    // due to mocked price, user's rp will be 0
    Utils.borrow({
      spoke: spoke,
      reserveId: collateralReserveId,
      user: user,
      amount: borrowAmount,
      onBehalfOf: user
    });
    vm.clearMockedCalls();
    skip(skipTime);
    uint256 finalExRate = hub.convertToSuppliedAssets(assetId, WadRayMathExtended.RAY.wadify());
    assertGt(finalExRate, initialExRate);
  }

  function _logLiquidationTestLocalParams(LiquidationTestLocalParams memory state) internal {
    console.log(' liquidationProtocolFeePercentage %e', state.liquidationProtocolFeePercentage);
    console.log(' liquidationBonus %e', state.liquidationBonus);
    console.log(' liqProtocolFee %e', state.liqProtocolFee);

    console.log(
      ' collateralReserveId',
      state.collateralReserves[state.collateralReserveIndex].reserveId
    );
    console.log(
      ' collateralReserveAssetId',
      state.collateralReserves[state.collateralReserveIndex].assetId
    );

    console.log(' debtReserveId', state.debtReserves[state.debtReserveIndex].reserveId);
    console.log(' debtReserveAssetId', state.debtReserves[state.debtReserveIndex].assetId);

    console.log(' collToLiq %e', state.collToLiq);
    console.log(' debtToLiq %e', state.debtToLiq);

    console.log(' state.totalDebt.balanceAfter %e', state.totalDebt.balanceAfter);
    console.log(' state.totalDebt.balanceBefore %e', state.totalDebt.balanceBefore);

    console.log(' state.premiumDebt.balanceAfter %e', state.premiumDebt.balanceAfter);
    console.log(' state.premiumDebt.balanceBefore %e', state.premiumDebt.balanceBefore);

    console.log(' state.baseDebt.balanceAfter %e', state.baseDebt.balanceAfter);
    console.log(' state.baseDebt.balanceBefore %e', state.baseDebt.balanceBefore);

    console.log(' state.supply.balanceAfter %e', state.supply.balanceAfter);
    console.log(' state.supply.balanceBefore %e', state.supply.balanceBefore);
  }

  // TODO: update when dynamic risk config is implemented
  function _getCollateralFactor(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getCollateralFactor(reserveId);
  }
}
