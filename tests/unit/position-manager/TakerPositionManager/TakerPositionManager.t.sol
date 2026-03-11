// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/position-manager/TakerPositionManager/TakerPositionManager.Base.t.sol';

contract TakerPositionManagerTest is TakerPositionManagerBaseTest {
  function test_approveWithdraw_fuzz(address spender, uint256 reserveId, uint256 amount) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, mintAmount_DAI);

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.WithdrawApproval(address(spoke1), reserveId, alice, spender, amount);
    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, spender, amount);

    assertEq(positionManager.withdrawAllowance(address(spoke1), reserveId, alice, spender), amount);
  }

  function test_approveWithdraw_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke2), 1, bob, 100e18);
  }

  function test_renounceWithdrawAllowance_fuzz(uint256 initialAllowance) public {
    uint256 reserveId = _randomReserveId(spoke1);
    initialAllowance = bound(initialAllowance, 1, mintAmount_DAI);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, bob, initialAllowance);

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.WithdrawApproval(address(spoke1), reserveId, alice, bob, 0);
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke1), reserveId, alice);

    assertEq(positionManager.withdrawAllowance(address(spoke1), reserveId, alice, bob), 0);
  }

  function test_renounceWithdrawAllowance_noop_alreadyRenounced() public {
    uint256 reserveId = _randomReserveId(spoke1);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, bob, 100e18);
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke1), reserveId, alice);

    vm.recordLogs();
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke1), reserveId, alice);
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_renounceWithdrawAllowance_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke2), 1, alice);
  }

  function test_withdrawOnBehalfOf() public {
    test_withdrawOnBehalfOf_fuzz(100e18);
  }

  function test_withdrawOnBehalfOf_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: mintAmount_DAI,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, mintAmount_DAI);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, amount);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));
    uint256 userSuppliedAmountBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);

    assertEq(spoke1.getUserSuppliedShares(_daiReserveId(spoke1), alice), expectedSupplyShares);

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.WithdrawApproval(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob,
      0
    );
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      hub1.previewRemoveByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      amount,
      alice
    );

    assertEq(returnValues.amount, amount);
    assertEq(returnValues.shares, hub1.previewRemoveByAssets(daiAssetId, amount));

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore + amount);
    assertEq(
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice),
      userSuppliedAmountBefore - amount
    );
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - amount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      0
    );
  }

  function test_withdrawOnBehalfOf_fuzz_allBalance(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, supplyAmount * 10);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));
    uint256 allowanceBefore = positionManager.withdrawAllowance(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob
    );

    assertEq(spoke1.getUserSuppliedShares(_daiReserveId(spoke1), alice), expectedSupplyShares);

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.WithdrawApproval(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob,
      allowanceBefore - (supplyAmount * 2)
    );
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      expectedSupplyShares,
      supplyAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      supplyAmount * 2,
      alice
    );

    assertEq(returnValues.amount, supplyAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore + supplyAmount);
    assertEq(spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - supplyAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      allowanceBefore - (supplyAmount * 2)
    );
  }

  function test_withdrawOnBehalfOf_fuzz_allBalance_noAllowanceDecreased(
    uint256 supplyAmount
  ) public {
    supplyAmount = bound(supplyAmount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, type(uint256).max);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    assertEq(spoke1.getUserSuppliedShares(_daiReserveId(spoke1), alice), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      expectedSupplyShares,
      supplyAmount
    );
    vm.recordLogs();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      type(uint256).max,
      alice
    );
    vm.getRecordedLogs();
    _assertEventNotEmitted(ITakerPositionManager.WithdrawApproval.selector);

    assertEq(returnValues.amount, supplyAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore + supplyAmount);
    assertEq(spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - supplyAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      type(uint256).max
    );
  }

  function test_withdrawOnBehalfOf_fuzz_allBalanceWithInterest(
    uint256 supplyAmount,
    uint256 borrowAmount
  ) public {
    supplyAmount = bound(supplyAmount, 2, mintAmount_DAI / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    skip(322 days);
    vm.assume(hub1.getAddedAssets(daiAssetId) > supplyAmount);
    uint256 repayAmount = spoke1.getReserveTotalDebt(_daiReserveId(spoke1));
    deal(address(tokenList.dai), bob, repayAmount);

    Utils.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    uint256 expectedWithdrawAmount = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, supplyAmount * 10);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    assertEq(spoke1.getUserSuppliedShares(_daiReserveId(spoke1), alice), expectedSupplyShares);

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.WithdrawApproval(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob,
      0
    );
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      expectedSupplyShares,
      expectedWithdrawAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      supplyAmount * 10,
      alice
    );

    assertEq(returnValues.amount, expectedWithdrawAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore + expectedWithdrawAmount);
    assertEq(spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - expectedWithdrawAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      0
    );
  }

  function test_withdrawOnBehalfOf_revertsWith_InsufficientWithdrawAllowance(
    uint256 approvalAmount
  ) public {
    uint256 amount = 100e18;
    approvalAmount = bound(approvalAmount, 1, amount - 1);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: mintAmount_DAI,
      onBehalfOf: alice
    });

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, approvalAmount);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITakerPositionManager.InsufficientWithdrawAllowance.selector,
        approvalAmount,
        amount
      )
    );
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), _daiReserveId(spoke1), amount, alice);
  }

  function test_withdrawOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke1);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, bob, 100e18);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), reserveId, 100e18, alice);
  }

  function test_withdrawOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke2), 1, 100e18, alice);
  }

  function test_approveBorrow_fuzz(address spender, uint256 reserveId, uint256 amount) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, mintAmount_DAI);

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.BorrowApproval(address(spoke1), reserveId, alice, spender, amount);
    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), reserveId, spender, amount);

    assertEq(positionManager.borrowAllowance(address(spoke1), reserveId, alice, spender), amount);
  }

  function test_approveBorrow_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.approveBorrow(address(spoke2), 1, bob, 100e18);
  }

  function test_renounceBorrowAllowance_fuzz(uint256 initialAllowance) public {
    uint256 reserveId = _randomReserveId(spoke1);
    initialAllowance = bound(initialAllowance, 1, mintAmount_DAI);

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), reserveId, bob, initialAllowance);

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.BorrowApproval(address(spoke1), reserveId, alice, bob, 0);
    vm.prank(bob);
    positionManager.renounceBorrowAllowance(address(spoke1), reserveId, alice);

    assertEq(positionManager.borrowAllowance(address(spoke1), reserveId, alice, bob), 0);
  }

  function test_renounceBorrowAllowance_noop_alreadyRenounced() public {
    uint256 reserveId = _randomReserveId(spoke1);

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), reserveId, bob, 100e18);
    vm.prank(bob);
    positionManager.renounceBorrowAllowance(address(spoke1), reserveId, alice);

    vm.recordLogs();
    vm.prank(bob);
    positionManager.renounceBorrowAllowance(address(spoke1), reserveId, alice);
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_renounceBorrowAllowance_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceBorrowAllowance(address(spoke2), 1, alice);
  }

  function test_borrowOnBehalfOf() public {
    test_borrowOnBehalfOf_fuzz(5e18, 5e18);
  }

  function test_borrowOnBehalfOf_fuzz(uint256 borrowAmount, uint256 approveBorrowAmount) public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    borrowAmount = bound(borrowAmount, 1, bobSupplyAmount);
    approveBorrowAmount = bound(approveBorrowAmount, borrowAmount, borrowAmount * 10);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), _daiReserveId(spoke1), bob, approveBorrowAmount);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.BorrowApproval(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob,
      approveBorrowAmount - borrowAmount
    );
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      hub1.previewRestoreByAssets(daiAssetId, borrowAmount),
      borrowAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.borrowOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      borrowAmount,
      alice
    );

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );

    assertEq(returnValues.amount, borrowAmount);
    assertEq(returnValues.shares, hub1.previewDrawByAssets(daiAssetId, borrowAmount));

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(alice)), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(address(bob)), callerBalanceBefore + borrowAmount);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.borrowAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      approveBorrowAmount - borrowAmount
    );
  }

  function test_borrowOnBehalfOf_fuzz_noAllowanceDecrease(uint256 borrowAmount) public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    borrowAmount = bound(borrowAmount, 1, bobSupplyAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), _daiReserveId(spoke1), bob, type(uint256).max);

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      hub1.previewRestoreByAssets(daiAssetId, borrowAmount),
      borrowAmount
    );
    vm.recordLogs();
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.borrowOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      borrowAmount,
      alice
    );
    vm.getRecordedLogs();
    _assertEventNotEmitted(ITakerPositionManager.BorrowApproval.selector);

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );

    assertEq(returnValues.amount, borrowAmount);
    assertEq(returnValues.shares, hub1.previewDrawByAssets(daiAssetId, borrowAmount));

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(alice)), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(address(bob)), callerBalanceBefore + borrowAmount);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.borrowAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      type(uint256).max
    );
  }

  function test_borrowOnBehalfOf_revertsWith_InsufficientBorrowAllowance(
    uint256 approveBorrowAmount
  ) public {
    uint256 borrowAmount = 100e18;
    approveBorrowAmount = bound(approveBorrowAmount, 1, borrowAmount - 1);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), _daiReserveId(spoke1), bob, approveBorrowAmount);

    vm.expectRevert(
      abi.encodeWithSelector(
        ITakerPositionManager.InsufficientBorrowAllowance.selector,
        approveBorrowAmount,
        borrowAmount
      )
    );
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke1), _daiReserveId(spoke1), borrowAmount, alice);
  }

  function test_borrowOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke1);

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), reserveId, bob, 100e18);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke1), reserveId, 100e18, alice);
  }

  function test_borrowOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke2), 1, 100e18, alice);
  }

  function test_multicall() public {
    uint256 amount = 100e18;

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature(
      'approveWithdraw(address,uint256,address,uint256)',
      address(spoke1),
      _daiReserveId(spoke1),
      bob,
      amount
    );
    calls[1] = abi.encodeWithSignature(
      'approveBorrow(address,uint256,address,uint256)',
      address(spoke1),
      _daiReserveId(spoke1),
      bob,
      amount
    );

    vm.prank(alice);
    bytes[] memory res = positionManager.multicall(calls);

    assertEq(res[0].length, 0);
    assertEq(res[1].length, 0);

    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      amount
    );
    assertEq(
      positionManager.borrowAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      amount
    );
  }
}
