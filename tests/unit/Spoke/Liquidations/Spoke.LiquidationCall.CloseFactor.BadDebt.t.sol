// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

/// tests where liquidation results in bad debt (debt > 0, collateral = 0)
/// TODO: realize bad debt into deficit when deficit accounting is implemented, resolve tests
contract LiquidationCallCloseFactorBadDebtTest is SpokeLiquidationBase {
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  /// variable close factor > HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_closeFactor_badDebt(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationFee,
    uint256 skipTime
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.getReserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorBadDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationFee,
      skipTime
    );

    _checkLiquidation(state, spoke1, 'test_liquidationCall_fuzz_closeFactor_badDebt');

    // with no collateral remaining collateral should be disabled as collateral
    assertFalse(
      spoke1.getUsingAsCollateral(state.collateralReserve.reserveId, alice),
      'isUsingAsCollateral should be false with no collateral'
    );
    // all collateral is seized
    assertTrue(
      spoke1.getUserSuppliedAmount(collateralReserveId, alice) == 0,
      'remaining supplied collateral should be 0'
    );
    // TODO: bad debt should be cleared, removed from user but added to deficit
    // assertTrue(spoke1.getUserTotalDebt(debtReserveId, alice) > 0, 'remaining bad debt remains');

    (uint256 userRp, , uint256 healthFactor, , ) = spoke1.getUserAccountData(alice);
    assertEq(healthFactor, 0, 'health factor should be max after liquidation');
    assertEq(userRp, 0, 'user rp = 0 with no coll');
  }

  /// fuzz tests with close factor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_closeFactor_badDebt_defaultCloseFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationFee,
    uint256 skipTime
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor_badDebt(
      collateralReserveId,
      debtReserveId,
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationFee,
      skipTime
    );
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_closeFactor_badDebt_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor_badDebt({
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
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_badDebt_defaultValue_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_closeFactor_badDebt_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor_badDebt({
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
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_badDebt_defaultValue_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_closeFactor_badDebt_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor_badDebt({
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
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_badDebt_defaultValue_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_closeFactor_badDebt_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor_badDebt({
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
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_badDebt_defaultValue_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_closeFactor_badDebt_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor_badDebt({
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
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_badDebt_defaultValue_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_closeFactor_badDebt_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor_badDebt({
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
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_badDebt_defaultValue_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

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
    liqConfig.healthFactorForMaxBonus = 0;

    return liqConfig;
  }

  /// fuzz tests to make sure bad debt remains after liquidation
  /// single debt reserve, single collateral reserve
  /// user health factor position is lower than threshold -> liquidating all collateral is insufficient to cover debt
  /// close factor varies across range of values
  /// constant liquidation bonus
  function _execLiqCallCloseFactorBadDebtTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationFee,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    vm.skip(true, 'pending deficit accounting');

    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDiv(state.collDynConfig.collateralFactor)
    );

    liquidationFee = bound(liquidationFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(spoke1, state.collateralReserve.reserveId, 1e25),
      _min(
        _convertBaseCurrencyToAmount(
          spoke1,
          state.collateralReserve.reserveId,
          MAX_SUPPLY_IN_BASE_CURRENCY
        ),
        MAX_SUPPLY_AMOUNT
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.liquidationFee = liquidationFee;

    // set spoke liq config
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationFee(spoke1, collateralReserveId, state.liquidationFee);
    // set user position under hf threshold so that there is invalid collateral to cover all debt
    // results in bad debt remaining (debt > 0, collateral = 0)
    uint256 desiredHf = _calcLowestHfToRestoreCloseFactor(spoke1, collateralReserveId, liqBonus)
      .percentMul(99_00);

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

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
    (
      state.collToLiq,
      state.debtToLiq,
      state.liquidationFeeAmount
    ) = _calculateAvailableCollateralToLiquidate(spoke1, state, requiredDebtAmount);

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

    // if bad debt remains, supplied amount should be 0 after liquidation
    // debt remaining should be > 0
    assertTrue(state.supply.balanceAfter == 0 && state.debt.balanceAfter > 0);
    // with a close factor, it is impossible to liquidate all debt
    assertTrue(
      stdMath.delta(state.debt.balanceAfter, state.debt.balanceBefore) < requiredDebtAmount
    );

    return state;
  }
}
