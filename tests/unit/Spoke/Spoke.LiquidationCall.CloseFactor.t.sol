// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  function testUnit() public {
    // test_liquidationCall_fuzz_closeFactor1({
    //   liqConfig: DataTypes.LiquidationConfig({
    //     closeFactor: 12e18,
    //     liquidationBonusFactor: 0,
    //     healthFactorBonusThreshold: 0
    //   }),
    //   liqBonus: 105_00,
    //   supplyAmount: 1.5e18,
    //   liquidationProtocolFeePercentage: 0
    // });

    // test_liquidationCall_fuzz_closeFactor1({
    //   liqConfig: DataTypes.LiquidationConfig({
    //     closeFactor: 9.783398447710474924e18,
    //     liquidationBonusFactor: 4.945e3,
    //     healthFactorBonusThreshold: 5.00000000000000003e17
    //   }),
    //   liqBonus: 1e4,
    //   supplyAmount: 1.1276892461193349e16,
    //   liquidationProtocolFeePercentage: 0
    // });

    test_liquidationCall_fuzz_closeFactor_scenario1_defaultCloseFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 9.783398447710474924e18,
        liquidationBonusFactor: 4.945e3,
        healthFactorBonusThreshold: 5.00000000000000003e17
      }),
      liqBonus: 1e4,
      supplyAmount: 1.1276892461193349e16,
      liquidationProtocolFeePercentage: 0
    });
  }

  function test_liquidationCall_fuzz_closeFactor_scenario1(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e8, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    console.log(
      'debt amt remaining %e | base %e',
      spoke1.getUserTotalDebt(debtReserveId, alice),
      _convertAmountToBaseCurrency(daiAssetId, spoke1.getUserTotalDebt(debtReserveId, alice))
    );
    console.log(
      'collateral amt remaining %e | base %e',
      spoke1.getUserSuppliedAmount(collateralReserveId, alice),
      _convertAmountToBaseCurrency(
        wethAssetId,
        spoke1.getUserSuppliedAmount(collateralReserveId, alice)
      )
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

  function _assertHealthFactor(ISpoke spoke) internal view {
    uint256 finalHf = spoke.getHealthFactor(alice);
    console.log('final hf %e | closefactor %e', finalHf, _getCloseFactor(spoke));

    assertGe(finalHf, _getCloseFactor(spoke), 'Health factor >= close factor');
    assertApproxEqRel(finalHf, _getCloseFactor(spoke), _approxRelFromBps(10), 'approx equal');
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      20e18
    );
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
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);

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

    uint256 desiredHf = _calcMaxAchievableHf(debtReserveId, collateralReserveId, liqBonus);
    vm.assume(desiredHf < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

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

    console.log('hf after borrow %e | debt: %e', hfAfterBorrow, requiredDebtAmount);

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

    return state;
  }

  /// @notice Calculate the maximum achievable health factor after liquidation
  function _calcMaxAchievableHf(
    uint256 debtReserveId,
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

// 1.6429736644435e13
