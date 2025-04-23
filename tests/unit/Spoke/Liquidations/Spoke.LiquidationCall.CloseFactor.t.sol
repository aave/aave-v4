// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  uint256 minSupplyInBaseCurrency = 10e26; // $10 in base currency
  uint256 remainingBaseCurrencyBound = 1e26; // $1 in base currency units

  // todo: multi coll/debt

  /// coll: weth / debt: dai
  function test_liquidationCall_closeFactor_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: weth / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_closeFactor_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: weth / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_closeFactor_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: usdx / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_closeFactor_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: usdx / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_closeFactor_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: dai / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_closeFactor_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: dai / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  // close factor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_closeFactor_defaultCloseFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor(
      collateralReserveId,
      debtReserveId,
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage
    );
  }

  function test_liquidationCall_fuzz_closeFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertHealthFactor(state, spoke1);
    _assertAccounting(state, spoke1, remainingBaseCurrencyBound);
  }

  function _assertHealthFactor(
    LiquidationTestLocalParams memory state,
    ISpoke spoke
  ) internal view {
    uint256 finalHf = spoke.getHealthFactor(alice);

    console.log('hf %e cf %e', finalHf, _getCloseFactor(spoke));

    // ensure HF is above close factor
    assertGe(finalHf, _getCloseFactor(spoke), 'Health factor >= close factor');
    // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
    if (
      _convertAmountToBaseCurrency(state.debtReserve.assetId, state.debt.balanceAfter) >
      remainingBaseCurrencyBound &&
      _convertAmountToBaseCurrency(state.collateralReserve.assetId, state.supply.balanceAfter) >
      remainingBaseCurrencyBound
    ) {
      assertApproxEqRel(
        finalHf,
        _getCloseFactor(spoke),
        _approxRelFromBps(10),
        'HF matches closeFactor within 0.1%'
      );

      // 2.79304204108631032637e21
      // 2.793042041086310326368e21
    }
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    uint256 increment = WadRayMath.WAD / 1e2; // assume close factor set as increments of 100 BPS

    uint256 minTick = HEALTH_FACTOR_LIQUIDATION_THRESHOLD / increment;
    uint256 maxTick = (5 * HEALTH_FACTOR_LIQUIDATION_THRESHOLD) / increment - 1;

    // Bound in number of ticks
    uint256 tick = bound(liqConfig.closeFactor / increment, minTick, maxTick);

    // Reconstruct the actual value
    liqConfig.closeFactor = tick * increment;
    // console.log('liqConfig.closeFactor %e', liqConfig.closeFactor);
    // liqConfig.healthFactorBonusThreshold = bound(
    //   liqConfig.healthFactorBonusThreshold,
    //   1,
    //   HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    // );
    // liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    // set config to 0 so that desiredHf can be easily calculated (dependent on LB)
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorBonusThreshold = 0;

    return liqConfig;
  }

  function _execLiqCallCloseFactorTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFeePercentage
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath
        .PERCENTAGE_FACTOR
        .percentDiv(state.collateralReserve.config.collateralFactor)
        .percentMul(90_00) // add 10% buffer so that not all debt is liquidated
    );

    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e25),
      MAX_SUPPLY_AMOUNT / 1e4
    );

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );
    uint256 desiredHf = _calcMaxAchievableHf(collateralReserveId, liqBonus).percentMul(101_00); // add 1% buffer so that not all debt is liquidated

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    (uint256 hfAfterBorrow, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );

    state.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      collateralReserveId,
      hfAfterBorrow
    );

    state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.treasury.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state.liquidator.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.treasury.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    vm.assume(state.supply.balanceAfter > 0 && state.debt.balanceAfter > 0);

    // convert
    state.liquidator.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore)
    );
    state.treasury.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      _absDiff(state.treasury.balanceAfter, state.treasury.balanceBefore)
    );
    state.debt.baseChange = _convertAmountToBaseCurrency(
      state.debtReserve.assetId,
      _absDiff(state.debt.balanceBefore, state.debt.balanceAfter)
    );
    state.supply.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      _absDiff(state.supply.balanceBefore, state.supply.balanceAfter)
    );

    return state;
  }

  /// @notice Calc max achievable hf to be able to repay all debt and have remaining collateral
  /// allows close factor to be up to max uint
  /// @param healthFactor in WAD
  function _calcMaxAchievableHf(
    uint256 collateralReserveId,
    uint256 liquidationBonus
  ) internal view returns (uint256 healthFactor) {
    healthFactor = uint256(1e18)
      .percentMul(spoke1.getCollateralFactor(collateralReserveId))
      .percentMul(liquidationBonus + 1);
  }
}
