// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract GiverPositionManagerTest is SpokeBase {
  GiverPositionManager public positionManager;
  TestReturnValues public returnValues;

  function setUp() public virtual override {
    super.setUp();

    positionManager = new GiverPositionManager(address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function test_supplyOnBehalfOf() public {
    test_supplyOnBehalfOf_fuzz(100e18);
  }

  function test_supplyOnBehalfOf_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_DAI);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), amount);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));
    uint256 userSuppliedAmountBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);
    uint256 callerSuppliedAmountBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      hub1.previewAddByAssets(daiAssetId, amount),
      amount
    );
    vm.expectEmit(address(positionManager));
    emit IGiverPositionManager.SupplyOnBehalfOf(
      address(spoke1),
      bob,
      alice,
      _daiReserveId(spoke1),
      hub1.previewAddByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.supplyOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      amount,
      alice
    );

    assertEq(returnValues.amount, amount);
    assertEq(returnValues.shares, hub1.previewAddByAssets(daiAssetId, amount));

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore - amount);
    assertEq(
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice),
      userSuppliedAmountBefore + amount
    );
    assertEq(spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob), callerSuppliedAmountBefore);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore + amount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
  }

  function test_supplyOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    uint256 reserveId = _randomReserveId(spoke2);

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.supplyOnBehalfOf(address(spoke2), reserveId, 100e18, alice);
  }

  function test_supplyOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke1);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.supplyOnBehalfOf(address(spoke1), reserveId, 100e18, alice);
  }

  function test_repayOnBehalfOf() public {
    test_repayOnBehalfOf_fuzz(50e18);
  }

  function test_repayOnBehalfOf_fuzz(uint256 repayAmount) public {
    uint256 borrowAmount = 100e18;
    repayAmount = bound(repayAmount, 1, borrowAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, 150e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), repayAmount);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );
    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      daiAssetId
    );

    {
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        alice,
        _daiReserveId(spoke1),
        repayAmount
      );

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        address(positionManager),
        alice,
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        repayAmount,
        expectedPremiumDelta
      );
    }
    vm.expectEmit(address(positionManager));
    emit IGiverPositionManager.RepayOnBehalfOf(
      address(spoke1),
      bob,
      alice,
      _daiReserveId(spoke1),
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      repayAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.repayOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      repayAmount,
      alice
    );

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);

    assertEq(returnValues.amount, repayAmount);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount - repayAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore + repayAmount);
    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore - repayAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
  }

  function test_repayOnBehalfOf_fuzz_withInterest(uint256 repayAmount, uint256 elapsedTime) public {
    uint256 borrowAmount = 100e18;
    repayAmount = bound(repayAmount, borrowAmount, borrowAmount * 10);
    elapsedTime = bound(elapsedTime, 100 days, 400 days);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, 150e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);

    skip(elapsedTime);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), repayAmount);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      daiAssetId
    );

    {
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        alice,
        _daiReserveId(spoke1),
        repayAmount
      );
      uint256 repaidAmount = _min(userDrawnDebt + userPremiumDebt, repayAmount);
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        address(positionManager),
        alice,
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        repaidAmount,
        expectedPremiumDelta
      );
      vm.expectEmit(address(positionManager));
      emit IGiverPositionManager.RepayOnBehalfOf(
        address(spoke1),
        bob,
        alice,
        _daiReserveId(spoke1),
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        repaidAmount
      );
      vm.prank(bob);
      (returnValues.shares, returnValues.amount) = positionManager.repayOnBehalfOf(
        address(spoke1),
        _daiReserveId(spoke1),
        repayAmount,
        alice
      );

      assertApproxEqAbs(returnValues.amount, baseRestored + premiumRestored, 1);
      assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));
    }

    (uint256 newUserDrawnDebt, uint256 newUserPremiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );

    assertApproxEqAbs(
      newUserDrawnDebt + newUserPremiumDebt,
      userDrawnDebt + userPremiumDebt - (baseRestored + premiumRestored),
      2
    );
    assertApproxEqAbs(
      tokenList.dai.balanceOf(address(hub1)),
      hubBalanceBefore + (baseRestored + premiumRestored),
      2
    );
    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertApproxEqAbs(
      tokenList.dai.balanceOf(bob),
      callerBalanceBefore - (baseRestored + premiumRestored),
      1
    );
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
  }

  function test_repayOnBehalfOf_maxRepay() public {
    uint256 aliceSupplyAmount = 1000e18;
    uint256 bobSupplyAmount = 150e18;
    uint256 borrowAmount = 100e18;
    uint256 repayAmount = 150e18;

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);

    skip(322 days);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), repayAmount);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      daiAssetId
    );
    uint256 totalRepaid = baseRestored + premiumRestored;
    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      alice,
      _daiReserveId(spoke1),
      repayAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      totalRepaid,
      expectedPremiumDelta
    );
    vm.expectEmit(address(positionManager));
    emit IGiverPositionManager.RepayOnBehalfOf(
      address(spoke1),
      bob,
      alice,
      _daiReserveId(spoke1),
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      totalRepaid
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.repayOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      repayAmount,
      alice
    );

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);

    assertEq(returnValues.amount, baseRestored + premiumRestored);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(userDrawnDebt + userPremiumDebt, 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore + totalRepaid);
    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore - totalRepaid);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
  }

  function test_repayOnBehalfOf_maxRepay_revertsWith_InvalidRepayAmount() public {
    uint256 aliceSupplyAmount = 1000e18;
    uint256 bobSupplyAmount = 150e18;
    uint256 borrowAmount = 100e18;

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), UINT256_MAX);

    vm.expectRevert(IGiverPositionManager.RepayOnBehalfMaxUintNotAllowed.selector);
    vm.prank(bob);
    positionManager.repayOnBehalfOf(address(spoke1), _daiReserveId(spoke1), UINT256_MAX, alice);
  }

  function test_repayOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke1);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.repayOnBehalfOf(address(spoke1), reserveId, 100e18, alice);
  }

  function test_repayOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    uint256 reserveId = _randomReserveId(spoke2);

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.repayOnBehalfOf(address(spoke2), reserveId, 100e18, alice);
  }

  function test_multicall() public {
    uint256 amount = 100e18;

    vm.prank(carol);
    spoke1.setUserPositionManager(address(positionManager), true);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), UINT256_MAX);

    uint256 aliceSuppliedAmountBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);
    uint256 carolSuppliedAmountBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), carol);

    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature(
      'supplyOnBehalfOf(address,uint256,uint256,address)',
      address(spoke1),
      _daiReserveId(spoke1),
      amount,
      alice
    );
    calls[1] = abi.encodeWithSignature(
      'supplyOnBehalfOf(address,uint256,uint256,address)',
      address(spoke1),
      _daiReserveId(spoke1),
      amount,
      carol
    );

    vm.prank(bob);
    bytes[] memory res = positionManager.multicall(calls);

    (uint256 aliceShares, uint256 aliceAmount) = abi.decode(res[0], (uint256, uint256));
    (uint256 carolShares, uint256 carolAmount) = abi.decode(res[1], (uint256, uint256));

    assertEq(aliceAmount, amount);
    assertEq(carolAmount, amount);
    assertEq(aliceShares, expectedShares);
    assertEq(carolShares, expectedShares);

    assertEq(
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice),
      aliceSuppliedAmountBefore + amount
    );
    assertEq(
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), carol),
      carolSuppliedAmountBefore + amount
    );
  }
}
