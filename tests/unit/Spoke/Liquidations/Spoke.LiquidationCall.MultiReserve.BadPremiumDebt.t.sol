// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

/// tests with bad debt across multiple reserves that includes accrued premium debt
contract LiquidationCallMultiReserveBadPremiumDebtTest is SpokeLiquidationBase {
  using PercentageMath for uint256;

  struct BorrowMultipleReservesToBeAboveHealthyHf {
    uint256 requiredDebtInBase;
    uint256 remaining;
  }
  struct ReportDeficitEvent {
    uint256 assetId;
    address spoke;
    uint256 deficitShares;
    DataTypes.PremiumDelta premiumDelta;
    uint256 deficitAmount;
  }

  /// @dev coll: weth; bad debt: wbtc, dai, usdx
  /// deficit covers drawn debt and premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario1_base_and_premium() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario1({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4,
      debtReserveIndex: 0
    });
  }

  /// @dev coll: weth; bad debt: wbtc, dai, usdx
  /// deficit only covers premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario1_only_premium() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario1({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days,
      debtReserveIndex: 0
    });
  }

  /// fuzz test - bad debt: wbtc, dai, usdx
  function test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario1(
    uint256 collateralReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium,
    uint256 debtReserveIndex
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);

    uint256[] memory debtReserveIds = new uint256[](3);
    // debtReserveIds must be in ascending order for event emission assertions
    debtReserveIds[0] = _wbtcReserveId(spoke1);
    debtReserveIds[1] = _daiReserveId(spoke1);
    debtReserveIds[2] = _usdxReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorMultiAssetBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveIds,
      debtReserveIndex,
      liquidationFee,
      skipTime,
      skipTimeToAccruePremium
    );
    _checkLiquidation(
      state,
      'test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario1_only_premium'
    );
    _checkDebtReserveDeficits(state, debtReserveIds, alice);
  }

  /// coll: weth; bad debt: wbtc, dai, usdx
  /// deficit covers drawn debt and premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario2_only_premium() public {
    uint256 collateralReserveId = _wbtcReserveId(spoke1);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario2({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4,
      debtReserveIndex: 0
    });
  }

  /// coll: weth; bad debt: wbtc, dai, usdx
  /// deficit covers only premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario2_base_and_premium() public {
    uint256 collateralReserveId = _wbtcReserveId(spoke1);

    // update to a high liquidity premium so that even after liquidating all collateral, both base/premium debt remains
    updateCollateralRisk(spoke1, collateralReserveId, 100_00);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario2({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 2,
      debtReserveIndex: 0
    });
  }

  /// fuzz test - bad debt: weth, wbtc, usdy
  function test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario2(
    uint256 collateralReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium,
    uint256 debtReserveIndex
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);

    uint256[] memory debtReserveIds = new uint256[](3);
    // debtReserveIds must be in ascending order for event emission assertions
    debtReserveIds[0] = _wethReserveId(spoke1);
    debtReserveIds[1] = _wbtcReserveId(spoke1);
    debtReserveIds[2] = _usdyReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorMultiAssetBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveIds,
      debtReserveIndex,
      liquidationFee,
      skipTime,
      skipTimeToAccruePremium
    );

    string memory label = 'test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario2';
    _checkLiquidation(state, label);
    _checkDebtReserveDeficits(state, debtReserveIds, alice);
  }

  /// coll: usdy; bad debt: dai, usdx, usdy
  /// deficit covers drawn debt and premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario3_base_and_premium() public {
    uint256 collateralReserveId = _usdyReserveId(spoke1);

    // update to a high liquidity premium so that even after liquidating all collateral, both base/premium debt remains
    updateCollateralRisk(spoke1, collateralReserveId, 100_00);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario3({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4,
      debtReserveIndex: 0
    });
  }

  /// coll: usdy; bad debt: dai, usdx, usdy
  /// deficit covers only premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario3_only_premium() public {
    uint256 collateralReserveId = _usdyReserveId(spoke1);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario3({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4,
      debtReserveIndex: 0
    });
  }

  /// fuzz test - bad debt: dai, usdx, usdy
  function test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario3(
    uint256 collateralReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium,
    uint256 debtReserveIndex
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);

    uint256[] memory debtReserveIds = new uint256[](3);
    // debtReserveIds must be in ascending order for event emission assertions
    debtReserveIds[0] = _daiReserveId(spoke1);
    debtReserveIds[1] = _usdxReserveId(spoke1);
    debtReserveIds[2] = _usdyReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorMultiAssetBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveIds,
      debtReserveIndex,
      liquidationFee,
      skipTime,
      skipTimeToAccruePremium
    );

    string memory label = 'test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario3';
    _checkLiquidation(state, label);
    _checkDebtReserveDeficits(state, debtReserveIds, alice);
  }

  /// execute fuzz tests with bad debt across multiple debt reserves, single collateral reserve
  /// liquidating all collateral is insufficient to cover debt, bad debt remains
  /// close factor varies across range of values
  /// non-variable liquidation bonus
  function _execLiqCallCloseFactorMultiAssetBadPremiumDebtTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256[] memory debtReserveIds,
    uint256 debtReserveIndex,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 skipTimeForPremiumAccrual
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);

    state.spoke = spoke1;
    state.user = alice;

    state.collateralReserves[state.collateralReserveIndex] = state.spoke.getReserve(
      collateralReserveId
    );
    state.debtReserveIndex = bound(debtReserveIndex, 0, debtReserveIds.length - 1);
    state.debtReserves = new DataTypes.Reserve[](debtReserveIds.length);
    state.collDynConfig = _getUserDynConfig(state.spoke, state.user, collateralReserveId);

    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      state.debtReserves[i] = state.spoke.getReserve(debtReserveIds[i]);
    }
    state.collateralReserve = state.collateralReserves[state.collateralReserveIndex];
    state.debtReserve = state.debtReserves[state.debtReserveIndex];

    liqConfig = _boundCloseFactor(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDivDown(state.collDynConfig.collateralFactor)
    );
    state.liquidationFee = bound(liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.spoke, state.collateralReserve.reserveId, 10e26),
      _convertBaseCurrencyToAmount(state.spoke, state.collateralReserve.reserveId, 1e36)
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    skipTimeForPremiumAccrual = bound(skipTimeForPremiumAccrual, 365 days, MAX_SKIP_TIME); // enough time to accrue debt so that HF is liquidatable

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
    _borrowWithoutHfCheck({
      spoke: state.spoke,
      user: bob,
      reserveId: collateralReserveId,
      debtAmount: supplyAmount / 2
    });
    skip(skipTime);

    // calculate lowest HF where there is sufficient collateral to cover debt
    // below this value results in bad debt
    uint256 hfBadDebtThreshold = _calcLowestHfForBadDebt(state.spoke, state.user, liqBonus);

    // borrow some amount of debt reserve to end up below hf threshold
    _borrowMultipleReservesToBeAboveHealthyHf(
      state.spoke,
      state.user,
      debtReserveIds,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    // skip time to accrue premium debt
    skip(skipTimeForPremiumAccrual);

    state = _getAccountingInfoBeforeLiquidation(state);

    state.liquidationBonus = state.spoke.getVariableLiquidationBonus(
      collateralReserveId,
      state.user,
      state.initialHf
    );

    // ensure that there is bad debt that includes premium debt
    vm.assume(
      state.spoke.getHealthFactor(state.user) < hfBadDebtThreshold &&
        _convertAmountToBaseCurrency(
          state.spoke,
          state.debtReserve.reserveId,
          state.spoke.getUserTotalDebt(state.debtReserve.reserveId, state.user)
        ) >
        state.totalCollateralInBaseCurrency.balanceBefore
    );

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

    ReportDeficitEvent[] memory expectedLogs = new ReportDeficitEvent[](debtReserveIds.length);

    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      uint256 reserveId = debtReserveIds[i];
      uint256 assetId = state.debtReserves[i].assetId;

      uint256 expectedDeficitShares;
      uint256 expectedDeficitAmount;
      DataTypes.PremiumDelta memory expectedDeficitPremiumDelta;

      if (reserveId != state.debtReserve.reserveId) {
        DataTypes.UserPosition memory userPosition = state.spoke.getUserPosition(reserveId, alice);
        expectedDeficitShares = userPosition.drawnShares;
        expectedDeficitAmount = state.spoke.getUserTotalDebt(reserveId, alice);
        expectedDeficitPremiumDelta = DataTypes.PremiumDelta(
          -int256(userPosition.premiumShares),
          -int256(userPosition.premiumOffset),
          -int256(userPosition.realizedPremium)
        );
        // for debt asset being liquidated, some debt is restored prior to deficit creation
      } else {
        DataTypes.UserPosition memory userPosition = state.spoke.getUserPosition(reserveId, alice);
        (uint256 drawnDebtRestored, uint256 premDebtRestored) = _calculateExactRestoreAmount(
          state.userDrawnDebt.balanceBefore,
          state.userPremiumDebt.balanceBefore,
          state.debtToLiq,
          assetId
        );

        // debt asset deficit shares are the initial amount minus the amount restored during liquidation
        state.expectedDeficitShares = expectedDeficitShares =
          userPosition.drawnShares -
          hub1.convertToDrawnShares(assetId, drawnDebtRestored);
        // total debt asset deficit is the expected drawn debt and remaining premium debt after settlement during liquidation
        state.expectedDeficitAmount = expectedDeficitAmount =
          hub1.convertToDrawnAssets(assetId, expectedDeficitShares) +
          state.userPremiumDebt.balanceBefore -
          premDebtRestored;
        uint256 accruedPremium = hub1.convertToDrawnAssets(assetId, userPosition.premiumShares) -
          userPosition.premiumOffset;
        // premium shares & offset were reset in the prior restore, and the remaining realized premium is now restored as deficit
        expectedDeficitPremiumDelta = DataTypes.PremiumDelta(
          0,
          0,
          int256(premDebtRestored) - int256(accruedPremium)
        );
      }
      expectedLogs[i] = ReportDeficitEvent({
        assetId: assetId,
        spoke: address(state.spoke),
        deficitShares: expectedDeficitShares,
        premiumDelta: expectedDeficitPremiumDelta,
        deficitAmount: expectedDeficitAmount
      });

      // @dev We omit checking data (deficitShares, premiumDelta, deficitAmount) here since premiumDelta.realizedDelta
      // can be off by 2 wei due to exchange rate changing because of 2 wei instant premium debt during restore before deficit
      // in the case when liquidated asset is also reported in deficit.
      // It will be checked within 2 wei, rest exact, in the post action checks since we'll record the actual logs. (_checkReportDeficitEvents)
      vm.expectEmit({
        checkTopic1: true,
        checkTopic2: true,
        checkTopic3: true,
        checkData: false,
        emitter: address(hub1)
      });
      emit IHub.ReportDeficit(
        assetId,
        address(state.spoke),
        expectedDeficitShares,
        expectedDeficitPremiumDelta,
        expectedDeficitAmount
      );
    }
    vm.expectEmit(address(state.spoke));
    emit ISpoke.UserRiskPremiumUpdate(state.user, 0);

    vm.expectEmit(address(state.spoke));
    emit ISpokeBase.LiquidationCall(
      state.collateralReserve.underlying,
      state.debtReserve.underlying,
      state.user,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );

    vm.recordLogs();

    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(
      collateralReserveId,
      debtReserveIds[state.debtReserveIndex],
      state.user,
      UINT256_MAX
    );

    state = _getAccountingInfoAfterLiquidation(state);
    _checkReportDeficitEvents(expectedLogs, vm.getRecordedLogs());

    return state;
  }

  /// @dev check deficit reported events data against actual logs, all exact except for realizedDelta which is checked within 2 wei
  function _checkReportDeficitEvents(
    ReportDeficitEvent[] memory expectedLogs,
    Vm.Log[] memory actualLogs
  ) internal view {
    uint256 expectedLogCounter = 0;
    for (uint256 i = 0; i < actualLogs.length; ++i) {
      Vm.Log memory actualLog = actualLogs[i];
      if (actualLog.topics[0] != IHub.ReportDeficit.selector) continue;

      ReportDeficitEvent memory expectedLog = expectedLogs[expectedLogCounter++];
      assertEq(actualLog.emitter, address(hub1), 'deficit reported event: emitter');
      assertEq(
        uint256(actualLog.topics[1]),
        expectedLog.assetId,
        'deficit reported event: assetId'
      );
      assertEq(
        address(uint160(uint256(actualLog.topics[2]))),
        expectedLog.spoke,
        'deficit reported event: spoke'
      );
      (
        uint256 deficitShares,
        DataTypes.PremiumDelta memory premiumDelta,
        uint256 deficitAmount
      ) = abi.decode(actualLog.data, (uint256, DataTypes.PremiumDelta, uint256));
      assertEq(deficitShares, expectedLog.deficitShares, 'deficit reported event: deficitShares');
      assertEq(deficitAmount, expectedLog.deficitAmount, 'deficit reported event: deficitAmount');
      assertEq(
        premiumDelta.sharesDelta,
        expectedLog.premiumDelta.sharesDelta,
        'deficit reported event: premiumDelta.sharesDelta'
      );
      assertEq(
        premiumDelta.offsetDelta,
        expectedLog.premiumDelta.offsetDelta,
        'deficit reported event: premiumDelta.offsetDelta'
      );
      assertApproxEqAbs(
        premiumDelta.realizedDelta,
        expectedLog.premiumDelta.realizedDelta,
        2,
        'deficit reported event: premiumDelta.realizedDelta'
      );
    }

    assertEq(
      expectedLogCounter,
      expectedLogs.length,
      'all deficit reported events should be checked'
    );
  }

  /// @dev Borrow random amounts from multiple reserves to ensure the health factor is above the desired HF
  /// validates HF, therefore it must be a healthy HF
  function _borrowMultipleReservesToBeAboveHealthyHf(
    ISpoke spoke,
    address user,
    uint256[] memory reserveIds,
    uint256 desiredHf
  ) internal returns (uint256 finalHf, uint256[] memory requiredDebts) {
    BorrowMultipleReservesToBeAboveHealthyHf memory vars;
    requiredDebts = new uint256[](reserveIds.length);

    // extra debt to ensure HF below desired
    vars.requiredDebtInBase = _getRequiredDebtForGtHf(spoke, user, desiredHf);
    vars.remaining = vars.requiredDebtInBase;
    // make sure that each reserve has at least dustInBase in debt
    uint256 dustInBase = 1e26;

    // mock with high base borrow rate so that less time must be skipped to reach desired HF
    _mockInterestRateBps(500_00);

    for (uint256 i = 0; i < reserveIds.length; i++) {
      uint256 assetId = spoke.getReserve(reserveIds[i]).assetId;
      uint256 amountInBase;
      // randomly distribute total required debt across debt reserves
      if (i == reserveIds.length - 1) {
        // Last iteration, borrow remaining amount
        amountInBase = vars.remaining;
      } else {
        amountInBase = randomizer(
          dustInBase,
          vars.remaining - dustInBase * (reserveIds.length - i - 1)
        );
      }
      uint256 amount = _convertBaseCurrencyToAmount(spoke, reserveIds[i], amountInBase);
      vm.assume(amount < MAX_SUPPLY_AMOUNT);

      Utils.borrow({
        spoke: spoke,
        reserveId: reserveIds[i],
        caller: user,
        amount: amount,
        onBehalfOf: user
      });

      vars.remaining -= amountInBase;
      requiredDebts[i] = amount;
    }

    finalHf = spoke.getHealthFactor(user);
    assertGt(finalHf, desiredHf, 'should borrow enough for HF to be above desiredHf');
  }

  /// @dev Check deficit accounting for all remaining debt reserves
  /// debt reserve being liquidated is checked in _assertBadDebt
  function _checkDebtReserveDeficits(
    LiquidationTestLocalParams memory state,
    uint256[] memory debtReserveIds,
    address user
  ) internal pure {
    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      assertEq(
        state.userTotalDebts[i].balanceAfter,
        0,
        'remaining debt should be 0 (reported as deficit)'
      );
      if (i != state.debtReserveIndex) {
        uint256 expectedDeficitAmount = state.userTotalDebts[i].balanceChange; // for other debt assets, total debt should be reported as deficit
        assertEq(
          state.deficits[i].balanceChange,
          expectedDeficitAmount,
          'non-liquidated debt asset deficit'
        );
      } else {
        assertEq(
          state.deficits[i].balanceChange,
          state.expectedDeficitAmount,
          'liquidated debt asset deficit'
        );
      }
    }
  }
}
