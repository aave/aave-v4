// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubDrawTest is LiquidityHubBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_draw_same_block() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke1, alice supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2, bob supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    vm.expectEmit(address(hub));
    emit Draw(daiAssetId, address(spoke1), alice, drawAmount);
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, riskPremiumRad: 0, to: alice});

    Asset memory wethData = hub.getAsset(wethAssetId);
    Asset memory daiData = hub.getAsset(daiAssetId);

    SpokeData memory spoke1WethData = hub.getSpoke(wethAssetId, address(spoke1));
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(daiAssetId, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(wethAssetId), wethAmount, 'hub weth total assets post-draw');
    assertEq(hub.getTotalAssets(daiAssetId), daiAmount, 'hub dai total assets post-draw');
    // weth
    assertEq(
      wethData.suppliedShares,
      hub.convertToSharesUp(wethAssetId, wethAmount),
      'hub weth suppliedShares post-draw'
    );
    assertEq(wethData.baseDebt, 0, 'hub weth baseDebt post-draw');
    assertEq(wethData.outstandingPremium, 0, 'hub weth outstandingPremium post-draw');
    assertEq(wethData.baseBorrowIndex, WadRayMath.RAY, 'hub weth baseBorrowIndex post-draw');
    assertEq(wethData.riskPremiumRad, 0, 'hub weth riskPremiumRad post-draw');
    assertEq(
      wethData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'hub weth lastUpdateTimestamp post-draw'
    );
    // dai
    assertEq(
      daiData.suppliedShares,
      hub.convertToSharesUp(daiAssetId, daiAmount),
      'hub dai suppliedShares post-draw'
    );
    assertEq(daiData.baseDebt, drawAmount, 'hub dai baseDebt post-draw');
    assertEq(daiData.outstandingPremium, 0, 'hub dai outstandingPremium post-draw');
    assertEq(daiData.baseBorrowIndex, WadRayMath.RAY, 'hub dai baseBorrowIndex post-draw');
    assertEq(daiData.riskPremiumRad, 0, 'hub dai riskPremiumRad post-draw');
    assertEq(
      daiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'hub dai lastUpdateTimestamp post-draw'
    );
    // spoke1 weth
    assertEq(
      spoke1WethData.suppliedShares,
      wethData.suppliedShares,
      'hub spoke1 suppliedShares post-draw'
    );
    assertEq(spoke1WethData.baseDebt, wethData.baseDebt, 'hub spoke1 baseDebt post-draw');
    assertEq(
      spoke1WethData.outstandingPremium,
      wethData.outstandingPremium,
      'hub spoke1 outstandingPremium post-draw'
    );
    assertEq(
      spoke1WethData.baseBorrowIndex,
      wethData.baseBorrowIndex,
      'hub spoke1 baseBorrowIndex post-draw'
    );
    assertEq(spoke1WethData.riskPremiumRad, 0, 'hub spoke1 riskPremiumRad post-draw');
    assertEq(
      spoke1WethData.lastUpdateTimestamp,
      wethData.lastUpdateTimestamp,
      'hub spoke1 lastUpdateTimestamp post-draw'
    );
    // spoke1 dai
    assertEq(spoke1DaiData.suppliedShares, 0, 'hub spoke1 suppliedShares post-draw');
    assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt post-draw');
    assertEq(
      spoke1DaiData.outstandingPremium,
      daiData.outstandingPremium,
      'hub spoke1 outstandingPremium post-draw'
    );
    assertEq(
      spoke1DaiData.baseBorrowIndex,
      daiData.baseBorrowIndex,
      'hub spoke1 baseBorrowIndex post-draw'
    );
    assertEq(spoke1DaiData.riskPremiumRad, 0, 'hub spoke1 riskPremiumRad post-draw');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'hub spoke1 lastUpdateTimestamp post-draw'
    );
    // spoke2
    assertEq(
      spoke2Data.suppliedShares,
      daiData.suppliedShares,
      'hub spoke2 suppliedShares post-draw'
    );
    assertEq(spoke2Data.baseDebt, 0, 'hub spoke2 baseDebt post-draw');
    assertEq(
      spoke2Data.outstandingPremium,
      daiData.outstandingPremium,
      'hub spoke2 outstandingPremium post-draw'
    );
    assertEq(
      spoke2Data.baseBorrowIndex,
      daiData.baseBorrowIndex,
      'hub spoke2 baseBorrowIndex post-draw'
    );
    assertEq(spoke2Data.riskPremiumRad, 0, 'hub spoke2 riskPremiumRad post-draw');
    assertEq(
      spoke2Data.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'hub spoke2 lastUpdateTimestamp post-draw'
    );
    // dai balance
    assertEq(
      tokenList.dai.balanceOf(alice),
      drawAmount + MAX_SUPPLY_AMOUNT,
      'alice dai final balance'
    );
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai final balance');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      daiAmount - drawAmount,
      'hub dai final balance'
    );
    // weth balance
    assertEq(
      tokenList.weth.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - wethAmount,
      'alice weth final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), MAX_SUPPLY_AMOUNT, 'bob weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke1)), 0, 'spoke1 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'spoke2 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(hub)), wethAmount, 'hub weth final balance');
  }

  function test_draw_fuzz_amounts_same_block(uint256 daiAmount) public {
    daiAmount = bound(daiAmount, 10, MAX_SUPPLY_AMOUNT);
    uint256 wethAmount = daiAmount / 10;
    uint256 drawAmount = daiAmount / 2;

    // spoke1, alice supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2, bob supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    vm.expectEmit(address(hub));
    emit Draw(daiAssetId, address(spoke1), alice, drawAmount);
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, amount: drawAmount, riskPremiumRad: 0, to: alice});

    Asset memory wethData = hub.getAsset(wethAssetId);
    Asset memory daiData = hub.getAsset(daiAssetId);

    SpokeData memory spoke1WethData = hub.getSpoke(wethAssetId, address(spoke1));
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(daiAssetId, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(wethAssetId), wethAmount, 'hub weth total assets post-draw');
    assertEq(hub.getTotalAssets(daiAssetId), daiAmount, 'hub dai total assets post-draw');
    // weth
    assertEq(
      wethData.suppliedShares,
      hub.convertToSharesUp(wethAssetId, wethAmount),
      'hub weth suppliedShares post-draw'
    );
    assertEq(wethData.baseDebt, 0, 'hub weth baseDebt post-draw');
    assertEq(wethData.outstandingPremium, 0, 'hub weth outstandingPremium post-draw');
    assertEq(wethData.baseBorrowIndex, WadRayMath.RAY, 'hub weth baseBorrowIndex post-draw');
    assertEq(wethData.riskPremiumRad, 0, 'hub weth riskPremiumRad post-draw');
    assertEq(
      wethData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'hub weth lastUpdateTimestamp post-draw'
    );
    // dai
    assertEq(
      daiData.suppliedShares,
      hub.convertToSharesUp(daiAssetId, daiAmount),
      'hub dai suppliedShares post-draw'
    );
    assertEq(daiData.baseDebt, drawAmount, 'hub dai baseDebt post-draw');
    assertEq(daiData.outstandingPremium, 0, 'hub dai outstandingPremium post-draw');
    assertEq(daiData.baseBorrowIndex, WadRayMath.RAY, 'hub dai baseBorrowIndex post-draw');
    assertEq(daiData.riskPremiumRad, 0, 'hub dai riskPremiumRad post-draw');
    assertEq(
      daiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'hub dai lastUpdateTimestamp post-draw'
    );
    // spoke1 weth
    assertEq(
      spoke1WethData.suppliedShares,
      wethData.suppliedShares,
      'hub spoke1 suppliedShares post-draw'
    );
    assertEq(spoke1WethData.baseDebt, wethData.baseDebt, 'hub spoke1 baseDebt post-draw');
    assertEq(
      spoke1WethData.outstandingPremium,
      wethData.outstandingPremium,
      'hub spoke1 outstandingPremium post-draw'
    );
    assertEq(
      spoke1WethData.baseBorrowIndex,
      wethData.baseBorrowIndex,
      'hub spoke1 baseBorrowIndex post-draw'
    );
    assertEq(spoke1WethData.riskPremiumRad, 0, 'hub spoke1 riskPremiumRad post-draw');
    assertEq(
      spoke1WethData.lastUpdateTimestamp,
      wethData.lastUpdateTimestamp,
      'hub spoke1 lastUpdateTimestamp post-draw'
    );
    // spoke1 dai
    assertEq(spoke1DaiData.suppliedShares, 0, 'hub spoke1 suppliedShares post-draw');
    assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt post-draw');
    assertEq(
      spoke1DaiData.outstandingPremium,
      daiData.outstandingPremium,
      'hub spoke1 outstandingPremium post-draw'
    );
    assertEq(
      spoke1DaiData.baseBorrowIndex,
      daiData.baseBorrowIndex,
      'hub spoke1 baseBorrowIndex post-draw'
    );
    assertEq(spoke1DaiData.riskPremiumRad, 0, 'hub spoke1 riskPremiumRad post-draw');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'hub spoke1 lastUpdateTimestamp post-draw'
    );
    // spoke2
    assertEq(
      spoke2Data.suppliedShares,
      daiData.suppliedShares,
      'hub spoke2 suppliedShares post-draw'
    );
    assertEq(spoke2Data.baseDebt, 0, 'hub spoke2 baseDebt post-draw');
    assertEq(
      spoke2Data.outstandingPremium,
      daiData.outstandingPremium,
      'hub spoke2 outstandingPremium post-draw'
    );
    assertEq(
      spoke2Data.baseBorrowIndex,
      daiData.baseBorrowIndex,
      'hub spoke2 baseBorrowIndex post-draw'
    );
    assertEq(spoke2Data.riskPremiumRad, 0, 'hub spoke2 riskPremiumRad post-draw');
    assertEq(
      spoke2Data.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'hub spoke2 lastUpdateTimestamp post-draw'
    );
    // dai balance
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT + drawAmount,
      'alice dai final balance'
    );
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai final balance');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      daiAmount - drawAmount,
      'hub dai final balance'
    );
    // weth balance
    assertEq(
      tokenList.weth.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - wethAmount,
      'alice weth final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), MAX_SUPPLY_AMOUNT, 'bob weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke1)), 0, 'spoke1 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'spoke2 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(hub)), wethAmount, 'hub weth final balance');
  }

  function test_draw_revertsWith_asset_not_active() public {
    uint256 drawAmount = 1;
    _updateActive(daiAssetId, false);
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.draw({assetId: daiAssetId, amount: drawAmount, riskPremiumRad: 0, to: address(spoke1)});
  }

  function test_draw_revertsWith_not_available_liquidity() public {
    uint256 drawAmount = 1;
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    hub.draw({assetId: daiAssetId, amount: drawAmount, riskPremiumRad: 0, to: address(spoke1)});
  }

  function test_draw_revertsWith_draw_cap_exceeded_due_to_interest() public {
    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = drawCap;
    uint256 rate = uint256(10_00).bpsToRay();

    _updateDrawCap(daiAssetId, address(spoke1), drawCap);

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: 0,
      rate: rate
    });
    skip(365 days);

    // restore to provide liquidity
    vm.startPrank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: 1, riskPremiumRad: 0, repayer: alice});

    vm.expectRevert(TestErrors.DRAW_CAP_EXCEEDED);
    hub.draw({assetId: daiAssetId, amount: 1, riskPremiumRad: 0, to: bob});
    vm.stopPrank();
  }

  function test_draw_revertsWith_draw_cap_exceeded() public {
    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap + 1;

    _updateDrawCap(daiAssetId, address(spoke1), drawCap);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.DRAW_CAP_EXCEEDED);
    hub.draw({assetId: daiAssetId, amount: drawAmount, riskPremiumRad: 0, to: address(spoke1)});
  }
}
