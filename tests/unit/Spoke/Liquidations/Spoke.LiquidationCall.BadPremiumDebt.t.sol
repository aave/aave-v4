// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

/// tests with bad debt with a single collateral/debt reserve that includes accrued premium debt
contract LiquidationCallBadPremiumDebtTest is SpokeLiquidationBase {
  using PercentageMath for uint256;

  /// tests where liquidation results in bad debt with premium debt > 0
  function test_liquidationCall_fuzz_badPremiumDebt(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.getReserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationFee,
      skipTime,
      skipTimeToAccruePremium
    );

    string memory label = 'test_liquidationCall_fuzz_badPremiumDebt';
    _checkLiquidation(state, label);
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_badPremiumDebt_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_badPremiumDebt_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_badPremiumDebt_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_badPremiumDebt_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_badPremiumDebt_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_badPremiumDebt_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// fuzz tests to make sure bad debt remains after liquidation
  /// single debt reserve, single collateral reserve
  /// user health factor position is lower than threshold -> liquidating all collateral is insufficient to cover debt
  /// close factor varies across range of values
  /// non-variable liquidation bonus
  function _execLiqCallCloseFactorBadPremiumDebtTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 skipTimeForPremiumAccrual
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);
    state.debtReserves = new DataTypes.Reserve[](1);
    state.spoke = spoke1;
    state.user = alice;

    state.collateralReserves[state.collateralReserveIndex] = state.spoke.getReserve(
      collateralReserveId
    );
    state.debtReserves[state.debtReserveIndex] = state.spoke.getReserve(debtReserveId);
    state.collDynConfig = _getUserDynConfig(state.spoke, state.user, collateralReserveId);
    state.collateralReserve = state.collateralReserves[state.collateralReserveIndex];
    state.debtReserve = state.debtReserves[state.debtReserveIndex];

    liqConfig = _boundCloseFactor(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDivDown(state.collDynConfig.collateralFactor)
    );
    liquidationFee = bound(liquidationFee, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.spoke, state.collateralReserve.reserveId, 10e26),
      _convertBaseCurrencyToAmount(state.spoke, state.collateralReserve.reserveId, 1e36)
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    skipTimeForPremiumAccrual = bound(skipTimeForPremiumAccrual, 5 * 365 days, MAX_SKIP_TIME); // enough time to accrue debt so that HF is liquidatable

    state.liquidationFee = liquidationFee;

    // set spoke liq config
    updateLiquidationConfig(state.spoke, liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationFee(state.spoke, collateralReserveId, state.liquidationFee);

    Utils.supplyCollateral({
      spoke: state.spoke,
      reserveId: collateralReserveId,
      caller: state.user,
      amount: supplyAmount,
      onBehalfOf: state.user
    });

    // calculate lowest HF where there is sufficient collateral to cover debt
    // below this value results in bad debt during liquidation
    uint256 hfBadDebtThreshold = _calcLowestHfForBadDebt(state.spoke, alice, liqBonus);

    _borrowWithoutHfCheck({
      spoke: spoke1,
      user: bob,
      reserveId: collateralReserveId,
      debtAmount: supplyAmount / 2
    });
    skip(skipTime);

    // borrow some amount of debt reserve to keep healthy hf initially
    (uint256 hfAfterBorrow, ) = _borrowToBeAboveHealthyHf(
      state.spoke,
      alice,
      debtReserveId,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    state.liquidationBonus = state.spoke.getVariableLiquidationBonus(
      collateralReserveId,
      state.user,
      hfAfterBorrow
    );

    skip(skipTimeForPremiumAccrual);
    // ensure that debt accrued results in HF below bad debt threshold
    // causes bad debt to remain
    vm.assume(state.spoke.getHealthFactor(alice) < hfBadDebtThreshold);

    state = _getAccountingInfoBeforeLiquidation(state);

    assertGt(
      state.userPremiumDebt.balanceBefore,
      0,
      'premium debt should be > 0 before liquidation'
    );

    (
      state.collToLiq,
      state.debtToLiq,
      state.liquidationFeeAmount,

    ) = _calculateAvailableCollateralToLiquidate(state, UINT256_MAX);

    uint256 debtAssetId = state.debtReserve.assetId;
    DataTypes.UserPosition memory userPosition = state.spoke.getUserPosition(debtReserveId, alice);
    (uint256 drawnDebtRestored, uint256 premDebtRestored) = _calculateExactRestoreAmount(
      state.userDrawnDebt.balanceBefore,
      state.userPremiumDebt.balanceBefore,
      state.debtToLiq,
      debtAssetId
    );

    // debt asset deficit shares are the initial amount minus the amount restored during liquidation
    state.expectedDeficitShares =
      userPosition.drawnShares -
      hub1.convertToDrawnShares(debtAssetId, drawnDebtRestored);
    // total debt asset deficit is the expected drawn debt and remaining premium debt after settlement during liquidation
    state.expectedDeficitAmount =
      hub1.convertToDrawnAssets(debtAssetId, state.expectedDeficitShares) +
      state.userPremiumDebt.balanceBefore -
      premDebtRestored;
    {
      uint256 accruedPremium = hub1.convertToDrawnAssets(debtAssetId, userPosition.premiumShares) -
        userPosition.premiumOffset;
      // premium shares & offset were reset in the prior restore, and the remaining realized premium is now restored as deficit
      DataTypes.PremiumDelta memory expectedDeficitPremiumDelta = DataTypes.PremiumDelta(
        0,
        0,
        int256(premDebtRestored) - int256(accruedPremium)
      );

      vm.expectEmit(address(hub1));
      emit IHub.DeficitReported(
        debtAssetId,
        address(state.spoke),
        state.expectedDeficitShares,
        expectedDeficitPremiumDelta,
        state.expectedDeficitAmount
      );
    }

    vm.expectEmit(address(state.spoke));
    emit ISpokeBase.LiquidationCall(
      state.collateralReserve.underlying,
      state.debtReserve.underlying,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, alice, UINT256_MAX);

    state = _getAccountingInfoAfterLiquidation(state);
    return state;
  }
}
