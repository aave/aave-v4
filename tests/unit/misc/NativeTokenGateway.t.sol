// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract NativeTokenGatewayTest is SpokeBase {
  NativeTokenGateway public nativeTokenGateway;
  TestReturnValues public returnValues;

  function setUp() public virtual override {
    super.setUp();

    nativeTokenGateway = new NativeTokenGateway(address(tokenList.weth), address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(nativeTokenGateway), true);

    vm.prank(address(ADMIN));
    nativeTokenGateway.registerSpoke(address(spoke1), true);

    deal(address(tokenList.weth), MAX_SUPPLY_AMOUNT);
    deal(bob, mintAmount_WETH);
  }

  function test_constructor() public {
    NativeTokenGateway gateway = new NativeTokenGateway(address(tokenList.weth), address(ADMIN));

    assertEq(gateway.NATIVE_WRAPPER(), address(tokenList.weth));

    assertEq(gateway.owner(), address(ADMIN));
    assertEq(gateway.pendingOwner(), address(0));

    assertEq(gateway.rescueGuardian(), address(ADMIN));
  }

  function test_constructor_revertsWith_InvalidAddress() public {
    vm.expectRevert(IGatewayBase.InvalidAddress.selector);
    new NativeTokenGateway(address(0), address(ADMIN));
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
    emit ISpokeBase.Supply(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      hub1.previewAddByAssets(wethAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = nativeTokenGateway.supplyNative{value: amount}(
      address(spoke1),
      _wethReserveId(spoke1),
      amount
    );

    assertEq(returnValues.amount, amount);
    assertEq(returnValues.shares, hub1.previewAddByAssets(wethAssetId, amount));

    assertEq(bob.balance, prevUserBalance - amount);
    assertEq(
      spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob),
      prevUserSuppliedAmount + amount
    );
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + amount);
    _checkFinalBalances();

    assertFalse(_isUsingAsCollateral(spoke1, _wethReserveId(spoke1), bob));
  }

  function test_supplyNative_revertsWith_SpokeNotRegistered() public {
    uint256 amount = 100e18;
    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: amount}(address(spoke2), _wethReserveId(spoke1), amount);

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: amount}(address(0), _wethReserveId(spoke1), amount);
  }

  function test_supplyNative_revertsWith_InvalidAmount() public {
    vm.expectRevert(IGatewayBase.InvalidAmount.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: 0}(address(spoke1), _wethReserveId(spoke1), 0);
  }

  function test_supplyNative_revertsWith_NotNativeWrappedAsset() public {
    uint256 amount = 100e18;
    vm.expectRevert(INativeTokenGateway.NotNativeWrappedAsset.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: amount}(
      address(spoke1),
      _wethReserveId(spoke1) + 1,
      amount
    );
  }

  function test_supplyNative_revertsWith_NativeAmountMismatch() public {
    vm.expectRevert(INativeTokenGateway.NativeAmountMismatch.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: 0}(address(spoke1), _wethReserveId(spoke1), 100e18);

    vm.expectRevert(INativeTokenGateway.NativeAmountMismatch.selector);
    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: 500e18}(address(spoke1), _wethReserveId(spoke1), 100e18);
  }

  function test_supplyAndCollateralNative() public {
    test_supplyAndCollateralNative_fuzz(100e18);
  }

  function test_supplyAndCollateralNative_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);
    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob);

    assertEq(tokenList.weth.balanceOf(address(hub1)), 0);
    assertEq(prevUserSuppliedAmount, 0);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      hub1.previewAddByAssets(wethAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = nativeTokenGateway.supplyAsCollateralNative{
      value: amount
    }(address(spoke1), _wethReserveId(spoke1), amount);

    assertEq(returnValues.amount, amount);
    assertEq(returnValues.shares, hub1.previewAddByAssets(wethAssetId, amount));

    assertEq(bob.balance, prevUserBalance - amount);
    assertEq(
      spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob),
      prevUserSuppliedAmount + amount
    );
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + amount);
    _checkFinalBalances();

    assertTrue(_isUsingAsCollateral(spoke1, _wethReserveId(spoke1), bob));
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
    uint256 expectedSupplyShares = hub1.previewAddByAssets(wethAssetId, mintAmount_WETH);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob);

    assertEq(spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      _wethReserveId(spoke1),
      address(nativeTokenGateway),
      bob,
      hub1.previewRemoveByAssets(wethAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = nativeTokenGateway.withdrawNative(
      address(spoke1),
      _wethReserveId(spoke1),
      amount
    );

    assertEq(returnValues.amount, amount);
    assertEq(returnValues.shares, hub1.previewRemoveByAssets(wethAssetId, amount));

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
    uint256 expectedSupplyShares = hub1.previewAddByAssets(wethAssetId, supplyAmount);

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
      expectedSupplyShares,
      supplyAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = nativeTokenGateway.withdrawNative(
      address(spoke1),
      _wethReserveId(spoke1),
      UINT256_MAX
    );

    assertEq(returnValues.amount, supplyAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

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
    uint256 expectedSupplyShares = hub1.previewAddByAssets(wethAssetId, supplyAmount);

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
      expectedSupplyShares,
      expectedWithdrawAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = nativeTokenGateway.withdrawNative(
      address(spoke1),
      _wethReserveId(spoke1),
      UINT256_MAX
    );

    assertEq(returnValues.amount, expectedWithdrawAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(bob.balance, prevUserBalance + expectedWithdrawAmount);
    assertEq(spoke1.getUserSuppliedAssets(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - expectedWithdrawAmount);
    _checkFinalBalances();
  }

  function test_withdrawNative_revertsWith_SpokeNotRegistered() public {
    uint256 amount = 100e18;
    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(address(spoke2), _wethReserveId(spoke1), amount);

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(address(0), _wethReserveId(spoke1), amount);
  }

  function test_withdrawNative_revertsWith_InvalidAmount() public {
    vm.expectRevert(IGatewayBase.InvalidAmount.selector);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(address(spoke1), _wethReserveId(spoke1), 0);
  }

  function test_withdrawNative_revertsWith_NotNativeWrappedAsset() public {
    uint256 amount = 100e18;

    vm.expectRevert(INativeTokenGateway.NotNativeWrappedAsset.selector);
    vm.prank(bob);
    nativeTokenGateway.withdrawNative(address(spoke1), _wethReserveId(spoke1) + 1, amount);
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
      hub1.previewRestoreByAssets(wethAssetId, borrowAmount),
      borrowAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = nativeTokenGateway.borrowNative(
      address(spoke1),
      _wethReserveId(spoke1),
      borrowAmount
    );

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );

    assertEq(returnValues.amount, borrowAmount);
    assertEq(returnValues.shares, hub1.previewDrawByAssets(wethAssetId, borrowAmount));

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - borrowAmount);
    assertEq(bob.balance, prevUserBalance + borrowAmount);
    _checkFinalBalances();
  }

  function test_borrowNative_revertsWith_SpokeNotRegistered() public {
    uint256 amount = 100e18;
    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    nativeTokenGateway.borrowNative(address(spoke2), _wethReserveId(spoke1), amount);

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    nativeTokenGateway.borrowNative(address(0), _wethReserveId(spoke1), amount);
  }

  function test_borrowNative_revertsWith_InvalidAmount() public {
    vm.expectRevert(IGatewayBase.InvalidAmount.selector);
    vm.prank(bob);
    nativeTokenGateway.borrowNative(address(spoke1), _wethReserveId(spoke1), 0);
  }

  function test_borrowNative_revertsWith_NotNativeWrappedAsset() public {
    uint256 borrowAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.NotNativeWrappedAsset.selector);
    vm.prank(bob);
    nativeTokenGateway.borrowNative(address(spoke1), _wethReserveId(spoke1) + 1, borrowAmount);
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
    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
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
      repayAmount,
      expectedPremiumDelta
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = nativeTokenGateway.repayNative{value: repayAmount}(
      address(spoke1),
      _wethReserveId(spoke1),
      repayAmount
    );

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(_wethReserveId(spoke1), bob);

    assertEq(returnValues.amount, repayAmount);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(wethAssetId, baseRestored));

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

    {
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDelta(
        spoke1,
        bob,
        _wethReserveId(spoke1),
        repayAmount
      );
      uint256 repaidAmount = _min(userDrawnDebt + userPremiumDebt, repayAmount);
      vm.expectEmit(address(spoke1));
      emit ISpokeBase.Repay(
        _wethReserveId(spoke1),
        address(nativeTokenGateway),
        bob,
        hub1.previewRestoreByAssets(wethAssetId, baseRestored),
        repaidAmount,
        expectedPremiumDelta
      );
      vm.prank(bob);
      (returnValues.shares, returnValues.amount) = nativeTokenGateway.repayNative{
        value: repayAmount
      }(address(spoke1), _wethReserveId(spoke1), repayAmount);

      assertApproxEqAbs(returnValues.amount, baseRestored + premiumRestored, 1);
      assertEq(returnValues.shares, hub1.previewRestoreByAssets(wethAssetId, baseRestored));
    }

    (uint256 newUserDrawnDebt, uint256 newUserPremiumDebt) = spoke1.getUserDebt(
      _wethReserveId(spoke1),
      bob
    );

    assertApproxEqAbs(
      newUserDrawnDebt + newUserPremiumDebt,
      userDrawnDebt + userPremiumDebt - (baseRestored + premiumRestored),
      2
    );
    assertApproxEqAbs(
      tokenList.weth.balanceOf(address(hub1)),
      prevHubBalance + (baseRestored + premiumRestored),
      2
    );
    assertApproxEqAbs(bob.balance, prevUserBalance - (baseRestored + premiumRestored), 1);
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
      totalRepaid,
      expectedPremiumDelta
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = nativeTokenGateway.repayNative{value: repayAmount}(
      address(spoke1),
      _wethReserveId(spoke1),
      repayAmount
    );

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(_wethReserveId(spoke1), bob);

    assertEq(returnValues.amount, baseRestored + premiumRestored);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(wethAssetId, baseRestored));

    assertEq(userDrawnDebt + userPremiumDebt, 0);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + totalRepaid);
    assertEq(bob.balance, prevUserBalance - totalRepaid);
    _checkFinalBalances();
  }

  function test_repayNative_revertsWith_SpokeNotRegistered() public {
    uint256 repayAmount = 5e18;

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount}(
      address(spoke2),
      _wethReserveId(spoke1),
      repayAmount
    );

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount}(
      address(0),
      _wethReserveId(spoke1),
      repayAmount
    );
  }

  function test_repayNative_revertsWith_InvalidAmount() public {
    vm.expectRevert(IGatewayBase.InvalidAmount.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: 0}(address(spoke1), _wethReserveId(spoke1), 0);
  }

  function test_repayNative_revertsWith_NotNativeWrappedAsset() public {
    uint256 repayAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.NotNativeWrappedAsset.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount}(
      address(spoke1),
      _wethReserveId(spoke1) + 1,
      repayAmount
    );
  }

  function test_repayNative_revertsWith_NativeAmountMismatch() public {
    uint256 repayAmount = 5e18;

    vm.expectRevert(INativeTokenGateway.NativeAmountMismatch.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: 0}(address(spoke1), _wethReserveId(spoke1), repayAmount);

    vm.expectRevert(INativeTokenGateway.NativeAmountMismatch.selector);
    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount / 2}(
      address(spoke1),
      _wethReserveId(spoke1),
      repayAmount
    );
  }

  function test_receive_revertsWith_UnsupportedAction() public {
    deal(address(this), 1 ether);

    vm.expectRevert(INativeTokenGateway.UnsupportedAction.selector);
    (bool success, ) = address(nativeTokenGateway).call{value: 1 ether}(new bytes(0));
    assertTrue(success);
  }

  function test_fallback_revertsWith_UnsupportedAction() public {
    deal(address(this), 1 ether);

    bytes memory invalidCall = abi.encode('invalidFunction()');

    vm.expectRevert(INativeTokenGateway.UnsupportedAction.selector);
    (bool success, ) = address(nativeTokenGateway).call{value: 1 ether}(invalidCall);
    assertTrue(success);
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
