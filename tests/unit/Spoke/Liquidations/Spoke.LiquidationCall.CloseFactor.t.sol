// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorTest is SpokeLiquidationBase {
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;
  using WadRayMathExtended for uint256;

  /// fuzz tests with close factor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  /// single debt reserve, single collateral reserve
  /// user health factor position is higher than threshold, so that close factor can be achieved post-liquidation
  /// close factor varies across range of values
  /// constant liquidation bonus
  function test_liquidationCall_fuzz_closeFactor_defaultCloseFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFee,
    uint256 skipTime
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor(
      collateralReserveId,
      debtReserveId,
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFee,
      skipTime
    );
  }

  /// variable close factor > HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_closeFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFee,
    uint256 skipTime
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFee,
      skipTime
    );

    _checkLiquidation(state, spoke1, 'test_liquidationCall_fuzz_closeFactor');
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_closeFactor_scenario1() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 2e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario1() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_closeFactor_scenario2() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario2() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_closeFactor_scenario3() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario3() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_closeFactor_scenario4() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario4() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_closeFactor_scenario5() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario5() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_closeFactor_scenario6() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario6() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: weth, both 18 decimals
  function test_liquidationCall_closeFactor_scenario7() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth, both 18 decimals, with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario7() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: usdx, both 6 decimals
  function test_liquidationCall_closeFactor_scenario8() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: usdx, both 18 decimals, with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario8() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days
    });
  }

  /// fuzz tests for supply ex rate increase
  /// can only increase by 1 wei due to rounding in withdraw
  function test_liquidationCall_fuzz_closeFactor_supply_ex_rate_incr(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 supplyAmount,
    uint256 skipTime,
    uint256 liqBonus
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTest({
      liqConfig: liqConfig,
      liqBonus: liqBonus,
      supplyAmount: supplyAmount,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liquidationProtocolFee: 0,
      skipTime: skipTime
    });

    // supply rate can be greater than previous due to rounding on hub remove, only by 1 wei
    assertGe(state.rate.rateAfter, state.rate.rateBefore, 'supply rate');
    assertApproxEqAbs(state.rate.rateAfter, state.rate.rateBefore, 1, 'supply rate precision');
  }

  /// constant liquidation bonus to simplify calcs for desiredHf
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );

    // set config to 0 so that desiredHf can be easily calculated (dependent on LB)
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorForMaxBonus = 0;

    return liqConfig;
  }

  /// fuzz tests where liquidation results in health factor = close factor
  function _execLiqCallCloseFactorTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFee,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.collDynConfig = spoke1.getDynamicReserveConfig(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMathExtended
        .PERCENTAGE_FACTOR
        .percentDiv(state.collDynConfig.collateralFactor)
        .percentMul(95_00) // add buffer so that amount to restore is > 0
    );

    liquidationProtocolFee = bound(liquidationProtocolFee, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e25),
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
    uint256 desiredHf = _calcLowestHfToRestoreCloseFactor(spoke1, collateralReserveId, liqBonus)
      .percentMul(101_00); // add buffer so that not all collateral is seized

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

    // with repay donation, it is possible to repay more than the actual debt amount
    if (stdMath.delta(state.debt.balanceAfter, state.debt.balanceBefore) > requiredDebtAmount) {
      assertApproxEqAbs(
        stdMath.delta(state.debt.balanceAfter, state.debt.balanceBefore),
        requiredDebtAmount,
        1,
        'required debt can be greater than actual debt due to repay donation'
      );
    }

    return state;
  }
}
