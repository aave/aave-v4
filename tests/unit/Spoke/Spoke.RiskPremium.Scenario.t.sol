// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract SpokeRiskPremiumScenarioTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct GeneralLocalVars {
    uint256 usdxSupplyAmount;
    uint256 wethSupplyAmount;
    uint256 daiBorrowAmount;
    uint40 lastUpdateTimestamp;
    uint256 delay;
  }

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
  }

  /** Spoke1 Init Config
   * +-----------+------------+------------------+--------+----------+
   * | reserveId | collateral | liquidityPremium | price  | decimals |
   * +-----------+------------+------------------+--------+----------+
   * |         0 | weth       | 15%              | 2_000  |       18 |
   * |         1 | wbtc       | 50%              | 50_000 |        8 |
   * |         2 | dai        | 20%              | 1      |       18 |
   * |         3 | usdx       | 50%              | 1      |        6 |
   * +-----------+------------+------------------+--------+----------+
   */
  function test_riskPremiumPropagatesCorrectly_singleBorrow() public {
    GeneralLocalVars memory vars;
    vars.usdxSupplyAmount = 1500e6; // 1500 usd, 50 lp
    vars.wethSupplyAmount = 5e18; // 10_000 usd, 15 lp
    vars.daiBorrowAmount = 10_000e18; // 10_000 usd, 20 lp
    vars.delay = 365 days;

    vm.prank(bob);
    spoke1.supply(daiReserveId(spoke1), vars.daiBorrowAmount);

    vm.startPrank(alice);
    spoke1.supply(usdxReserveId(spoke1), vars.usdxSupplyAmount);
    spoke1.setUsingAsCollateral(usdxReserveId(spoke1), true);

    spoke1.supply(wethReserveId(spoke1), vars.wethSupplyAmount);
    spoke1.setUsingAsCollateral(wethReserveId(spoke1), true);

    spoke1.borrow(daiReserveId(spoke1), vars.daiBorrowAmount, alice);
    vm.stopPrank();

    uint256 usdxLiquidityPremium = spoke1.getReserve(usdxReserveId(spoke1)).config.liquidityPremium;
    uint256 wethLiquidityPremium = spoke1.getReserve(wethReserveId(spoke1)).config.liquidityPremium;
    assertLt(wethLiquidityPremium, usdxLiquidityPremium);
    // weth is enough to cover debt, both stored & calc value match
    assertEq(spoke1.getUserRiskPremium(alice), wethLiquidityPremium);
    assertEq(spoke1.getLastUsedUserRiskPremium(alice), wethLiquidityPremium);

    // spoke risk premium should match since there is only 1 debt for dai
    assertEq(spoke1.getReserveRiskPremium(daiReserveId(spoke1)), wethLiquidityPremium);
    // propagated correctly on hub, should match this spoke's reserve since it's the only
    // spoke drawing dai
    assertEq(hub.getSpokeRiskPremium(daiAssetId, address(spoke1)), wethLiquidityPremium);

    vars.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(vars.delay);

    // since only DAI is borrowed in the system, supply interest is accrued only on it
    assertEq(spoke1.getUserSuppliedAmount(usdxReserveId(spoke1), alice), vars.usdxSupplyAmount);
    assertEq(spoke1.getUserSuppliedAmount(wethReserveId(spoke1), alice), vars.wethSupplyAmount);

    uint256 accruedDaiDebt = vars.daiBorrowAmount.rayMul(
      MathUtils.calculateLinearInterest(
        hub.getBaseInterestRate(daiAssetId), // note: IR strategy has a pending fix
        vars.lastUpdateTimestamp
      ) - WadRayMath.RAY
    );
    uint256 expectedOutstandingPremium = accruedDaiDebt.percentMul(wethLiquidityPremium);

    (uint256 baseDaiDebt, uint256 outstandingDaiPremium) = spoke1.getUserDebt(
      daiReserveId(spoke1),
      alice
    );
    assertEq(baseDaiDebt, vars.daiBorrowAmount + accruedDaiDebt);
    assertEq(outstandingDaiPremium, expectedOutstandingPremium);
    vars.daiBorrowAmount += accruedDaiDebt;

    // now since debt has grown, weth supply is not enough to cover debt, hence rp changes
    uint256 remainingDaiDebt = accruedDaiDebt + outstandingDaiPremium;
    // usdx is enough to cover remaining debt
    assertLt(
      _getValueInBaseCurrency(daiAssetId, remainingDaiDebt),
      _getValueInBaseCurrency(usdxAssetId, vars.usdxSupplyAmount)
    );

    uint256 newLiquidityPremium = (_getValueInBaseCurrency(wethAssetId, vars.wethSupplyAmount) *
      wethLiquidityPremium +
      _getValueInBaseCurrency(daiAssetId, remainingDaiDebt) *
      usdxLiquidityPremium) /
      (_getValueInBaseCurrency(wethAssetId, vars.wethSupplyAmount) +
        _getValueInBaseCurrency(daiAssetId, remainingDaiDebt));

    assertEq(spoke1.getUserRiskPremium(alice), newLiquidityPremium);
    // last stored remains the same
    assertEq(spoke1.getLastUsedUserRiskPremium(alice), wethLiquidityPremium);

    // we supply more usdx which should trigger stored value update for risk premium, *and accrue* dai debt
    // (this will be checked implicitly through having correct outstanding premium accrual after delay)
    vm.prank(alice);
    spoke1.supply(usdxReserveId(spoke1), 500e6);

    assertEq(spoke1.getLastUsedUserRiskPremium(alice), newLiquidityPremium);
    assertEq(spoke1.getUserRiskPremium(alice), newLiquidityPremium);
    // spoke's risk premium should still match since we only have alice's debt in system
    assertEq(spoke1.getReserveRiskPremium(daiReserveId(spoke1)), newLiquidityPremium);
    assertEq(hub.getSpokeRiskPremium(daiAssetId, address(spoke1)), newLiquidityPremium);

    vars.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(vars.delay);

    // now we supply more weth such that new total debt from now on is covered by weth
    vm.prank(alice);
    spoke1.supply(wethReserveId(spoke1), vars.wethSupplyAmount);

    accruedDaiDebt = vars.daiBorrowAmount.rayMul(
      MathUtils.calculateLinearInterest(
        hub.getBaseInterestRate(daiAssetId), // note: IR strategy has a pending fix
        vars.lastUpdateTimestamp
      ) - WadRayMath.RAY
    );
    expectedOutstandingPremium += accruedDaiDebt.percentMul(newLiquidityPremium);

    (baseDaiDebt, outstandingDaiPremium) = spoke1.getUserDebt(daiReserveId(spoke1), alice);
    assertEq(baseDaiDebt, vars.daiBorrowAmount + accruedDaiDebt);
    assertEq(outstandingDaiPremium, expectedOutstandingPremium);

    vm.prank(alice);
    spoke1.repay(daiReserveId(spoke1), baseDaiDebt + outstandingDaiPremium);

    (baseDaiDebt, outstandingDaiPremium) = spoke1.getUserDebt(daiReserveId(spoke1), alice);
    assertEq(baseDaiDebt, 0);
    assertEq(outstandingDaiPremium, 0);
    (baseDaiDebt, outstandingDaiPremium) = spoke1.getReserveDebt(daiReserveId(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(outstandingDaiPremium, 0);
    (baseDaiDebt, outstandingDaiPremium) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(outstandingDaiPremium, 0);

    assertEq(spoke1.getUserRiskPremium(alice), 0);
    assertEq(spoke1.getLastUsedUserRiskPremium(alice), 0);
    assertEq(spoke1.getReserveRiskPremium(daiReserveId(spoke1)), 0);
    assertEq(hub.getSpokeRiskPremium(daiAssetId, address(spoke1)), 0);
  }

  function _getValueInBaseCurrency(
    uint256 assetId,
    uint256 amount
  ) internal view returns (uint256) {
    return
      (amount * oracle.getAssetPrice(assetId)).wadify() /
      10 ** hub.getAsset(assetId).config.decimals;
  }
}
