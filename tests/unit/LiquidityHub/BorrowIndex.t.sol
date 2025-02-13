pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';

contract BorrowIndexTest is BaseTest {
  using WadRayMath for uint256;

  function setUp() public override {
    deployFixtures();
    initEnvironment();
  }

  function test_spokeAddedMidWay() public {
    uint256 amount = 1000e18;
    uint256 borrowRate = 10_00;
    uint256 delay = 365 days;
    _mockInterestRate(borrowRate);

    vm.startPrank(address(spoke1));
    hub.supply(wethAssetId, amount, 0, alice);
    hub.draw(wethAssetId, amount / 2, 0, alice);
    vm.stopPrank();

    skip(delay);

    address spoke4 = _deployAndAddSpoke(wethAssetId);
    uint256 spoke4DrawAmount = amount / 2;
    vm.prank(spoke4);
    hub.draw(wethAssetId, spoke4DrawAmount, 0, bob);

    assertEq(hub.getSpoke(wethAssetId, spoke4).baseDebt, spoke4DrawAmount);
    // assertEq(hub.getSpoke(wethAssetId, spoke4).baseBorrowIndex, WadRayMath.RAY);

    uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    skip(delay);

    vm.prank(spoke4);
    hub.supply(wethAssetId, 10000, 0, alice); // trigger index update

    uint256 expectedSpoke4BaseDebt = MathUtils
      .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
      .rayMul(spoke4DrawAmount);

    assertEq(
      expectedSpoke4BaseDebt,
      hub.getSpoke(wethAssetId, spoke4).baseDebt,
      'base debt mismatch'
    );
  }

  function test_noDebtMidWay_sameSpokeAndNewSpokeDrawAgain() public {
    uint256 amount = 1000e18;
    uint256 borrowRate = 10_00;
    uint256 delay = 365 days;
    _mockInterestRate(borrowRate);

    vm.startPrank(address(spoke1));
    hub.supply(wethAssetId, amount, 0, alice);
    hub.draw(wethAssetId, amount / 2, 0, alice);
    vm.stopPrank();

    uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    skip(delay);

    uint256 spoke1ExpectedDebt = MathUtils
      .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
      .rayMul(amount / 2);
    vm.prank(address(spoke1));
    hub.restore(wethAssetId, spoke1ExpectedDebt, 0, alice);
    assertEq(hub.getSpoke(wethAssetId, address(spoke1)).baseDebt, 0);
    assertEq(hub.getAsset(wethAssetId).baseDebt, 0);

    skip(delay);

    address spoke4 = _deployAndAddSpoke(wethAssetId);
    uint256 drawAmount = amount / 2;
    vm.prank(address(spoke1));
    hub.draw(wethAssetId, drawAmount, 0, alice);
    vm.prank(spoke4);
    hub.draw(wethAssetId, drawAmount, 0, bob);

    assertEq(hub.getSpoke(wethAssetId, address(spoke1)).baseDebt, drawAmount);
    assertEq(hub.getSpoke(wethAssetId, spoke4).baseDebt, drawAmount);

    lastUpdateTimestamp = vm.getBlockTimestamp();
    skip(365 days);

    vm.prank(address(spoke1));
    hub.supply(wethAssetId, 10000, 0, alice);
    vm.prank(spoke4);
    hub.supply(wethAssetId, 10000, 0, alice);

    uint256 expectedSpokeBaseDebt = MathUtils
      .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
      .rayMul(drawAmount);

    assertEq(
      hub.getSpoke(wethAssetId, address(spoke1)).baseDebt,
      expectedSpokeBaseDebt,
      'spoke1 base debt mismatch'
    );
    assertEq(
      hub.getSpoke(wethAssetId, spoke4).baseDebt,
      expectedSpokeBaseDebt,
      'spoke4 base debt mis match'
    );
  }

  function test_noDebtMidWay_differentExistingSpokeAndNewSpokeDrawAgain() public {
    uint256 amount = 1000e18;
    uint256 borrowRate = 10_00;
    uint256 delay = 365 days;
    _mockInterestRate(borrowRate);

    vm.startPrank(address(spoke1));
    hub.supply(wethAssetId, amount, 0, alice);
    hub.draw(wethAssetId, amount / 2, 0, alice);
    vm.stopPrank();

    uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    skip(delay);

    uint256 spoke1ExpectedDebt = MathUtils
      .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
      .rayMul(amount / 2);
    vm.prank(address(spoke1));
    hub.restore(wethAssetId, spoke1ExpectedDebt, 0, alice);
    assertEq(hub.getSpoke(wethAssetId, address(spoke1)).baseDebt, 0);
    assertEq(hub.getAsset(wethAssetId).baseDebt, 0);

    skip(delay);

    address spoke4 = _deployAndAddSpoke(wethAssetId);
    uint256 drawAmount = amount / 2;
    vm.prank(address(spoke2));
    hub.draw(wethAssetId, drawAmount, 0, alice);
    vm.prank(spoke4);
    hub.draw(wethAssetId, drawAmount, 0, bob);

    assertEq(hub.getSpoke(wethAssetId, address(spoke2)).baseDebt, drawAmount);
    assertEq(hub.getSpoke(wethAssetId, spoke4).baseDebt, drawAmount);

    lastUpdateTimestamp = vm.getBlockTimestamp();
    skip(365 days);

    vm.prank(address(spoke2));
    hub.supply(wethAssetId, 10000, 0, alice);
    vm.prank(spoke4);
    hub.supply(wethAssetId, 10000, 0, alice);

    uint256 expectedSpokeBaseDebt = MathUtils
      .calculateLinearInterest(borrowRate.bpsToRay(), uint40(lastUpdateTimestamp))
      .rayMul(drawAmount);

    assertEq(
      hub.getSpoke(wethAssetId, address(spoke2)).baseDebt,
      expectedSpokeBaseDebt,
      'spoke2 base debt mismatch'
    );
    assertEq(
      hub.getSpoke(wethAssetId, spoke4).baseDebt,
      expectedSpokeBaseDebt,
      'spoke4 base debt mis match'
    );
  }

  function _deployAndAddSpoke(uint256 assetId) internal returns (address) {
    Spoke spoke = new Spoke(address(hub), address(oracle));
    hub.addSpoke(
      assetId,
      DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max}),
      address(spoke)
    );
    return address(spoke);
  }

  function _mockInterestRate(uint256 bps) internal {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(bps.bpsToRay())
    );
  }
}
