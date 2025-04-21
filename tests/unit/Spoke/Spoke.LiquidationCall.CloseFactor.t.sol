// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  function testUnit() public {
    test_liquidationCall_closeFactor1(
      DataTypes.LiquidationConfig({
        closeFactor: 12e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      })
    );
  }

  function test_liquidationCall_closeFactor1(
    DataTypes.LiquidationConfig memory liqConfig // DataTypes.LiquidationConfig memory liqConfig,
    // uint256 liqBonus,
  ) public // uint256 supplyAmount,
  // uint256 desiredHf,
  // uint256 liquidationProtocolFeePercentage
  {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    // DataTypes.LiquidationConfig memory liqConfig = DataTypes.LiquidationConfig({
    //   closeFactor: 12e18, // todo: vary in fuzz test
    //   liquidationBonusFactor: 0,
    //   healthFactorBonusThreshold: 0
    // });
    uint256 liquidationProtocolFeePercentage = 0;
    uint256 liqBonus = 105_00;
    uint256 supplyAmount = 1.5e18; // vary in fuzz test
    uint256 desiredHf = _calcMaxAchievableHf(debtReserveId, collateralReserveId, liqBonus);

    // supplyAmount = bound(supplyAmount, 1e11, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    console.log('debt remaining %e', spoke1.getUserTotalDebt(debtReserveId, alice));
    console.log(
      'collateral remaining %e',
      spoke1.getUserSuppliedAmount(collateralReserveId, alice)
    );

    _assertHealthFactor(liqConfig);
  }

  function _assertHealthFactor(DataTypes.LiquidationConfig memory liqConfig) internal view {
    uint256 finalHf = spoke1.getHealthFactor(alice);
    console.log('final hf %e', finalHf);

    assertGe(finalHf, liqConfig.closeFactor, 'Health factor >= close factor');
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      10e18
    );
    liqConfig.healthFactorBonusThreshold = bound(
      liqConfig.healthFactorBonusThreshold,
      0.5e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    console.log('close factor %e', liqConfig.closeFactor);

    return liqConfig;
  }

  function _execLiqCallCloseFactorTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFeePercentage
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );

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

    console.log('hf after borrow %e', hfAfterBorrow);

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
