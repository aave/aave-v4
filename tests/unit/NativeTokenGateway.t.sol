// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract NativeTokenGatewayTest is Base {
  NativeTokenGateway public nativeTokenGateway;

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();

    nativeTokenGateway = new NativeTokenGateway(
      address(tokenList.weth),
      address(spoke1),
      address(ADMIN)
    );

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(nativeTokenGateway), true);

    deal(address(tokenList.weth), MAX_SUPPLY_AMOUNT);
    deal(bob, mintAmount_WETH);
  }

  function test_constructor() public {
    NativeTokenGateway gateway = new NativeTokenGateway(
      address(tokenList.weth),
      address(spoke1),
      address(ADMIN)
    );

    assertEq(gateway.NATIVE_WRAPPER(), address(tokenList.weth));
    assertEq(gateway.SPOKE(), address(spoke1));

    assertEq(gateway.owner(), address(ADMIN));
    assertEq(gateway.pendingOwner(), address(0));

    assertEq(gateway.rescueGuardian(), address(ADMIN));
  }

  function test_constructor_revertsWith_InvalidAddress() public {
    vm.expectRevert(INativeTokenGateway.InvalidAddress.selector);
    new NativeTokenGateway(address(0), address(spoke1), address(ADMIN));

    vm.expectRevert(INativeTokenGateway.InvalidAddress.selector);
    new NativeTokenGateway(address(tokenList.weth), address(0), address(ADMIN));
  }

  function test_renouncePositionManagerRole() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));

    vm.prank(user);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    assertTrue(spoke1.isPositionManager(user, address(nativeTokenGateway)));

    vm.prank(ADMIN);
    nativeTokenGateway.renouncePositionManagerRole(user);

    assertFalse(spoke1.isPositionManager(user, address(nativeTokenGateway)));
  }

  function test_renouncePositionManagerRole_revertsWith_OwnableUnauthorizedAccount() public {
    (address user, ) = makeAddrAndKey(string(vm.randomBytes(32)));

    vm.prank(user);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
    vm.prank(user);
    nativeTokenGateway.renouncePositionManagerRole(user);
  }

  function test_supplyNative() public {
    test_supplyNative_fuzz(100e18);
  }

  function test_supplyNative_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);
    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob);

    assertEq(tokenList.weth.balanceOf(address(hub1)), 0);
    assertEq(prevUserSuppliedAmount, 0);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(_wethReserveId(spoke1), address(nativeTokenGateway), bob, amount);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: amount}(_wethReserveId(spoke1), amount);

    assertEq(bob.balance, prevUserBalance - amount);
    assertEq(
      spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob),
      prevUserSuppliedAmount + amount
    );
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + amount);
    _checkFinalBalances();
  }

  function test_supplyNative_revertsWith_InvalidAmount() public {
    uint256 amount = 100e18;
    vm.expectRevert(INativeTokenGateway.InvalidAmount.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: 0}(_wethReserveId(spoke1), 0);
  }

  function test_supplyNative_revertsWith_NotNativeWrappedAsset() public {
    uint256 amount = 100e18;
    vm.expectRevert(INativeTokenGateway.NotNativeWrappedAsset.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: amount}(_wethReserveId(spoke1) + 1, amount);
  }

  function test_supplyNative_revertsWith_NativeAmountMismatch() public {
    vm.expectRevert(INativeTokenGateway.NativeAmountMismatch.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: 0}(_wethReserveId(spoke1), 100e18);

    vm.expectRevert(INativeTokenGateway.NativeAmountMismatch.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: 500e18}(_wethReserveId(spoke1), 100e18);
  }

  function test_withdrawNative() public {
    test_withdrawNative_fuzz(100e18);
  }

  function test_withdrawNative_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);

    Utils.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: mintAmount_WETH,
      onBehalfOf: bob
    });
    uint256 expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, mintAmount_WETH);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob);

    assertEq(spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(_wethReserveId(spoke1), address(nativeTokenGateway), bob, amount);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(_wethReserveId(spoke1), amount, bob);

    assertEq(bob.balance, prevUserBalance + amount);
    assertEq(
      spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob),
      prevUserSuppliedAmount - amount
    );
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - amount);
    _checkFinalBalances();
  }

  function test_withdrawNative_fuzz_allBalance(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, mintAmount_WETH);

    Utils.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    uint256 expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, supplyAmount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    assertEq(spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      supplyAmount
    );
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(_wethReserveId(spoke1), UINT256_MAX, bob);

    assertEq(bob.balance, prevUserBalance + supplyAmount);
    assertEq(spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - supplyAmount);
    _checkFinalBalances();
  }

  function test_withdrawNative_fuzz_allBalanceWithInterest(
    uint256 supplyAmount,
    uint256 borrowAmount
  ) public {
    supplyAmount = bound(supplyAmount, 2, mintAmount_WETH / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    uint256 expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, supplyAmount);

    // Bob borrows weth
    Utils.borrow({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    skip(322 days);
    vm.assume(hub1.getAddedAssets(wethAssetId) > supplyAmount);
    uint256 repayAmount = spoke1.getReserveTotalDebt(_wethReserveId(spoke1));
    deal(address(tokenList.weth), bob, repayAmount);

    Utils.repay({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    uint256 expectedWithdrawAmount = spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    assertEq(spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      expectedSupplyShares
    );
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(_wethReserveId(spoke1), UINT256_MAX, bob);

    assertEq(bob.balance, prevUserBalance + expectedWithdrawAmount);
    assertEq(spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - expectedWithdrawAmount);
    _checkFinalBalances();
  }

  function test_withdrawNative_otherReceiver() public {
    test_withdrawNative_fuzz_otherReceiver(100e18);
  }

  function test_withdrawNative_fuzz_otherReceiver(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);

    Utils.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });
    uint256 expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, amount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevReceiverBalance = alice.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob);

    assertEq(spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(_wethReserveId(spoke1), address(nativeTokenGateway), bob, amount);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(_wethReserveId(spoke1), amount, alice);

    assertEq(bob.balance, prevUserBalance);
    assertEq(alice.balance, prevReceiverBalance + amount);
    assertEq(
      spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob),
      prevUserSuppliedAmount - amount
    );
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - amount);
    _checkFinalBalances();
  }

  function test_withdrawNative_revertsWith_InvalidAmount() public {
    uint256 amount = 100e18;

    vm.expectRevert(INativeTokenGateway.InvalidAmount.selector);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(_wethReserveId(spoke1), 0, bob);
  }

  function test_withdrawNative_revertsWith_NotNativeWrappedAsset() public {
    uint256 amount = 100e18;

    vm.expectRevert(INativeTokenGateway.NotNativeWrappedAsset.selector);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(_wethReserveId(spoke1) + 1, amount, bob);
  }

  function test_withdrawNative_revertsWith_InvalidAddress() public {
    uint256 amount = 100e18;

    vm.expectRevert(INativeTokenGateway.InvalidAddress.selector);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(_wethReserveId(spoke1), amount, address(0));
  }

  function test_borrowNative() public {
    test_borrowNative_fuzz(5e18);
  }

  function test_borrowNative_fuzz(uint256 borrowAmount) public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    borrowAmount = bound(borrowAmount, 1, aliceSupplyAmount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, aliceSupplyAmount, alice);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      hub1.previewRestoreByAssets(wethAssetId, borrowAmount)
    );
    vm.prank(bob);
    nativeTokenGateway.borrowNative(_wethReserveId(spoke1), borrowAmount, bob);

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - borrowAmount);
    assertEq(bob.balance, prevUserBalance + borrowAmount);
    _checkFinalBalances();
  }

  function test_borrowNative_otherReceiver() public {
    test_borrowNative_fuzz_otherReceiver(5e18);
  }

  function test_borrowNative_fuzz_otherReceiver(uint256 borrowAmount) public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    borrowAmount = bound(borrowAmount, 1, aliceSupplyAmount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, aliceSupplyAmount, alice);

    uint256 prevUserBalance = bob.balance;
    uint256 prevReceiverBalance = alice.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      hub1.previewRestoreByAssets(wethAssetId, borrowAmount)
    );
    vm.prank(bob);
    nativeTokenGateway.borrowNative(_wethReserveId(spoke1), borrowAmount, alice);

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - borrowAmount);
    assertEq(bob.balance, prevUserBalance);
    assertEq(alice.balance, prevReceiverBalance + borrowAmount);
    _checkFinalBalances();
  }

  function test_borrowNative_revertsWith_InvalidAmount() public {
    uint256 borrowAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.InvalidAmount.selector);
    vm.prank(bob);
    nativeTokenGateway.borrowNative(_wethReserveId(spoke1), 0, bob);
  }

  function test_borrowNative_revertsWith_NotNativeWrappedAsset() public {
    uint256 borrowAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.NotNativeWrappedAsset.selector);
    vm.prank(bob);
    nativeTokenGateway.borrowNative(_wethReserveId(spoke1) + 1, borrowAmount, bob);
  }

  function test_borrowNative_revertsWith_InvalidAddress() public {
    uint256 borrowAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.InvalidAddress.selector);
    vm.prank(bob);
    nativeTokenGateway.borrowNative(_wethReserveId(spoke1), borrowAmount, address(0));
  }

  function test_repayNative() public {
    test_repayNative_fuzz(5e18);
  }

  function test_repayNative_fuzz(uint256 repayAmount) public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    repayAmount = bound(repayAmount, 1, borrowAmount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.borrow(spoke1, _wethReserveId(spoke1), bob, borrowAmount, bob);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      wethAssetId
    );
    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDelta(
      spoke1,
      bob,
      _wethReserveId(spoke1),
      repayAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      hub1.previewRestoreByAssets(wethAssetId, baseRestored),
      expectedPremiumDelta
    );
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount}(_wethReserveId(spoke1), repayAmount);

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(_wethReserveId(spoke1), bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount - repayAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + repayAmount);
    assertEq(bob.balance, prevUserBalance - repayAmount);
    _checkFinalBalances();
  }

  function test_repayNative_fuzz_withInterest(uint256 repayAmount, uint256 elapsedTime) public {
    uint256 borrowAmount = 10e18;
    repayAmount = bound(repayAmount, borrowAmount, borrowAmount * 10);
    elapsedTime = bound(elapsedTime, 100 days, 400 days);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 100000e18, bob);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, 10e18, alice);
    Utils.borrow(spoke1, _wethReserveId(spoke1), bob, borrowAmount, bob);

    skip(elapsedTime);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      wethAssetId
    );
    uint256 totalRepaid = baseRestored + premiumRestored;
    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDelta(
      spoke1,
      bob,
      _wethReserveId(spoke1),
      repayAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      hub1.previewRestoreByAssets(wethAssetId, baseRestored),
      expectedPremiumDelta
    );
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount}(_wethReserveId(spoke1), repayAmount);

    (uint256 newUserDrawnDebt, uint256 newUserPremiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );

    assertApproxEqAbs(
      newUserDrawnDebt + newUserPremiumDebt,
      userDrawnDebt + userPremiumDebt - totalRepaid,
      2
    );
    assertApproxEqAbs(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + totalRepaid, 2);
    assertApproxEqAbs(bob.balance, prevUserBalance - totalRepaid, 1);
    _checkFinalBalances();
  }

  function test_repayNative_excessAmount() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 15e18;

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.borrow(spoke1, _wethReserveId(spoke1), bob, borrowAmount, bob);

    skip(322 days);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      wethAssetId
    );
    uint256 totalRepaid = baseRestored + premiumRestored;
    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDelta(
      spoke1,
      bob,
      _wethReserveId(spoke1),
      repayAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      hub1.previewRestoreByAssets(wethAssetId, baseRestored),
      expectedPremiumDelta
    );
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount}(_wethReserveId(spoke1), repayAmount);

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(_wethReserveId(spoke1), bob);

    assertEq(userDrawnDebt + userPremiumDebt, 0);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + totalRepaid);
    assertEq(bob.balance, prevUserBalance - totalRepaid);
    _checkFinalBalances();
  }

  function test_repayNative_revertsWith_InvalidAmount() public {
    uint256 repayAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.InvalidAmount.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: 0}(_wethReserveId(spoke1), 0);
  }

  function test_repayNative_revertsWith_NotNativeWrappedAsset() public {
    uint256 repayAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.NotNativeWrappedAsset.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount}(_wethReserveId(spoke1) + 1, repayAmount);
  }

  function test_repayNative_revertsWith_NativeAmountMismatch() public {
    uint256 repayAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.NativeAmountMismatch.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: 0}(_wethReserveId(spoke1), repayAmount);

    vm.expectRevert(INativeTokenGateway.NativeAmountMismatch.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount / 2}(_wethReserveId(spoke1), repayAmount);
  }

  function test_receive_revertsWith_UnsupportedAction() public {
    deal(address(this), 1 ether);

    vm.expectRevert(INativeTokenGateway.UnsupportedAction.selector);
    address(nativeTokenGateway).call{value: 1 ether}(new bytes(0));
  }

  function test_fallback_revertsWith_UnsupportedAction() public {
    deal(address(this), 1 ether);

    bytes memory invalidCall = abi.encode('invalidFunction()');

    vm.expectRevert(INativeTokenGateway.UnsupportedAction.selector);
    address(nativeTokenGateway).call{value: 1 ether}(invalidCall);
  }

  function _getUserData(address user) internal view returns (ISpoke.UserPosition memory) {
    return getUserInfo(spoke1, user, _wethReserveId(spoke1));
  }

  function _checkFinalBalances() internal view {
    assertEq(address(nativeTokenGateway).balance, 0);
    assertEq(tokenList.weth.balanceOf(address(nativeTokenGateway)), 0);
    assertEq(tokenList.weth.allowance(address(nativeTokenGateway), address(hub1)), 0);
  }
}
