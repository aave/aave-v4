// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubRestoreDeficitTest is LiquidityHubBase {
  function setUp() public override {
    super.setUp();

    _deployLiquidity(spoke1, wethAssetId, MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, usdxAssetId, MAX_SUPPLY_AMOUNT);

    // IERC20 asset = hub.assetsList(wethAssetId);
    vm.startPrank(address(spoke1));
    hub.assetsList(wethAssetId).approve(address(hub), type(uint256).max);
    hub.assetsList(usdxAssetId).approve(address(hub), type(uint256).max);
    vm.stopPrank();
  }

  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit() public {
    uint256 drawnAmount = 10_000e6;
    uint256 deficitAmountToRestore = drawnAmount + 1;

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));
    (uint256 baseAmount, uint256 premiumAmount) = hub.getSpokeDebt(usdxAssetId, address(spoke1));

    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);

    vm.prank(address(spoke1));
    hub.restore(usdxAssetId, baseAmount, premiumAmount, deficitAmountToRestore, address(spoke1));
  }

  // function test_restore_revertsWith_InvalidDeficitAmount_with_deficit_no_premium() public {
  //   uint256 drawnAmount = 10_000e6;

  //   // draw usdx liquidity to be restored
  //   Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));
  //   skip(365 days);

  //   (uint256 baseAmount, uint256 premiumAmount) = hub.getSpokeDebt(usdxAssetId, address(spoke1));
  //   console.log('baseAmount: %e', baseAmount);
  //   console.log('premiumAmount: %e', premiumAmount);

  //   uint256 deficitAmountToRestore = baseAmount + premiumAmount + 1;
  //   uint256 deficitBefore = hub.getAsset(usdxAssetId).deficit;
  //   uint256 supplyExchangeRateBefore = hub.convertToSuppliedAssets(
  //     usdxAssetId,
  //     WadRayMathExtended.RAY
  //   );

  //   vm.prank(address(spoke1));
  //   hub.restore(usdxAssetId, baseAmount, premiumAmount, deficitAmountToRestore, address(spoke1));
  // }

  // function test_restore_with_deficit_no_premium() public {
  //   uint256 drawnAmount = 10_000e6;

  //   // draw usdx liquidity to be restored
  //   Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));
  //   skip(365 days);

  //   (uint256 baseAmount, uint256 premiumAmount) = hub.getSpokeDebt(usdxAssetId, address(spoke1));
  //   console.log('baseAmount: %e', baseAmount);
  //   console.log('premiumAmount: %e', premiumAmount);

  //   uint256 deficitAmountToRestore = baseAmount / 2;
  //   uint256 deficitBefore = hub.getAsset(usdxAssetId).deficit;
  //   uint256 supplyExchangeRateBefore = hub.convertToSuppliedAssets(
  //     usdxAssetId,
  //     WadRayMathExtended.RAY
  //   );

  //   // Set up the spoke to have a deficit
  //   // Restore the deficit
  //   vm.prank(address(spoke1));
  //   hub.restore(usdxAssetId, baseAmount, premiumAmount, deficitAmountToRestore, address(spoke1));
  //   // Check that the spoke's deficit has been restored

  //   uint256 deficitAfter = hub.getAsset(usdxAssetId).deficit;
  //   uint256 supplyExchangeRateAfter = hub.convertToSuppliedAssets(
  //     usdxAssetId,
  //     WadRayMathExtended.RAY
  //   );

  //   // console.log('supplyExchangeRateBefore: %e', supplyExchangeRateBefore);
  //   // console.log('supplyExchangeRateAfter: %e', supplyExchangeRateAfter);

  //   assertEq(deficitAfter, deficitBefore + deficitAmountToRestore);
  // }
}
