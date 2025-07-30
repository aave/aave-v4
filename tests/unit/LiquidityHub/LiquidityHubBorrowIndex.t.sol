pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

// todo: refactor to use getters
contract LiquidityHubBorrowIndex is Base {
  using WadRayMath for uint256;
  uint256 internal amount = 1000e18;
  uint256 internal borrowRate = 10_00;
  uint256 internal delay = 365 days;

  function setUp() public override {
    deployFixtures();
    initEnvironment();
    _mockInterestRateBps(borrowRate);
  }

  function test_spokeAddedDuringZeroDebtPeriod() public {
    vm.skip(true, 'pending refactor');

    //     vm.startPrank(address(spoke1));
    //     hub.supply(wethAssetId, amount, 0, alice);
    //     hub.draw(wethAssetId, amount / 2, 0, alice);
    //     vm.stopPrank();

    //     skip(delay);

    //     address spoke4 = _deployAndAddSpoke(wethAssetId);
    //     uint256 spoke4DrawAmount = amount / 2;
    //     vm.prank(spoke4);
    //     hub.draw(wethAssetId, spoke4DrawAmount, 0, bob);

    //     assertEq(hub.getSpoke(wethAssetId, spoke4).baseDebt, spoke4DrawAmount);
    //     // assertEq(hub.getSpoke(wethAssetId, spoke4).baseBorrowIndex, WadRayMath.RAY);

    //     uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    //     skip(delay);

    //     vm.prank(spoke4);
    //     hub.supply(wethAssetId, 10000, 0, alice); // trigger index update

    //     uint256 expectedSpoke4BaseDebt = MathUtils
    //       .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
    //       .rayMul(spoke4DrawAmount);

    //     assertEq(
    //       expectedSpoke4BaseDebt,
    //       hub.getSpoke(wethAssetId, spoke4).baseDebt,
    //       'base debt mismatch'
    //     );
  }

  function test_noDebtMidWay_sameAndNewSpokeDrawAgain() public {
    vm.skip(true, 'pending refactor');

    //     vm.startPrank(address(spoke1));
    //     hub.supply(wethAssetId, amount, 0, alice);
    //     hub.draw(wethAssetId, amount / 2, 0, alice);
    //     vm.stopPrank();

    //     uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    //     skip(delay);

    //     uint256 spoke1ExpectedDebt = MathUtils
    //       .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
    //       .rayMul(amount / 2);
    //     vm.prank(address(spoke1));
    //     hub.restore(wethAssetId, spoke1ExpectedDebt, 0, alice);
    //     assertEq(hub.getSpoke(wethAssetId, address(spoke1)).baseDebt, 0);
    //     assertEq(hub.getAsset(wethAssetId).baseDebt, 0);

    //     skip(delay);

    //     address spoke4 = _deployAndAddSpoke(wethAssetId);
    //     uint256 drawAmount = amount / 2;
    //     vm.prank(address(spoke1));
    //     hub.draw(wethAssetId, drawAmount, 0, alice);
    //     vm.prank(spoke4);
    //     hub.draw(wethAssetId, drawAmount, 0, bob);

    //     assertEq(hub.getSpoke(wethAssetId, address(spoke1)).baseDebt, drawAmount);
    //     assertEq(hub.getSpoke(wethAssetId, spoke4).baseDebt, drawAmount);

    //     lastUpdateTimestamp = vm.getBlockTimestamp();
    //     skip(365 days);

    //     vm.prank(address(spoke1));
    //     hub.supply(wethAssetId, 10000, 0, alice);
    //     vm.prank(spoke4);
    //     hub.supply(wethAssetId, 10000, 0, alice);

    //     uint256 expectedSpokeBaseDebt = MathUtils
    //       .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
    //       .rayMul(drawAmount);

    //     assertEq(
    //       hub.getSpoke(wethAssetId, address(spoke1)).baseDebt,
    //       expectedSpokeBaseDebt,
    //       'existing spoke base debt mismatch'
    //     );
    //     assertEq(
    //       hub.getSpoke(wethAssetId, spoke4).baseDebt,
    //       expectedSpokeBaseDebt,
    //       'new spoke base debt mismatch'
    //     );
  }

  function test_noDebtPeriod_suppliersDoNotEarn() public {
    vm.skip(true, 'pending refactor');

    //     vm.startPrank(address(spoke1));
    //     hub.supply(wethAssetId, amount, 0, alice);
    //     hub.draw(wethAssetId, amount / 2, 0, alice);
    //     vm.stopPrank();

    //     uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    //     skip(delay);

    //     uint256 spoke1ExpectedDebt = MathUtils
    //       .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
    //       .rayMul(amount / 2);
    //     vm.prank(address(spoke1));
    //     hub.restore(wethAssetId, spoke1ExpectedDebt, 0, alice);
    //     assertEq(hub.getSpoke(wethAssetId, address(spoke1)).baseDebt, 0);
    //     assertEq(hub.getAsset(wethAssetId).baseDebt, 0);

    //     skip(delay / 2);
    //     // no debt period
    //     vm.prank(address(spoke2));
    //     uint256 sharesMinted = hub.supply(wethAssetId, amount, 0, alice);
    //     assertApproxEqAbs(amount, hub.convertToAssets(wethAssetId, sharesMinted), 1);
    //     assertApproxEqAbs(hub.convertToShares(wethAssetId, amount), sharesMinted, 1);
    //     assertEq(hub.getSpoke(wethAssetId, address(spoke2)).suppliedShares, sharesMinted);

    //     skip(delay / 2); // since system has no debt, no interest should accrue

    //     assertApproxEqAbs(amount, hub.convertToAssets(wethAssetId, sharesMinted), 1);

    //     vm.expectRevert(
    //       abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, amount - 1)
    //     ); // should not revert
    //     vm.prank(address(spoke2));
    //     hub.withdraw(wethAssetId, amount, 0, alice);

    //     vm.prank(address(spoke2));
    //     hub.withdraw(wethAssetId, amount - 1, 0, alice);

    //     // no dust remains
    //     assertEq(hub.getSpoke(wethAssetId, address(spoke2)).suppliedShares, 0);

    //     // after zero amount check, cannot withdraw one 1 wei of shares in contract
    //     vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, 0));
    //     vm.prank(address(spoke2));
    //     hub.withdraw(wethAssetId, 1, 0, alice);

    //     // no supplied shares or amounts remain
    //     assertEq(hub.getSpokeSuppliedShares(wethAssetId, address(spoke2)), 0);
    //     assertEq(hub.getSpokeSuppliedAmount(wethAssetId, address(spoke2)), 0);
  }

  function test_withdrawRightAfterSupplying() public {
    vm.skip(true, 'pending refactor');

    //     vm.prank(address(spoke1));
    //     uint256 sharesMinted = hub.supply(wethAssetId, amount, 0, alice);
    //     assertApproxEqAbs(amount, hub.convertToAssets(wethAssetId, sharesMinted), 1);

    //     vm.prank(address(spoke2));
    //     sharesMinted = hub.supply(wethAssetId, amount, 0, alice);
    //     assertApproxEqAbs(amount, hub.convertToAssets(wethAssetId, sharesMinted), 1);

    //     vm.prank(address(spoke2));
    //     hub.withdraw(wethAssetId, amount, 0, alice);

    //     assertEq(hub.getSpoke(wethAssetId, address(spoke2)).suppliedShares, 0);
  }

  function test_noDebtPeriodMiday_ExistingAndNewSpokeDrawAgain() public {
    vm.skip(true, 'pending refactor');

    //     vm.startPrank(address(spoke1));
    //     hub.supply(wethAssetId, amount, 0, alice);
    //     hub.draw(wethAssetId, amount / 2, 0, alice);
    //     vm.stopPrank();

    //     uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    //     skip(delay);

    //     uint256 spoke1ExpectedDebt = MathUtils
    //       .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
    //       .rayMul(amount / 2);
    //     vm.prank(address(spoke1));
    //     hub.restore(wethAssetId, spoke1ExpectedDebt, 0, alice);
    //     assertEq(hub.getSpoke(wethAssetId, address(spoke1)).baseDebt, 0);
    //     assertEq(hub.getAsset(wethAssetId).baseDebt, 0);

    //     skip(delay);

    //     address spoke4 = _deployAndAddSpoke(wethAssetId);
    //     uint256 drawAmount = amount / 2;
    //     vm.prank(address(spoke2));
    //     hub.draw(wethAssetId, drawAmount, 0, alice);
    //     vm.prank(spoke4);
    //     hub.draw(wethAssetId, drawAmount, 0, bob);

    //     assertEq(hub.getSpoke(wethAssetId, address(spoke2)).baseDebt, drawAmount);
    //     assertEq(hub.getSpoke(wethAssetId, spoke4).baseDebt, drawAmount);

    //     lastUpdateTimestamp = vm.getBlockTimestamp();
    //     skip(365 days);

    //     vm.prank(address(spoke2));
    //     hub.supply(wethAssetId, 10000, 0, alice);
    //     vm.prank(spoke4);
    //     hub.supply(wethAssetId, 10000, 0, alice);

    //     uint256 expectedSpokeBaseDebt = MathUtils
    //       .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
    //       .rayMul(drawAmount);

    //     assertEq(
    //       hub.getSpoke(wethAssetId, address(spoke2)).baseDebt,
    //       expectedSpokeBaseDebt,
    //       'existing spoke base debt mismatch'
    //     );
    //     assertEq(
    //       hub.getSpoke(wethAssetId, spoke4).baseDebt,
    //       expectedSpokeBaseDebt,
    //       'new spoke base debt mismatch'
    //     );
  }

  function _deployAndAddSpoke(uint256 assetId) internal returns (address) {
    Spoke spoke = new Spoke(address(accessManager));
    IAaveOracle oracle = new AaveOracle(address(spoke), 8, 'Spoke (USD)');
    vm.prank(HUB_ADMIN);
    hub.addSpoke(
      assetId,
      address(spoke),
      DataTypes.SpokeConfig({
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max
      })
    );
    return address(spoke);
  }
}
