// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';

contract WrappedTokenGatewayV4Test is Base {
  WrappedTokenGatewayV4 public wrappedTokenGateway;
  ISpoke public spoke;
  uint256 public wethReserveId;

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();

    spoke = ISpoke(address(spoke1));

    wethReserveId = wethReserveId;

    wrappedTokenGateway = new WrappedTokenGatewayV4(
      address(tokenList.weth),
      address(spoke),
      address(accessManager)
    );

    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(address(wrappedTokenGateway), true);

    deal(address(tokenList.weth), 1e36);
  }

  function _getUserData(address user) internal view returns (DataTypes.UserPosition memory) {
    return getUserInfo(spoke, user, wethReserveId);
  }

  function test_constructor() public {
    WrappedTokenGatewayV4 gateway = new WrappedTokenGatewayV4(
      address(tokenList.weth),
      address(spoke),
      address(ADMIN)
    );

    assertEq(address(gateway.WRAPPED_ASSET()), address(tokenList.weth));
    assertEq(address(gateway.SPOKE()), address(spoke));
  }

  function test_setUserPositionManagerWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');

    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: address(wrappedTokenGateway),
      user: user,
      approve: vm.randomBool(),
      nonce: spoke.nonces(user),
      deadline: vm.randomUint(vm.getBlockTimestamp(), MAX_SKIP_TIME)
    });
    bytes32 digest = _getTypedDataHash(spoke, params);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    wrappedTokenGateway.setUserPositionManagerWithSig(
      user,
      params.approve,
      params.deadline,
      v,
      r,
      s
    );

    assertEq(spoke.isPositionManager(user, address(wrappedTokenGateway)), params.approve);
  }

  function test_setUserPositionManagerWithSig_revertsWith_AddressZero() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));

    EIP712Types.SetUserPositionManager memory params = EIP712Types.SetUserPositionManager({
      positionManager: address(wrappedTokenGateway),
      user: user,
      approve: vm.randomBool(),
      nonce: spoke.nonces(user),
      deadline: vm.randomUint(vm.getBlockTimestamp(), MAX_SKIP_TIME)
    });
    bytes32 digest = _getTypedDataHash(spoke, params);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    vm.expectRevert(IWrappedTokenGatewayV4.AddressZero.selector);
    wrappedTokenGateway.setUserPositionManagerWithSig(
      address(0),
      params.approve,
      params.deadline,
      v,
      r,
      s
    );
  }

  function test_supplyNative() public {
    uint256 amount = 100e18;
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    DataTypes.UserPosition memory prevUserData = _getUserData(bob);
    DataTypes.UserPosition memory prevGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory prevReserveData = getSpokePosition(spoke, wethReserveId);

    // weth balance
    assertEq(tokenList.weth.balanceOf(address(hub1)), 0);
    assertEq(tokenList.weth.balanceOf(address(spoke)), 0);

    // user
    assertEq(prevUserData.suppliedShares, 0);
    // wrappedTokenGateway
    assertEq(prevGatewayData.suppliedShares, 0);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Supply(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.supplyNative{value: amount}(wethReserveId, amount, bob);

    DataTypes.UserPosition memory finalUserData = _getUserData(bob);
    DataTypes.UserPosition memory finalGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory finalReserveData = getSpokePosition(spoke, wethReserveId);

    // weth balance
    assertEq(tokenList.weth.balanceOf(address(hub1)), amount, 'hub token balance after-supply');
    assertEq(tokenList.weth.balanceOf(address(spoke)), 0, 'spoke token balance after-supply');
    // reserve
    assertEq(
      finalReserveData.addedShares,
      hub1.convertToAddedShares(wethAssetId, amount),
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub1.getSpokeAddedAmount(wethAssetId, address(spoke)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub1.getAssetAddedAmount(wethAssetId), 'asset supplied amount after-supply');
    // user
    assertEq(
      finalUserData.suppliedShares,
      hub1.convertToAddedShares(wethAssetId, amount),
      'bob suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke.getUserSuppliedAmount(wethReserveId, bob),
      'user supplied amount after-supply'
    );

    // wrappedTokenGateway
    assertEq(
      finalGatewayData.suppliedShares,
      0,
      'wrappedTokenGateway supplied amount after-supply'
    );

    // native balances
    assertEq(address(bob).balance, mintAmount_WETH - amount, 'user native balance after-supply');
    assertEq(
      address(wrappedTokenGateway).balance,
      0,
      'wrappedTokenGateway native balance after-supply'
    );
  }

  function test_supplyNative_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    DataTypes.UserPosition memory prevUserData = _getUserData(bob);
    DataTypes.UserPosition memory prevGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory prevReserveData = getSpokePosition(spoke, wethReserveId);

    // weth balance
    assertEq(tokenList.weth.balanceOf(address(hub1)), 0);
    assertEq(tokenList.weth.balanceOf(address(spoke)), 0);

    // user
    assertEq(prevUserData.suppliedShares, 0);
    // wrappedTokenGateway
    assertEq(prevGatewayData.suppliedShares, 0);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Supply(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.supplyNative{value: amount}(wethReserveId, amount, bob);

    DataTypes.UserPosition memory finalUserData = _getUserData(bob);
    DataTypes.UserPosition memory finalGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory finalReserveData = getSpokePosition(spoke, wethReserveId);

    // weth balance
    assertEq(tokenList.weth.balanceOf(address(hub1)), amount, 'hub token balance after-supply');
    assertEq(tokenList.weth.balanceOf(address(spoke)), 0, 'spoke token balance after-supply');
    // reserve
    assertEq(
      finalReserveData.addedShares,
      hub1.convertToAddedShares(wethAssetId, amount),
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub1.getSpokeAddedAmount(wethAssetId, address(spoke)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub1.getAssetAddedAmount(wethAssetId), 'asset supplied amount after-supply');
    // user
    assertEq(
      finalUserData.suppliedShares,
      hub1.convertToAddedShares(wethAssetId, amount),
      'bob suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke.getUserSuppliedAmount(wethReserveId, bob),
      'user supplied amount after-supply'
    );

    // wrappedTokenGateway
    assertEq(
      finalGatewayData.suppliedShares,
      0,
      'wrappedTokenGateway supplied amount after-supply'
    );

    // native balances
    assertEq(address(bob).balance, mintAmount_WETH - amount, 'user native balance after-supply');
    assertEq(
      address(wrappedTokenGateway).balance,
      0,
      'wrappedTokenGateway native balance after-supply'
    );
  }

  function test_supplyNative_revertsWith_AmountNull() public {
    uint256 amount = 100e18;
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.AmountNull.selector);
    wrappedTokenGateway.supplyNative{value: 0}(wethReserveId, 0, bob);
  }

  function test_supplyNative_revertsWith_AddressZero() public {
    uint256 amount = 100e18;
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.AddressZero.selector);
    wrappedTokenGateway.supplyNative{value: amount}(wethReserveId, amount, address(0));
  }

  function test_supplyNative_revertsWith_InvalidReserveId() public {
    uint256 amount = 100e18;
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidReserveId.selector);
    wrappedTokenGateway.supplyNative{value: amount}(wethReserveId + 1, amount, bob);
  }

  function test_supplyNative_revertsWith_NativeAmountMismatch() public {
    uint256 amount = 100e18;
    deal(bob, mintAmount_WETH);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.NativeAmountMismatch.selector);
    wrappedTokenGateway.supplyNative{value: 0}(wethReserveId, amount, bob);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.NativeAmountMismatch.selector);
    wrappedTokenGateway.supplyNative{value: amount / 2}(wethReserveId, amount, bob);
  }

  struct WithdrawLocalVars {
    uint256 expectedSupplyShares;
    uint256 prevUserSuppliedAmount;
    uint256 prevHubBalance;
    uint256 prevSpokeBalance;
    uint256 prevHubAddedAmount;
    uint256 prevSpokeSupplied;
  }

  function test_withdrawNative() public {
    uint256 amount = 100e18;
    WithdrawLocalVars memory vars;

    // Bob supplies WETH
    Utils.supply({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });
    vars.expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, amount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    DataTypes.UserPosition memory prevUserData = _getUserData(bob);
    DataTypes.UserPosition memory prevGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory prevReserveData = getSpokePosition(spoke, wethReserveId);

    vars.prevUserSuppliedAmount = spoke.getUserSuppliedAmount(wethReserveId, bob);

    vars.prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    vars.prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    vars.prevHubAddedAmount = hub1.getAssetAddedAmount(wethAssetId);
    vars.prevSpokeSupplied = hub1.getSpokeAddedAmount(wethAssetId, address(spoke));

    // user
    assertEq(prevUserData.suppliedShares, vars.expectedSupplyShares);
    // wrappedTokenGateway
    assertEq(prevGatewayData.suppliedShares, 0);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Withdraw(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.withdrawNative(wethReserveId, amount, bob);

    DataTypes.UserPosition memory finalUserData = _getUserData(bob);
    DataTypes.UserPosition memory finalGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory finalReserveData = getSpokePosition(spoke, wethReserveId);

    // weth balance
    assertEq(
      tokenList.weth.balanceOf(address(hub1)),
      vars.prevHubBalance - amount,
      'hub token balance after-withdraw'
    );
    assertEq(
      tokenList.weth.balanceOf(address(spoke)),
      vars.prevSpokeBalance,
      'spoke token balance after-withdraw'
    );
    // reserve
    assertEq(
      finalReserveData.addedShares,
      prevReserveData.addedShares - hub1.convertToAddedShares(wethAssetId, amount),
      'reserve suppliedShares after-withdraw'
    );
    assertEq(
      vars.prevSpokeSupplied - amount,
      hub1.getSpokeAddedAmount(wethAssetId, address(spoke)),
      'spoke supplied amount after-withdraw'
    );
    assertEq(
      vars.prevHubAddedAmount - amount,
      hub1.getAssetAddedAmount(wethAssetId),
      'asset supplied amount after-withdraw'
    );
    // user
    assertEq(
      finalUserData.suppliedShares,
      prevUserData.suppliedShares - hub1.convertToAddedShares(wethAssetId, amount),
      'bob suppliedShares after-withdraw'
    );
    assertEq(
      vars.prevUserSuppliedAmount - amount,
      spoke.getUserSuppliedAmount(wethReserveId, bob),
      'user supplied amount after-withdraw'
    );

    // wrappedTokenGateway
    assertEq(
      finalGatewayData.suppliedShares,
      0,
      'wrappedTokenGateway supplied amount after-withdraw'
    );

    // native balances
    assertEq(address(bob).balance, amount, 'user native balance after-withdraw');
    assertEq(
      address(wrappedTokenGateway).balance,
      0,
      'wrappedTokenGateway native balance after-withdraw'
    );
  }

  function test_withdrawNative_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_WETH);
    WithdrawLocalVars memory vars;

    // Bob supplies WETH
    Utils.supply({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: mintAmount_WETH,
      onBehalfOf: bob
    });
    vars.expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, mintAmount_WETH);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    DataTypes.UserPosition memory prevUserData = _getUserData(bob);
    DataTypes.UserPosition memory prevGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory prevReserveData = getSpokePosition(spoke, wethReserveId);

    vars.prevUserSuppliedAmount = spoke.getUserSuppliedAmount(wethReserveId, bob);

    vars.prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    vars.prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    vars.prevHubAddedAmount = hub1.getAssetAddedAmount(wethAssetId);
    vars.prevSpokeSupplied = hub1.getSpokeAddedAmount(wethAssetId, address(spoke));

    // user
    assertEq(prevUserData.suppliedShares, vars.expectedSupplyShares);
    // wrappedTokenGateway
    assertEq(prevGatewayData.suppliedShares, 0);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Withdraw(wethReserveId, address(wrappedTokenGateway), bob, amount);
    vm.prank(bob);
    wrappedTokenGateway.withdrawNative(wethReserveId, amount, bob);

    DataTypes.UserPosition memory finalUserData = _getUserData(bob);
    DataTypes.UserPosition memory finalGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory finalReserveData = getSpokePosition(spoke, wethReserveId);

    // weth balance
    assertEq(
      tokenList.weth.balanceOf(address(hub1)),
      vars.prevHubBalance - amount,
      'hub token balance after-withdraw'
    );
    assertEq(
      tokenList.weth.balanceOf(address(spoke)),
      vars.prevSpokeBalance,
      'spoke token balance after-withdraw'
    );
    // reserve
    assertEq(
      finalReserveData.addedShares,
      prevReserveData.addedShares - hub1.convertToAddedShares(wethAssetId, amount),
      'reserve suppliedShares after-withdraw'
    );
    assertEq(
      vars.prevSpokeSupplied - amount,
      hub1.getSpokeAddedAmount(wethAssetId, address(spoke)),
      'spoke supplied amount after-withdraw'
    );
    assertEq(
      vars.prevHubAddedAmount - amount,
      hub1.getAssetAddedAmount(wethAssetId),
      'asset supplied amount after-withdraw'
    );
    // user
    assertEq(
      finalUserData.suppliedShares,
      prevUserData.suppliedShares - hub1.convertToAddedShares(wethAssetId, amount),
      'bob suppliedShares after-withdraw'
    );
    assertEq(
      vars.prevUserSuppliedAmount - amount,
      spoke.getUserSuppliedAmount(wethReserveId, bob),
      'user supplied amount after-withdraw'
    );

    // wrappedTokenGateway
    assertEq(
      finalGatewayData.suppliedShares,
      0,
      'wrappedTokenGateway supplied amount after-withdraw'
    );

    // native balances
    assertEq(address(bob).balance, amount, 'user native balance after-withdraw');
    assertEq(
      address(wrappedTokenGateway).balance,
      0,
      'wrappedTokenGateway native balance after-withdraw'
    );
  }

  function test_withdrawNative_fuzz_allBalance(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, mintAmount_WETH);
    WithdrawLocalVars memory vars;

    // Bob supplies WETH
    Utils.supply({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    vars.expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, supplyAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    DataTypes.UserPosition memory prevUserData = _getUserData(bob);
    DataTypes.UserPosition memory prevGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory prevReserveData = getSpokePosition(spoke, wethReserveId);

    vars.prevUserSuppliedAmount = spoke.getUserSuppliedAmount(wethReserveId, bob);

    vars.prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    vars.prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    vars.prevHubAddedAmount = hub1.getAssetAddedAmount(wethAssetId);
    vars.prevSpokeSupplied = hub1.getSpokeAddedAmount(wethAssetId, address(spoke));

    // user
    assertEq(prevUserData.suppliedShares, vars.expectedSupplyShares);
    // wrappedTokenGateway
    assertEq(prevGatewayData.suppliedShares, 0);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Withdraw(wethReserveId, address(wrappedTokenGateway), bob, supplyAmount);
    vm.prank(bob);
    wrappedTokenGateway.withdrawNative(wethReserveId, UINT256_MAX, bob);

    DataTypes.UserPosition memory finalUserData = _getUserData(bob);
    DataTypes.UserPosition memory finalGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory finalReserveData = getSpokePosition(spoke, wethReserveId);

    // weth balance
    assertEq(
      tokenList.weth.balanceOf(address(hub1)),
      vars.prevHubBalance - supplyAmount,
      'hub token balance after-withdraw'
    );
    assertEq(
      tokenList.weth.balanceOf(address(spoke)),
      vars.prevSpokeBalance,
      'spoke token balance after-withdraw'
    );
    // reserve
    assertEq(
      finalReserveData.addedShares,
      prevReserveData.addedShares - hub1.convertToAddedShares(wethAssetId, supplyAmount),
      'reserve suppliedShares after-withdraw'
    );
    assertEq(
      vars.prevSpokeSupplied - supplyAmount,
      hub1.getSpokeAddedAmount(wethAssetId, address(spoke)),
      'spoke supplied amount after-withdraw'
    );
    assertEq(
      vars.prevHubAddedAmount - supplyAmount,
      hub1.getAssetAddedAmount(wethAssetId),
      'asset supplied amount after-withdraw'
    );
    // user
    assertEq(
      finalUserData.suppliedShares,
      prevUserData.suppliedShares - hub1.convertToAddedShares(wethAssetId, supplyAmount),
      'bob suppliedShares after-withdraw'
    );
    assertEq(
      vars.prevUserSuppliedAmount - supplyAmount,
      spoke.getUserSuppliedAmount(wethReserveId, bob),
      'user supplied amount after-withdraw'
    );

    // wrappedTokenGateway
    assertEq(
      finalGatewayData.suppliedShares,
      0,
      'wrappedTokenGateway supplied amount after-withdraw'
    );

    // native balances
    assertEq(address(bob).balance, supplyAmount, 'user native balance after-withdraw');
    assertEq(
      address(wrappedTokenGateway).balance,
      0,
      'wrappedTokenGateway native balance after-withdraw'
    );
  }

  function test_withdrawNative_fuzz_allBalanceWithInterest(uint256 supplyAmount, uint256 borrowAmount) public {
    supplyAmount = bound(supplyAmount, 2, mintAmount_WETH);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    WithdrawLocalVars memory vars;

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supplies WETH
    Utils.supplyCollateral({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    vars.expectedSupplyShares = hub1.convertToAddedShares(wethAssetId, supplyAmount);

    // Bob borrows weth
    Utils.borrow({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    skip(365 days);
    vm.assume(hub1.getAssetAddedAmount(wethAssetId) > supplyAmount);
    uint256 repayAmount = spoke.getReserveTotalDebt(_wethReserveId(spoke));
    deal(address(tokenList.weth), bob, repayAmount);

    Utils.repay({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    uint256 expectedWithdrawAmount = spoke.getUserSuppliedAmount(wethReserveId, bob);

    DataTypes.UserPosition memory prevUserData = _getUserData(bob);
    DataTypes.UserPosition memory prevGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory prevReserveData = getSpokePosition(spoke, wethReserveId);

    vars.prevUserSuppliedAmount = spoke.getUserSuppliedAmount(wethReserveId, bob);

    vars.prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    vars.prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    vars.prevHubAddedAmount = hub1.getAssetAddedAmount(wethAssetId);
    vars.prevSpokeSupplied = hub1.getSpokeAddedAmount(wethAssetId, address(spoke));

    // user
    assertEq(prevUserData.suppliedShares, vars.expectedSupplyShares);
    // wrappedTokenGateway
    assertEq(prevGatewayData.suppliedShares, 0);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Withdraw(wethReserveId, address(wrappedTokenGateway), bob, vars.expectedSupplyShares);
    vm.prank(bob);
    wrappedTokenGateway.withdrawNative(wethReserveId, UINT256_MAX, bob);

    // treasury spoke withdraw fees
    //withdrawLiquidityFees(wethAssetId, UINT256_MAX);

    DataTypes.UserPosition memory finalUserData = _getUserData(bob);
    DataTypes.UserPosition memory finalGatewayData = _getUserData(address(wrappedTokenGateway));
    SpokePosition memory finalReserveData = getSpokePosition(spoke, wethReserveId);

    // weth balance
    assertEq(
      tokenList.weth.balanceOf(address(hub1)),
      vars.prevHubBalance - expectedWithdrawAmount,
      'hub token balance after-withdraw'
    );
    assertEq(
      tokenList.weth.balanceOf(address(spoke)),
      vars.prevSpokeBalance,
      'spoke token balance after-withdraw'
    );
    // reserve
    assertEq(
      finalReserveData.addedShares,
      prevReserveData.addedShares - vars.expectedSupplyShares,
      'reserve suppliedShares after-withdraw'
    );
    assertEq(
      vars.prevSpokeSupplied - expectedWithdrawAmount,
      hub1.getSpokeAddedAmount(wethAssetId, address(spoke)),
      'spoke supplied amount after-withdraw'
    );
    // user
    assertEq(
      finalUserData.suppliedShares,
      prevUserData.suppliedShares - vars.expectedSupplyShares,
      'bob suppliedShares after-withdraw'
    );
    assertEq(
      vars.prevUserSuppliedAmount - expectedWithdrawAmount,
      spoke.getUserSuppliedAmount(wethReserveId, bob),
      'user supplied amount after-withdraw'
    );

    // wrappedTokenGateway
    assertEq(
      finalGatewayData.suppliedShares,
      0,
      'wrappedTokenGateway supplied amount after-withdraw'
    );

    // native balances
    assertEq(address(bob).balance, expectedWithdrawAmount, 'user native balance after-withdraw');
    assertEq(
      address(wrappedTokenGateway).balance,
      0,
      'wrappedTokenGateway native balance after-withdraw'
    );
  }

  function test_withdrawNative_revertsWith_AmountNull() public {
    uint256 amount = 100e18;

    // Bob supplies WETH
    Utils.supply({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.AmountNull.selector);
    wrappedTokenGateway.withdrawNative(wethReserveId, 0, bob);
  }

  function test_withdrawNative_revertsWith_AddressZero() public {
    uint256 amount = 100e18;

    // Bob supplies WETH
    Utils.supply({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.AddressZero.selector);
    wrappedTokenGateway.withdrawNative(wethReserveId, amount, address(0));
  }

  function test_withdrawNative_revertsWith_InvalidReserveId() public {
    uint256 amount = 100e18;

    // Bob supplies WETH
    Utils.supply({
      spoke: spoke,
      reserveId: _wethReserveId(spoke),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidReserveId.selector);
    wrappedTokenGateway.withdrawNative(wethReserveId + 1, amount, bob);
  }

  function test_borrowNative() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 50000e18;
    uint256 borrowAmount = 5e18;

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);

    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);

    uint256 prevUserBalance = address(bob).balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Borrow(wethReserveId, address(wrappedTokenGateway), bob, hub1.convertToDrawnShares(wethAssetId, borrowAmount));
    vm.prank(bob);
    wrappedTokenGateway.borrowNative(wethReserveId, borrowAmount, bob);
    
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount, 'user total debt after-borrow');
    assertEq(tokenList.weth.balanceOf(address(spoke)), prevSpokeBalance, 'spoke token balance after-borrow');
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - borrowAmount, 'hub token balance after-borrow');
    assertEq(address(bob).balance, prevUserBalance + borrowAmount, 'user native balance after-borrow');
    assertEq(address(wrappedTokenGateway).balance, 0, 'wrappedTokenGateway native balance after-borrow');
  }

  function test_borrowNative_fuzz(uint256 borrowAmount) public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    borrowAmount = bound(borrowAmount, 1, aliceSupplyAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);

    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);

    uint256 prevUserBalance = address(bob).balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Borrow(wethReserveId, address(wrappedTokenGateway), bob, hub1.convertToDrawnShares(wethAssetId, borrowAmount));
    vm.prank(bob);
    wrappedTokenGateway.borrowNative(wethReserveId, borrowAmount, bob);
    
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount, 'user total debt after-borrow');
    assertEq(tokenList.weth.balanceOf(address(spoke)), prevSpokeBalance, 'spoke token balance after-borrow');
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance - borrowAmount, 'hub token balance after-borrow');
    assertEq(address(bob).balance, prevUserBalance + borrowAmount, 'user native balance after-borrow');
    assertEq(address(wrappedTokenGateway).balance, 0, 'wrappedTokenGateway native balance after-borrow');
  }

  function test_borrowNative_revertsWith_AmountNull() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 50000e18;
    uint256 borrowAmount = 5e18;

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);

    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.AmountNull.selector);
    wrappedTokenGateway.borrowNative(wethReserveId, 0, bob);
  }

  function test_borrowNative_revertsWith_AddressZero() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 50000e18;
    uint256 borrowAmount = 5e18;

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);

    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.AddressZero.selector);
    wrappedTokenGateway.borrowNative(wethReserveId, borrowAmount, address(0));
  }

  function test_borrowNative_revertsWith_InvalidReserveId() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 50000e18;
    uint256 borrowAmount = 5e18;

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);

    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidReserveId.selector);
    wrappedTokenGateway.borrowNative(wethReserveId + 1, borrowAmount, bob);
  }

  function test_repayNative() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 5e18;
    deal(address(bob), repayAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);
    //Bob borrows weth
    Utils.borrow(spoke, wethReserveId, bob, borrowAmount, bob);

    uint256 prevUserBalance = address(bob).balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    /*vm.expectEmit(address(spoke));
    emit ISpokeBase.Repay(wethReserveId, address(wrappedTokenGateway), bob, hub1.convertToDrawnShares(wethAssetId, repayAmount));*/
    vm.prank(bob);
    wrappedTokenGateway.repayNative{ value: repayAmount }(wethReserveId, repayAmount, bob);
    
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount - repayAmount, 'user total debt after-repay');
    assertEq(tokenList.weth.balanceOf(address(spoke)), prevSpokeBalance, 'spoke token balance after-borrow');
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + repayAmount, 'hub token balance after-borrow');
    assertEq(address(bob).balance, prevUserBalance - repayAmount, 'user native balance after-borrow');
    assertEq(address(wrappedTokenGateway).balance, 0, 'wrappedTokenGateway native balance after-borrow');
  }

  function test_repayNative_excessAmount() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 15e18;
    deal(address(bob), repayAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);
    //Bob borrows weth
    Utils.borrow(spoke, wethReserveId, bob, borrowAmount, bob);

    uint256 prevUserBalance = address(bob).balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    /*vm.expectEmit(address(spoke));
    emit ISpokeBase.Repay(wethReserveId, address(wrappedTokenGateway), bob, hub1.convertToDrawnShares(wethAssetId, repayAmount));*/
    vm.prank(bob);
    wrappedTokenGateway.repayNative{ value: repayAmount }(wethReserveId, repayAmount, bob);
    
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, 0, 'user total debt after-repay');
    assertEq(tokenList.weth.balanceOf(address(spoke)), prevSpokeBalance, 'spoke token balance after-borrow');
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + borrowAmount, 'hub token balance after-borrow');
    assertEq(address(bob).balance, prevUserBalance - borrowAmount, 'user native balance after-borrow');
    assertEq(address(wrappedTokenGateway).balance, 0, 'wrappedTokenGateway native balance after-borrow');
  }

  function test_repayNative_fuzz(uint256 repayAmount) public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    repayAmount = bound(repayAmount, 1, borrowAmount);
    deal(address(bob), repayAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);
    //Bob borrows weth
    Utils.borrow(spoke, wethReserveId, bob, borrowAmount, bob);

    uint256 prevUserBalance = address(bob).balance;
    uint256 prevHubBalance = tokenList.weth.balanceOf(address(hub1));
    uint256 prevSpokeBalance = tokenList.weth.balanceOf(address(spoke));

    /*vm.expectEmit(address(spoke));
    emit ISpokeBase.Repay(wethReserveId, address(wrappedTokenGateway), bob, hub1.convertToDrawnShares(wethAssetId, repayAmount));*/
    vm.prank(bob);
    wrappedTokenGateway.repayNative{ value: repayAmount }(wethReserveId, repayAmount, bob);
    
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(wethReserveId, bob);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount - repayAmount, 'user total debt after-repay');
    assertEq(tokenList.weth.balanceOf(address(spoke)), prevSpokeBalance, 'spoke token balance after-borrow');
    assertEq(tokenList.weth.balanceOf(address(hub1)), prevHubBalance + repayAmount, 'hub token balance after-borrow');
    assertEq(address(bob).balance, prevUserBalance - repayAmount, 'user native balance after-borrow');
    assertEq(address(wrappedTokenGateway).balance, 0, 'wrappedTokenGateway native balance after-borrow');
  }

  function test_repayNative_revertsWith_AmountNull() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 5e18;
    deal(address(bob), repayAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);
    //Bob borrows weth
    Utils.borrow(spoke, wethReserveId, bob, borrowAmount, bob);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.AmountNull.selector);
    wrappedTokenGateway.repayNative{value: 0}(wethReserveId, 0, bob);
  }

  function test_repayNative_revertsWith_AddressZero() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 5e18;
    deal(address(bob), repayAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);
    //Bob borrows weth
    Utils.borrow(spoke, wethReserveId, bob, borrowAmount, bob);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.AddressZero.selector);
    wrappedTokenGateway.repayNative{value: repayAmount}(wethReserveId, repayAmount, address(0));
  }

  function test_repayNative_revertsWith_InvalidReserveId() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 5e18;
    deal(address(bob), repayAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);
    //Bob borrows weth
    Utils.borrow(spoke, wethReserveId, bob, borrowAmount, bob);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.InvalidReserveId.selector);
    wrappedTokenGateway.repayNative{value: repayAmount}(wethReserveId + 1, repayAmount, bob);
  }

  function test_repayNative_revertsWith_NativeAmountMismatch() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 5e18;
    deal(address(bob), repayAmount);

    vm.prank(bob);
    spoke.setUserPositionManager(address(wrappedTokenGateway), true);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    // Alice supply weth
    Utils.supply(spoke, wethReserveId, alice, aliceSupplyAmount, alice);
    //Bob borrows weth
    Utils.borrow(spoke, wethReserveId, bob, borrowAmount, bob);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.NativeAmountMismatch.selector);
    wrappedTokenGateway.repayNative{value: 0}(wethReserveId, repayAmount, bob);

    vm.prank(bob);
    vm.expectRevert(IWrappedTokenGatewayV4.NativeAmountMismatch.selector);
    wrappedTokenGateway.repayNative{value: repayAmount / 2}(wethReserveId, repayAmount, bob);
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

    uint256 prevBalanceThis = address(this).balance;

    vm.prank(address(ADMIN));
    wrappedTokenGateway.recoverNative(address(this), lostAmount);

    assertEq(address(this).balance, prevBalanceThis + lostAmount);
    assertEq(address(wrappedTokenGateway).balance, 0);
  }

  function test_receive_revertsWith_ReceiveNotAllowed() public {
    deal(address(this), 1 ether);

    vm.expectRevert(IWrappedTokenGatewayV4.ReceiveNotAllowed.selector);
    address(wrappedTokenGateway).call{value: 1 ether}(new bytes(0));
  }

  // To receive recovered native assets
  fallback() external payable {}
}
