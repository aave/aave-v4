// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallMultiReserveBadPremiumDebtTest is SpokeLiquidationBase {
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  /// tests where liquidation results in bad debt with premium debt > 0
  function test_liquidationCall_fuzz_multi_reserve_badPremiumDebt(
    uint256 collateralReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);

    uint256[] memory debtReserveIds = new uint256[](3);
    debtReserveIds[0] = _daiReserveId(spoke1);
    debtReserveIds[1] = _usdxReserveId(spoke1);
    debtReserveIds[2] = _usdyReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveIds,
      liquidationProtocolFeePercentage,
      skipTime,
      skipTimeToAccruePremium
    );

    string memory label = 'test_liquidationCall_fuzz_multi_reserve_badPremiumDebt';
    _checkLiquidation(state, spoke1, label);

    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      assertEq(
        spoke1.getUserTotalDebt(debtReserveIds[i], alice),
        0,
        'remaining debt should be 0 (reported as deficit)'
      );
      if (i != state.debtReserveIndex) {
        assertEq(
          state.deficits[i].balanceChange,
          state.debts[i].balanceChange,
          'for other debt assets, total debt should be reported as deficit'
        );
      }
      // console.log(
      //   ' deficit %e debt change %e',
      //   state.deficits[i].balanceChange,
      //   state.debts[i].balanceChange
      // );
    }

    // for (uint256 i = 0; i < state.deficits.length; i++) {
    //   console.log(
    //     ' id %s total debt %e',
    //     debtReserveIds[i],
    //     spoke1.getUserTotalDebt(debtReserveIds[i], alice)
    //   );
    //   console.log(
    //     ' deficit %e debt change %e',
    //     state.deficits[i].balanceChange,
    //     state.debts[i].balanceChange
    //   );
    //   // assertEq(
    //   //   ,
    //   //   'bad debt should be moved to deficit'
    //   // );
    // }
  }

  /// coll: weth
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  // /// coll: weth / debt: usdx
  // function test_liquidationCall_badPremiumDebt_scenario2() public {
  //   uint256 collateralReserveId = _wethReserveId(spoke1);
  //   uint256 debtReserveId = _usdxReserveId(spoke1);

  //   test_liquidationCall_fuzz_badPremiumDebt({
  //     liqConfig: DataTypes.LiquidationConfig({
  //       closeFactor: 1.5e18,
  //       liquidationBonusFactor: 0,
  //       healthFactorBonusThreshold: 0
  //     }),
  //     liqBonus: 105_00,
  //     supplyAmount: 1.5e18,
  //     liquidationProtocolFeePercentage: 5_00,
  //     collateralReserveId: collateralReserveId,
  //     debtReserveId: debtReserveId,
  //     skipTime: 365 days,
  //     skipTimeToAccruePremium: 365 days * 4
  //   });
  // }

  // /// coll: usdx / debt: weth
  // function test_liquidationCall_badPremiumDebt_scenario3() public {
  //   uint256 collateralReserveId = _usdxReserveId(spoke1);
  //   uint256 debtReserveId = _wethReserveId(spoke1);

  //   test_liquidationCall_fuzz_badPremiumDebt({
  //     liqConfig: DataTypes.LiquidationConfig({
  //       closeFactor: 1.5e18,
  //       liquidationBonusFactor: 0,
  //       healthFactorBonusThreshold: 0
  //     }),
  //     liqBonus: 105_00,
  //     supplyAmount: 10e6,
  //     liquidationProtocolFeePercentage: 5_00,
  //     collateralReserveId: collateralReserveId,
  //     debtReserveId: debtReserveId,
  //     skipTime: 365 days,
  //     skipTimeToAccruePremium: 365 days * 4
  //   });
  // }

  // /// coll: usdx / debt: dai
  // function test_liquidationCall_badPremiumDebt_scenario4() public {
  //   uint256 collateralReserveId = _usdxReserveId(spoke1);
  //   uint256 debtReserveId = _daiReserveId(spoke1);

  //   test_liquidationCall_fuzz_badPremiumDebt({
  //     liqConfig: DataTypes.LiquidationConfig({
  //       closeFactor: 1.5e18,
  //       liquidationBonusFactor: 0,
  //       healthFactorBonusThreshold: 0
  //     }),
  //     liqBonus: 105_00,
  //     supplyAmount: 10e6,
  //     liquidationProtocolFeePercentage: 5_00,
  //     collateralReserveId: collateralReserveId,
  //     debtReserveId: debtReserveId,
  //     skipTime: 365 days,
  //     skipTimeToAccruePremium: 365 days * 4
  //   });
  // }

  // /// coll: dai / debt: weth
  // function test_liquidationCall_badPremiumDebt_scenario5() public {
  //   uint256 collateralReserveId = _daiReserveId(spoke1);
  //   uint256 debtReserveId = _wethReserveId(spoke1);

  //   test_liquidationCall_fuzz_badPremiumDebt({
  //     liqConfig: DataTypes.LiquidationConfig({
  //       closeFactor: 1.5e18,
  //       liquidationBonusFactor: 0,
  //       healthFactorBonusThreshold: 0
  //     }),
  //     liqBonus: 105_00,
  //     supplyAmount: 1_000e6,
  //     liquidationProtocolFeePercentage: 5_00,
  //     collateralReserveId: collateralReserveId,
  //     debtReserveId: debtReserveId,
  //     skipTime: 365 days,
  //     skipTimeToAccruePremium: 365 days * 4
  //   });
  // }

  // /// coll: dai / debt: usdx
  // function test_liquidationCall_badPremiumDebt_scenario6() public {
  //   uint256 collateralReserveId = _daiReserveId(spoke1);
  //   uint256 debtReserveId = _usdxReserveId(spoke1);

  //   test_liquidationCall_fuzz_badPremiumDebt({
  //     liqConfig: DataTypes.LiquidationConfig({
  //       closeFactor: 1.5e18,
  //       liquidationBonusFactor: 0,
  //       healthFactorBonusThreshold: 0
  //     }),
  //     liqBonus: 105_00,
  //     supplyAmount: 1_000e6,
  //     liquidationProtocolFeePercentage: 5_00,
  //     collateralReserveId: collateralReserveId,
  //     debtReserveId: debtReserveId,
  //     skipTime: 365 days,
  //     skipTimeToAccruePremium: 365 days * 4
  //   });
  // }

  /// bound liqConfig close factor, with static liquidation bonus
  /// use constant liquidation bonus to simplify calcs for desiredHf
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
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

  /// fuzz tests to make sure bad debt remains after liquidation
  /// single debt reserve, single collateral reserve
  /// user health factor position is lower than threshold -> liquidating all collateral is insufficient to cover debt
  /// close factor varies across range of values
  /// constant liquidation bonus
  function _execLiqCallCloseFactorBadPremiumDebtTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256[] memory debtReserveIds,
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime,
    uint256 skipTimeForPremiumAccrual
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserves = new DataTypes.Reserve[](debtReserveIds.length);

    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      state.debtReserves[i] = spoke1.getReserve(debtReserveIds[i]);
      console.log('  debtReserveId %e', debtReserveIds[i]);
    }

    state.debtReserve = state.debtReserves[0];

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDiv(state.collateralReserve.config.collateralFactor)
    );
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 10e26),
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e36)
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    skipTimeForPremiumAccrual = bound(skipTimeForPremiumAccrual, 5 * 365 days, MAX_SKIP_TIME); // enough time to accrue debt so that HF is liquidatable

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    // set spoke liq config
    spoke1.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );
    // calculate lowest HF where there is sufficient collateral to cover debt
    // below this value results in bad debt
    uint256 hfBadDebtThreshold = _calcLowestHfToRestoreCloseFactor(collateralReserveId, liqBonus);

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    _increaseCollateralReserveSupplyExchangeRate(
      state.collateralReserve.assetId,
      collateralReserveId,
      supplyAmount / 2,
      skipTime,
      bob
    );

    // borrow some amount of debt reserve to end up below hf threshold
    (
      uint256 hfAfterBorrow,
      uint256[] memory requiredDebtAmounts
    ) = _borrowMultipleReservesToBeAboveHealthyHf(
        spoke1,
        alice,
        debtReserveIds,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
      );

    state.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      collateralReserveId,
      hfAfterBorrow
    );

    skip(skipTimeForPremiumAccrual);

    // (uint256 rp, , uint256 hf, , ) = spoke1.getUserAccountData(alice);
    // (uint256 baseDebt, uint256 premiumDebt) = spoke1.getUserDebt(debtReserveIds[0], alice);

    // console.log('rp %e debt %e %e', rp, baseDebt, premiumDebt);
    // (baseDebt, premiumDebt) = spoke1.getUserDebt(debtReserveIds[1], alice);
    // console.log('debt %e %e', rp, baseDebt, premiumDebt);
    // console.log('hf %e', hf);

    // assertLt(hf, hfBadDebtThreshold, 'HF should result in bad debt');
    state = _getAccountingInfoBeforeLiq(state);

    // ensure that debt accrued causes liquidatable position
    // and that the liquidated debt asset will fully cover the collateral
    vm.assume(
      spoke1.getHealthFactor(alice) < hfBadDebtThreshold &&
        _convertAmountToBaseCurrency(
          state.debtReserves[state.debtReserveIndex].assetId,
          spoke1.getUserTotalDebt(state.debtReserves[state.debtReserveIndex].reserveId, alice)
        ) >
        state.initialTotalCollateralInBaseCurrency
    );

    assertGt(state.premiumDebt.balanceBefore, 0, 'premium debt should be > 0 before liquidation');

    // console.log(
    //   'requiredDebtAmounts %e %e',
    //   _convertAmountToBaseCurrency(
    //     state.debtReserves[state.debtReserveIndex].assetId,
    //     spoke1.getUserTotalDebt(state.debtReserves[state.debtReserveIndex].reserveId, alice)
    //   ),
    //   state.initialTotalCollateralInBaseCurrency
    // );

    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee,

    ) = _calculateAvailableCollateralToLiquidate(spoke1, state, UINT256_MAX);

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    // console.log(
    //   'emit deficit %s %s %e',
    //   address(spoke1),
    //   state.debtReserve.assetId,
    //   state.debt.balanceBefore - state.debtToLiq
    // );

    // for (uint256 i = 0; i < debtReserveIds.length; i++) {
    //   console.log(
    //     ' id %s total debt %e',
    //     debtReserveIds[i],
    //     spoke1.getUserTotalDebt(debtReserveIds[i], alice)
    //   );
    // }

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCreated(
      address(spoke1),
      state.debtReserve.assetId,
      state.debt.balanceBefore - state.debtToLiq // outstanding debt which becomes bad debt reported as deficit
    );
    // for remaining debt assets, total debt is reported as deficit
    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      console.log(
        ' id %s total debt %e',
        debtReserveIds[i],
        spoke1.getUserTotalDebt(debtReserveIds[i], alice)
      );
      if (debtReserveIds[i] != state.debtReserve.reserveId) {
        vm.expectEmit(address(hub));
        emit ILiquidityHub.DeficitCreated(
          address(spoke1),
          state.debtReserves[i].assetId,
          spoke1.getUserTotalDebt(debtReserveIds[i], alice)
        );
      }
    }
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
    spoke1.liquidationCall(
      collateralReserveId,
      debtReserveIds[state.debtReserveIndex],
      alice,
      UINT256_MAX
    );

    state = _getAccountingInfoAfterLiq(state);

    console.log('supply balanceAfter %e', state.supplyShares.balanceAfter);

    // for (uint256 i = 0; i < state.deficits.length; i++) {

    //   console.log(
    //     ' id %s total debt %e',
    //     debtReserveIds[i],
    //     spoke1.getUserTotalDebt(debtReserveIds[i], alice)
    //   );
    //   console.log(
    //     ' deficit %e debt change %e',
    //     state.deficits[i].balanceChange,
    //     state.debts[i].balanceChange
    //   );
    //   // assertEq(
    //   //   ,
    //   //   'bad debt should be moved to deficit'
    //   // );
    // }

    // revert('bad prem debt');

    return state;
  }

  struct BorrowMultipleReservesToBeAboveHealthyHf {
    uint256 requiredDebtInBase;
    uint256 remaining;
  }

  /// @notice Borrow random amounts from multiple reserves to ensure the health factor is above the desired level.
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
    mockBaseBorrowRate(500_00);

    vm.startPrank(user);
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

      uint256 amount = _convertBaseCurrencyToAmount(assetId, amountInBase) + 1;
      vm.assume(amount < MAX_SUPPLY_AMOUNT);

      // // mock price to 0 to circumvent borrow validation
      // vm.mockCall(
      //   address(oracle),
      //   abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
      //   abi.encode(0)
      // );
      spoke.borrow(reserveIds[i], amount, user);
      // console.log('borrow %e %e', reserveIds[i], amount);
      // console.log('borrowSh %e', spoke.getUserTotalDebt(reserveIds[i], user));

      vars.remaining -= amountInBase;
      requiredDebts[i] = amount;
    }
    // vm.clearMockedCalls();
    vm.stopPrank();

    (, , finalHf, , ) = spoke.getUserAccountData(user);
    assertGt(finalHf, desiredHf, 'should borrow enough for HF to be above desiredHf');
  }
}
