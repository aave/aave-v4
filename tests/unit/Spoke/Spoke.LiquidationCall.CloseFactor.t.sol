// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  uint256 minSupplyInBaseCurrency = 1e26; // $10

  function test_liquidationCall_closeFactor_scenario1() public {
    test_liquidationCall_fuzz_closeFactor_scenario1({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00
    });
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_fuzz_closeFactor_scenario1(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e15, 1e24); // bounds to ensure HF is below desiredHf within precision

    _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );
    _assertHealthFactor(spoke1);
  }

  function test_liquidationCall_fuzz_closeFactor_scenario1_defaultCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor_scenario1(
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage
    );
  }

  function test_liquidationCall_closeFactor_scenario2() public {
    test_liquidationCall_fuzz_closeFactor_scenario2({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_fuzz_closeFactor_scenario2(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e15, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );
    _assertHealthFactor(spoke1);
  }

  function test_liquidationCall_fuzz_closeFactor_scenario2_defaultCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor_scenario2(
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage
    );
  }

  function test_liquidationCall_closeFactor_scenario3() public {
    test_liquidationCall_fuzz_closeFactor_scenario3({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_fuzz_closeFactor_scenario3(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 10e6, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertHealthFactor(spoke1);
  }

  function test_liquidationCall_fuzz_closeFactor_scenario3_defaultCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor_scenario3(
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage
    );
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_fuzz_closeFactor_scenario4(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 10e6, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertHealthFactor(spoke1);
  }

  function test_liquidationCall_fuzz_closeFactor_scenario4_defaultCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor_scenario4(
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage
    );
  }

  function test_liquidationCall_closeFactor_scenario4() public {
    test_liquidationCall_fuzz_closeFactor_scenario4({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_fuzz_closeFactor_scenario5(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e13, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertHealthFactor(spoke1);
  }

  function test_liquidationCall_fuzz_closeFactor_scenario5_defaultCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor_scenario5(
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage
    );
  }

  function test_liquidationCall_closeFactor_scenario5() public {
    test_liquidationCall_fuzz_closeFactor_scenario5({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_fuzz_closeFactor_scenario6(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 10e18, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertHealthFactor(spoke1);
  }

  function test_liquidationCall_fuzz_closeFactor_scenario6_defaultCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor_scenario6(
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage
    );
  }

  function test_liquidationCall_closeFactor_scenario6() public {
    test_liquidationCall_fuzz_closeFactor_scenario6({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00
    });
  }

  function _assertHealthFactor(ISpoke spoke) internal view {
    uint256 finalHf = spoke.getHealthFactor(alice);
    console.log('final hf %e | closefactor %e', finalHf, _getCloseFactor(spoke));

    // assertGe(finalHf, _getCloseFactor(spoke), 'Health factor >= close factor');
    assertApproxEqRel(finalHf, _getCloseFactor(spoke), _approxRelFromBps(10), 'approx equal');
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    // assume closeFactor will be in increments of 10 BPS
    // liqConfig.closeFactor = bound(liqConfig.closeFactor, 1e3, 10 * 1e3) * 1e15;
    liqConfig.closeFactor = bound(liqConfig.closeFactor, 1e18, 10e18);
    liqConfig.healthFactorBonusThreshold = bound(
      liqConfig.healthFactorBonusThreshold,
      0.5e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

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
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, 110_00);
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);

    console.log('cxf', liqConfig.closeFactor);

    console.log('   fuzz inputs');
    console.log('   supplyAmount %e', supplyAmount);
    console.log('   closeFactor %e', liqConfig.closeFactor);
    console.log('   healthFactorBonusThreshold %e', liqConfig.healthFactorBonusThreshold);
    console.log('   liquidationBonusFactor %e', liqConfig.liquidationBonusFactor);
    console.log('   liqBonus %e', liqBonus);
    console.log('   liquidationProtocolFeePercentage %e', liquidationProtocolFeePercentage);

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );

    uint256 desiredHf = _calcMaxAchievableHf(collateralReserveId, liqBonus);
    // vm.assume(desiredHf < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

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

    console.log('hf after borrow %e | borrowed amt: %e', hfAfterBorrow, requiredDebtAmount);

    state.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      collateralReserveId,
      hfAfterBorrow
    );

    state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.treasury.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state.liquidator.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.treasury.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);

    // convert
    state.collateralBaseDiff = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.liquidator.balanceAfter -
        state.liquidator.balanceBefore +
        state.treasury.balanceAfter -
        state.treasury.balanceBefore
    );
    state.debtBaseDiff = _convertAmountToBaseCurrency(
      state.debtReserve.assetId,
      state.debt.balanceBefore - state.debt.balanceAfter
    );

    console.log(
      'after liq: debt amt remaining %e | base %e',
      spoke1.getUserTotalDebt(debtReserveId, alice),
      _convertAmountToBaseCurrency(daiAssetId, spoke1.getUserTotalDebt(debtReserveId, alice))
    );
    console.log(
      'after liq: collateral amt remaining %e | base %e',
      spoke1.getUserSuppliedAmount(collateralReserveId, alice),
      _convertAmountToBaseCurrency(
        wethAssetId,
        spoke1.getUserSuppliedAmount(collateralReserveId, alice)
      )
    );

    return state;
  }

  /// @notice Calculate the maximum achievable health factor after liquidation
  /// @param liquidationBonus in BPS
  function _calcMaxAchievableHf(
    uint256 collateralReserveId,
    uint256 liquidationBonus
  ) internal view returns (uint256 healthFactor) {
    // calc max achievable hf in order to to be able to repay all debt and have remaining collateral
    // allows close factor to be up to max uint
    healthFactor = uint256(1e18)
      .percentMul(spoke1.getCollateralFactor(collateralReserveId) + 1)
      .percentMul(liquidationBonus + 1);
  }
}
