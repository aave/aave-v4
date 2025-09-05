// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';

contract WrappedTokenGatewayV4Test is Base {
  WrappedTokenGatewayV4 public wrappedTokenGateway;
  uint256 public wethReserveId;

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();

    wethReserveId = wethReserveId;

    wrappedTokenGateway = new WrappedTokenGatewayV4(
      address(tokenList.weth),
      address(spoke1),
      address(ADMIN)
    );

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(wrappedTokenGateway), true);

    deal(address(tokenList.weth), MAX_SUPPLY_AMOUNT);
  }

  function _getUserData(address user) internal view returns (DataTypes.UserPosition memory) {
    return getUserInfo(spoke1, user, wethReserveId);
  }

  function test_constructor() public {
    WrappedTokenGatewayV4 gateway = new WrappedTokenGatewayV4(
      address(tokenList.weth),
      address(spoke1),
      address(ADMIN)
    );

    assertEq(address(gateway.NATIVE_WRAPPER()), address(tokenList.weth));
    assertEq(address(gateway.SPOKE()), address(spoke1));

    assertEq(gateway.owner(), address(ADMIN));
    assertEq(gateway.pendingOwner(), address(0));
  }

  function test_setUserPositionManagerWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));

    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: address(wrappedTokenGateway),
      user: user,
      approve: vm.randomBool(),
      nonce: spoke1.nonces(user),
      deadline: vm.randomUint(vm.getBlockTimestamp(), MAX_SKIP_TIME)
    });
    bytes32 digest = _getTypedDataHash(spoke1, params);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    wrappedTokenGateway.setUserPositionManagerWithSig(
      user,
      params.approve,
      params.deadline,
      v,
      r,
      s
    );

    assertEq(spoke1.isPositionManager(user, address(wrappedTokenGateway)), params.approve);
  }

  function test_renouncePositionManagerRole() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));

    vm.prank(user);
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    assertTrue(spoke1.isPositionManager(user, address(wrappedTokenGateway)));

    vm.prank(user);
    wrappedTokenGateway.renouncePositionManagerRole(user);

    assertFalse(spoke1.isPositionManager(user, address(wrappedTokenGateway)));
  }

  function test_supplyNative() public {
    test_supplyNative_fuzz(100e18);
  }

  function test_supplyNative_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAmount(wethReserveId, bob);

    assertEq(tokenList.weth.balanceOf(address(hub1)), 0);
    assertEq(prevUserSuppliedAmount, 0);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.supplyNative{value: amount}(wethReserveId, amount);

    assertEq(bob.balance, prevUserBalance - amount);
    assertEq(spoke1.getUserSuppliedAmount(wethReserveId, bob), prevUserSuppliedAmount + amount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + amount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_supplyNative_revertsWith_InvalidAmount() public {
    uint256 amount = 100e18;
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidAmount.selector);
    wrappedTokenGateway.supplyNative{value: 0}(wethReserveId, 0);
  }

  function test_supplyNative_revertsWith_InvalidReserveId() public {
    uint256 amount = 100e18;
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidReserveId.selector);
    wrappedTokenGateway.supplyNative{value: amount}(wethReserveId + 1, amount);
  }

  function test_supplyNative_revertsWith_NativeAmountMismatch() public {
    uint256 amount = 100e18;
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.NativeAmountMismatch.selector);
    wrappedTokenGateway.supplyNative{value: 0}(wethReserveId, amount);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.NativeAmountMismatch.selector);
    wrappedTokenGateway.supplyNative{value: amount / 2}(wethReserveId, amount);
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
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAmount(wethReserveId, bob);

    assertEq(spoke1.getUserSuppliedShares(wethReserveId, bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.withdrawNative(wethReserveId, amount, bob);

    assertEq(bob.balance, prevUserBalance + amount);
    assertEq(spoke1.getUserSuppliedAmount(wethReserveId, bob), prevUserSuppliedAmount - amount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - amount);
    assertEq(address(wrappedTokenGateway).balance, 0);
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
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    assertEq(spoke1.getUserSuppliedShares(wethReserveId, bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(wethReserveId, address(wrappedTokenGateway), bob, supplyAmount);
    vm.prank(bob);
    wrappedTokenGateway.withdrawNative(wethReserveId, UINT256_MAX, bob);

    assertEq(bob.balance, prevUserBalance + supplyAmount);
    assertEq(spoke1.getUserSuppliedAmount(wethReserveId, bob), 0);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - supplyAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_withdrawNative_fuzz_allBalanceWithInterest(
    uint256 supplyAmount,
    uint256 borrowAmount
  ) public {
    supplyAmount = bound(supplyAmount, 2, mintAmount_WETH / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

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

    skip(365 days);
    vm.assume(hub1.getAssetAddedAmount(wethAssetId) > supplyAmount);
    uint256 repayAmount = spoke1.getReserveTotalDebt(_wethReserveId(spoke1));
    deal(address(tokenList.weth), bob, repayAmount);

    Utils.repay({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    uint256 expectedWithdrawAmount = spoke1.getUserSuppliedAmount(wethReserveId, bob);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    assertEq(spoke1.getUserSuppliedShares(wethReserveId, bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      wethReserveId,
      address(wrappedTokenGateway),
      bob,
      expectedSupplyShares
    );
    vm.prank(bob);
    wrappedTokenGateway.withdrawNative(wethReserveId, UINT256_MAX, bob);

    assertEq(bob.balance, prevUserBalance + expectedWithdrawAmount);
    assertEq(spoke1.getUserSuppliedAmount(wethReserveId, bob), 0);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - expectedWithdrawAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);
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
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    uint256 prevUserBalance = bob.balance;
    uint256 prevReceiverBalance = alice.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAmount(wethReserveId, bob);

    assertEq(spoke1.getUserSuppliedShares(wethReserveId, bob), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.withdrawNative(wethReserveId, amount, alice);

    assertEq(bob.balance, prevUserBalance);
    assertEq(alice.balance, prevReceiverBalance + amount);
    assertEq(spoke1.getUserSuppliedAmount(wethReserveId, bob), prevUserSuppliedAmount - amount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - amount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_withdrawNative_revertsWith_InvalidAmount() public {
    uint256 amount = 100e18;

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidAmount.selector);
    wrappedTokenGateway.withdrawNative(wethReserveId, 0, bob);
  }

  function test_withdrawNative_revertsWith_InvalidReserveId() public {
    uint256 amount = 100e18;

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidReserveId.selector);
    wrappedTokenGateway.withdrawNative(wethReserveId + 1, amount, bob);
  }

  function test_withdrawNative_revertsWith_InvalidAddress() public {
    uint256 amount = 100e18;

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidAddress.selector);
    wrappedTokenGateway.withdrawNative(wethReserveId, amount, address(0));
  }

  function test_borrowNative() public {
    test_borrowNative_fuzz(5e18);
  }

  function test_borrowNative_fuzz(uint256 borrowAmount) public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    borrowAmount = bound(borrowAmount, 1, aliceSupplyAmount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, wethReserveId, alice, aliceSupplyAmount, alice);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      wethReserveId,
      address(wrappedTokenGateway),
      bob,
      hub1.convertToDrawnShares(wethAssetId, borrowAmount)
    );
    vm.prank(bob);
    wrappedTokenGateway.borrowNative(wethReserveId, borrowAmount, bob);

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - borrowAmount);
    assertEq(bob.balance, prevUserBalance + borrowAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_borrowNative_otherReceiver() public {
    test_borrowNative_fuzz_otherReceiver(5e18);
  }

  function test_borrowNative_fuzz_otherReceiver(uint256 borrowAmount) public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    borrowAmount = bound(borrowAmount, 1, aliceSupplyAmount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, wethReserveId, alice, aliceSupplyAmount, alice);

    uint256 prevUserBalance = bob.balance;
    uint256 prevReceiverBalance = alice.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      wethReserveId,
      address(wrappedTokenGateway),
      bob,
      hub1.convertToDrawnShares(wethAssetId, borrowAmount)
    );
    vm.prank(bob);
    wrappedTokenGateway.borrowNative(wethReserveId, borrowAmount, alice);

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - borrowAmount);
    assertEq(bob.balance, prevUserBalance);
    assertEq(alice.balance, prevReceiverBalance + borrowAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_borrowNative_revertsWith_InvalidAmount() public {
    uint256 borrowAmount = 5e18;

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidAmount.selector);
    wrappedTokenGateway.borrowNative(wethReserveId, 0, bob);
  }

  function test_borrowNative_revertsWith_InvalidReserveId() public {
    uint256 borrowAmount = 5e18;

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidReserveId.selector);
    wrappedTokenGateway.borrowNative(wethReserveId + 1, borrowAmount, bob);
  }

  function test_borrowNative_revertsWith_InvalidAddress() public {
    uint256 borrowAmount = 5e18;

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidAddress.selector);
    wrappedTokenGateway.borrowNative(wethReserveId, borrowAmount, address(0));
  }

  // Taken from SpokeBase.t.sol
  function _getExpectedPremiumDelta(
    ISpoke spoke1,
    address user,
    uint256 reserveId,
    uint256 repayAmount
  ) internal returns (DataTypes.PremiumDelta memory) {
    DataTypes.UserPosition memory userPosition = spoke1.getUserPosition(reserveId, user);
    Debts memory userDebt = getUserDebt(spoke1, user, reserveId);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    DataTypes.PremiumDelta memory expectedPremiumDelta = DataTypes.PremiumDelta({
      sharesDelta: -int256(uint256(userPosition.premiumShares)),
      offsetDelta: -int256(uint256(userPosition.premiumOffset)),
      realizedDelta: 0
    });

    uint256 accruedPremium = hub1.previewRestoreByShares(assetId, userPosition.premiumShares) -
      userPosition.premiumOffset;
    (, uint256 premiumDebtRestored) = _calculateExactRestoreAmount(
      userDebt.drawnDebt,
      userDebt.premiumDebt,
      repayAmount,
      assetId
    );
    expectedPremiumDelta.realizedDelta = int256(accruedPremium) - int256(premiumDebtRestored);

    return expectedPremiumDelta;
  }

  function test_repayNative() public {
    test_repayNative_fuzz(5e18);
  }

  function test_repayNative_fuzz(uint256 repayAmount) public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    repayAmount = bound(repayAmount, 1, borrowAmount);
    deal(bob, repayAmount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, wethReserveId, alice, aliceSupplyAmount, alice);
    Utils.borrow(spoke1, wethReserveId, bob, borrowAmount, bob);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      wethAssetId
    );
    DataTypes.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDelta(
      spoke1,
      bob,
      _wethReserveId(spoke1),
      repayAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _wethReserveId(spoke1),
      address(wrappedTokenGateway),
      bob,
      hub1.convertToDrawnShares(wethAssetId, baseRestored),
      expectedPremiumDelta
    );
    vm.prank(bob);
    wrappedTokenGateway.repayNative{value: repayAmount}(wethReserveId, repayAmount);

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount - repayAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + repayAmount);
    assertEq(bob.balance, prevUserBalance - repayAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_repayNative_excessAmount() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 15e18;
    deal(bob, repayAmount);

    vm.prank(bob);
    spoke1.setUserPositionManager(address(wrappedTokenGateway), true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, wethReserveId, alice, aliceSupplyAmount, alice);
    Utils.borrow(spoke1, wethReserveId, bob, borrowAmount, bob);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      wethAssetId
    );
    DataTypes.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDelta(
      spoke1,
      bob,
      _wethReserveId(spoke1),
      repayAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _wethReserveId(spoke1),
      address(wrappedTokenGateway),
      bob,
      hub1.convertToDrawnShares(wethAssetId, baseRestored),
      expectedPremiumDelta
    );
    vm.prank(bob);
    wrappedTokenGateway.repayNative{value: repayAmount}(wethReserveId, repayAmount);

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, 0);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + borrowAmount);
    assertEq(bob.balance, prevUserBalance - borrowAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_repayNative_revertsWith_InvalidAmount() public {
    uint256 repayAmount = 5e18;
    deal(bob, repayAmount);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidAmount.selector);
    wrappedTokenGateway.repayNative{value: 0}(wethReserveId, 0);
  }

  function test_repayNative_revertsWith_InvalidReserveId() public {
    uint256 repayAmount = 5e18;
    deal(bob, repayAmount);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidReserveId.selector);
    wrappedTokenGateway.repayNative{value: repayAmount}(wethReserveId + 1, repayAmount);
  }

  function test_repayNative_revertsWith_NativeAmountMismatch() public {
    uint256 repayAmount = 5e18;
    deal(bob, repayAmount);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.NativeAmountMismatch.selector);
    wrappedTokenGateway.repayNative{value: 0}(wethReserveId, repayAmount);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.NativeAmountMismatch.selector);
    wrappedTokenGateway.repayNative{value: repayAmount / 2}(wethReserveId, repayAmount);
  }

  function test_recoverToken() public {
    uint256 lostAmount = 10e18;

    deal(address(tokenList.dai), address(wrappedTokenGateway), lostAmount);

    uint256 prevBalanceThis = tokenList.dai.balanceOf(address(this));

    vm.prank(address(ADMIN));
    wrappedTokenGateway.recoverToken(address(tokenList.dai), address(this));

    assertEq(tokenList.dai.balanceOf(address(this)), prevBalanceThis + lostAmount);
    assertEq(tokenList.dai.balanceOf(address(wrappedTokenGateway)), 0);
  }

  function test_recoverNative() public {
    uint256 lostAmount = 10e18;

    deal(address(wrappedTokenGateway), lostAmount);

    uint256 prevBalanceReceiver = address(alice).balance;

    vm.prank(address(ADMIN));
    wrappedTokenGateway.recoverNative(alice, lostAmount);

    assertEq(address(alice).balance, prevBalanceReceiver + lostAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_receive_revertsWith_ReceiveNotAllowed() public {
    deal(address(this), 1 ether);

    vm.expectRevert(IWrappedTokenGatewayV4.ReceiveNotAllowed.selector);
    address(wrappedTokenGateway).call{value: 1 ether}(new bytes(0));
  }

  function _encodeMulticallBatch(
    address user,
    uint256 userPk,
    bytes memory action
  ) internal returns (bytes[] memory) {
    bytes[] memory calls = new bytes[](3);

    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: address(wrappedTokenGateway),
      user: user,
      approve: true,
      nonce: spoke1.nonces(user),
      deadline: vm.randomUint(vm.getBlockTimestamp(), MAX_SKIP_TIME)
    });
    bytes32 digest = _getTypedDataHash(spoke1, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    calls[0] = abi.encodeCall(
      IWrappedTokenGatewayV4.setUserPositionManagerWithSig,
      (user, params.approve, params.deadline, v, r, s)
    );
    calls[1] = action;
    calls[2] = abi.encodeCall(IWrappedTokenGatewayV4.renouncePositionManagerRole, (user));
    return calls;
  }

  function test_multicall_supplyNative_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);
    (, uint256 bobPk) = makeAddrAndKey('bob');
    deal(bob, mintAmount_WETH);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAmount(wethReserveId, bob);

    assertFalse(spoke1.isPositionManager(bob, address(wrappedTokenGateway)));
    assertEq(tokenList.weth.balanceOf(address(hub1)), 0);
    assertEq(prevUserSuppliedAmount, 0);

    bytes memory action = abi.encodeCall(
      IWrappedTokenGatewayV4.supplyNative,
      (wethReserveId, amount)
    );
    bytes[] memory calls = _encodeMulticallBatch(bob, bobPk, action);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.multicall{value: amount}(calls);

    assertEq(bob.balance, prevUserBalance - amount);
    assertEq(spoke1.getUserSuppliedAmount(wethReserveId, bob), prevUserSuppliedAmount + amount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + amount);
    assertEq(address(wrappedTokenGateway).balance, 0);

    assertFalse(spoke1.isPositionManager(bob, address(wrappedTokenGateway)));
  }

  function test_multicall_withdrawNative_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);
    (, uint256 bobPk) = makeAddrAndKey('bob');

    Utils.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: mintAmount_WETH,
      onBehalfOf: bob
    });
    uint256 expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, mintAmount_WETH);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke1.getUserSuppliedAmount(wethReserveId, bob);

    assertEq(spoke1.getUserSuppliedShares(wethReserveId, bob), expectedSupplyShares);

    bytes memory action = abi.encodeCall(
      IWrappedTokenGatewayV4.withdrawNative,
      (wethReserveId, amount, bob)
    );
    bytes[] memory calls = _encodeMulticallBatch(bob, bobPk, action);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.multicall(calls);

    assertEq(bob.balance, prevUserBalance + amount);
    assertEq(spoke1.getUserSuppliedAmount(wethReserveId, bob), prevUserSuppliedAmount - amount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - amount);
    assertEq(address(wrappedTokenGateway).balance, 0);

    assertFalse(spoke1.isPositionManager(bob, address(wrappedTokenGateway)));
  }

  function test_multicall_borrowNative_fuzz(uint256 borrowAmount) public {
    (, uint256 bobPk) = makeAddrAndKey('bob');
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    borrowAmount = bound(borrowAmount, 1, aliceSupplyAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, wethReserveId, alice, aliceSupplyAmount, alice);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    bytes memory action = abi.encodeCall(
      IWrappedTokenGatewayV4.borrowNative,
      (wethReserveId, borrowAmount, bob)
    );
    bytes[] memory calls = _encodeMulticallBatch(bob, bobPk, action);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      wethReserveId,
      address(wrappedTokenGateway),
      bob,
      hub1.convertToDrawnShares(wethAssetId, borrowAmount)
    );
    vm.prank(bob);
    wrappedTokenGateway.multicall(calls);

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - borrowAmount);
    assertEq(bob.balance, prevUserBalance + borrowAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);

    assertFalse(spoke1.isPositionManager(bob, address(wrappedTokenGateway)));
  }

  function test_multicall_repayNative_fuzz(uint256 repayAmount) public {
    (, uint256 bobPk) = makeAddrAndKey('bob');

    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    repayAmount = bound(repayAmount, 1, borrowAmount);
    deal(bob, repayAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, wethReserveId, alice, aliceSupplyAmount, alice);
    Utils.borrow(spoke1, wethReserveId, bob, borrowAmount, bob);

    uint256 prevUserBalance = bob.balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      wethAssetId
    );
    DataTypes.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDelta(
      spoke1,
      bob,
      _wethReserveId(spoke1),
      repayAmount
    );

    bytes memory action = abi.encodeCall(
      IWrappedTokenGatewayV4.repayNative,
      (wethReserveId, repayAmount)
    );
    bytes[] memory calls = _encodeMulticallBatch(bob, bobPk, action);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      _wethReserveId(spoke1),
      address(wrappedTokenGateway),
      bob,
      hub1.convertToDrawnShares(wethAssetId, baseRestored),
      expectedPremiumDelta
    );
    vm.prank(bob);
    wrappedTokenGateway.multicall{value: repayAmount}(calls);

    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount - repayAmount);
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + repayAmount);
    assertEq(bob.balance, prevUserBalance - repayAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);

    assertFalse(spoke1.isPositionManager(bob, address(wrappedTokenGateway)));
  }
}
