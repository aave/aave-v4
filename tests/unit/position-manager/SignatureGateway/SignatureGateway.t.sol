// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/position-manager/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGatewayTest is SignatureGatewayBaseTest {
  using SafeCast for *;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);

    assertTrue(spoke1.isPositionManagerActive(address(gateway)));
    assertTrue(spoke1.isPositionManager(alice, address(gateway)));
  }

  function test_useNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(gateway));
    address user = vm.randomAddress();
    uint192 nonceKey = vm.randomUint(0, type(uint192).max).toUint192();

    (, uint64 nonce) = _unpackNonce(gateway.nonces(user, nonceKey));

    vm.prank(user);
    gateway.useNonce(nonceKey);

    // prettier-ignore
    unchecked { ++nonce; }
    assertEq(gateway.nonces(user, nonceKey), _packNonce(nonceKey, nonce));
  }

  function test_renouncePositionManagerRole_revertsWith_OnlyOwner() public {
    address caller = vm.randomAddress();
    while (caller == ADMIN) caller = vm.randomAddress();

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    gateway.renouncePositionManagerRole(address(spoke1), alice);
  }

  function test_renouncePositionManagerRole() public {
    address user = vm.randomAddress();
    vm.expectCall(address(spoke1), abi.encodeCall(ISpoke.renouncePositionManagerRole, (user)));
    vm.prank(ADMIN);
    gateway.renouncePositionManagerRole(address(spoke1), user);
  }

  function test_supplyWithSig() public {
    ISignatureGateway.Supply memory p = _supplyData(spoke1, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);

    uint256 shares = _hub(spoke1, p.reserveId).previewAddByAssets(
      _reserveAssetId(spoke1, p.reserveId),
      p.amount
    );

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(p.reserveId, address(gateway), alice, shares, p.amount);

    vm.prank(vm.randomAddress());
    (returnValues.shares, returnValues.amount) = gateway.supplyWithSig(p, signature);

    assertEq(returnValues.shares, shares);
    assertEq(returnValues.amount, p.amount);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_withdrawWithSig() public {
    ISignatureGateway.Withdraw memory p = _withdrawData(spoke1, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    Utils.supply(spoke1, p.reserveId, alice, p.amount + 1, alice);

    uint256 shares = _hub(spoke1, p.reserveId).previewRemoveByAssets(
      _reserveAssetId(spoke1, p.reserveId),
      p.amount
    );
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(p.reserveId, address(gateway), alice, shares, p.amount);

    vm.prank(vm.randomAddress());
    (returnValues.shares, returnValues.amount) = gateway.withdrawWithSig(p, signature);

    assertEq(returnValues.shares, shares);
    assertEq(returnValues.amount, p.amount);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_borrowWithSig() public {
    ISignatureGateway.Borrow memory p = _borrowData(spoke1, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    p.reserveId = _daiReserveId(spoke1);
    p.amount = 1e18;
    Utils.supplyCollateral(spoke1, p.reserveId, alice, p.amount * 2, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    uint256 shares = _hub(spoke1, p.reserveId).previewDrawByAssets(
      _reserveAssetId(spoke1, p.reserveId),
      p.amount
    );
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow(p.reserveId, address(gateway), alice, shares, p.amount);

    vm.prank(vm.randomAddress());
    (returnValues.shares, returnValues.amount) = gateway.borrowWithSig(p, signature);

    assertEq(returnValues.shares, shares);
    assertEq(returnValues.amount, p.amount);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_repayWithSig() public {
    ISignatureGateway.Repay memory p = _repayData(spoke1, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    p.reserveId = _daiReserveId(spoke1);
    p.amount = 1e18;
    Utils.supplyCollateral(spoke1, p.reserveId, alice, p.amount * 2, alice);
    Utils.borrow(spoke1, p.reserveId, alice, p.amount, alice);
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      spoke1,
      p.reserveId,
      alice,
      p.amount
    );
    uint256 shares = _hub(spoke1, p.reserveId).previewRestoreByAssets(
      _reserveAssetId(spoke1, p.reserveId),
      baseRestored
    );
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      p.reserveId,
      address(gateway),
      alice,
      shares,
      baseRestored + premiumRestored,
      _getExpectedPremiumDelta(spoke1, alice, p.reserveId, premiumRestored)
    );

    vm.prank(vm.randomAddress());
    (returnValues.shares, returnValues.amount) = gateway.repayWithSig(p, signature);

    assertEq(returnValues.shares, shares);
    assertEq(returnValues.amount, p.amount);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_setUsingAsCollateralWithSig() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    ISignatureGateway.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, alice, deadline);
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    p.reserveId = _daiReserveId(spoke1);
    Utils.supplyCollateral(spoke1, p.reserveId, alice, 1e18, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    if (_isUsingAsCollateral(spoke1, p.reserveId, alice) != p.useAsCollateral) {
      vm.expectEmit(address(spoke1));
      emit ISpoke.SetUsingAsCollateral(p.reserveId, address(gateway), alice, p.useAsCollateral);
    }

    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(p, signature);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_updateUserRiskPremiumWithSig() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    ISignatureGateway.UpdateUserRiskPremium memory p = _updateRiskPremiumData(
      spoke1,
      alice,
      deadline
    );
    p.nonce = _burnRandomNoncesAtKey(gateway, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 10e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 7e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(alice, _calculateExpectedUserRP(spoke1, alice));

    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p, signature);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_updateUserDynamicConfigWithSig() public {
    ISignatureGateway.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(gateway, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);

    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p, signature);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(address(gateway), true);

    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      updates: updates,
      onBehalfOf: alice,
      nonce: spoke1.nonces(address(alice), _randomNonceKey()), // note: this typed sig is forwarded to spoke
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(alice, address(gateway), p.updates[0].approve);

    vm.prank(vm.randomAddress());
    gateway.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke1),
      onBehalfOf: p.onBehalfOf,
      approve: p.updates[0].approve,
      nonce: p.nonce,
      deadline: p.deadline,
      signature: signature
    });

    _assertNonceIncrement(ISignatureGateway(address(spoke1)), alice, p.nonce); // note: nonce consumed on spoke
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_multicall() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);

    ISignatureGateway.Supply memory p = _supplyData(spoke1, alice, deadline);
    p.reserveId = reserveId;
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);

    uint256 expectedShares = _hub(spoke1, reserveId).previewAddByAssets(
      _reserveAssetId(spoke1, reserveId),
      p.amount
    );

    ISignatureGateway.SetUsingAsCollateral memory p2 = _setAsCollateralData(
      spoke1,
      alice,
      deadline
    );
    p2.nonce = _getNextNoncePacked(p.nonce);
    p2.reserveId = reserveId;
    bytes memory signature2 = _sign(alicePk, _getTypedDataHash(gateway, p2));

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(gateway.supplyWithSig, (p, signature));
    calls[1] = abi.encodeCall(gateway.setUsingAsCollateralWithSig, (p2, signature2));

    bytes[] memory res = gateway.multicall(calls);

    (uint256 returnedShares, uint256 returnedAmount) = abi.decode(res[0], (uint256, uint256));
    assertEq(returnedShares, expectedShares);
    assertEq(returnedAmount, p.amount);
    assertEq(res[1].length, 0); // setUsingAsCollateralWithSig has no return values

    _assertNonceIncrement(gateway, alice, p2.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  /// @dev We expect the multicall to revert due to the supplyWithSig() call being invalid because it was executed before the multicall.
  function test_multicall_atomicity_on_revert() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);

    ISignatureGateway.Supply memory p1 = _supplyData(spoke1, alice, deadline);
    p1.reserveId = reserveId;
    p1.nonce = _burnRandomNoncesAtKey(gateway, p1.onBehalfOf);
    bytes memory sig1 = _sign(alicePk, _getTypedDataHash(gateway, p1));
    Utils.approve(spoke1, p1.reserveId, alice, address(gateway), p1.amount);

    ISignatureGateway.SetUsingAsCollateral memory p2 = _setAsCollateralData(
      spoke1,
      alice,
      deadline
    );
    p2.reserveId = reserveId;
    p2.nonce = _getNextNoncePacked(p1.nonce);
    bytes memory sig2 = _sign(alicePk, _getTypedDataHash(gateway, p2));

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(gateway.supplyWithSig, (p1, sig1));
    calls[1] = abi.encodeCall(gateway.setUsingAsCollateralWithSig, (p2, sig2));

    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p1, sig1);

    uint256 balanceBefore = _underlying(spoke1, reserveId).balanceOf(alice);

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, alice, p2.nonce)
    );
    gateway.multicall(calls);

    assertEq(_underlying(spoke1, reserveId).balanceOf(alice), balanceBefore);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  /// @dev We expect the multicall not to revert, even if the call permitReserveUnderlying() is invalid, due to the use of try/catch.
  function test_multicall_no_atomicity_with_trycatch() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);

    ISignatureGateway.Supply memory p = _supplyData(spoke1, alice, deadline);
    p.reserveId = reserveId;
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);

    uint256 expectedShares = _hub(spoke1, reserveId).previewAddByAssets(
      _reserveAssetId(spoke1, reserveId),
      p.amount
    );

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(
      gateway.permitReserveUnderlying,
      (address(spoke1), reserveId, alice, 100e18, deadline, uint8(0), bytes32(0), bytes32(0))
    );
    calls[1] = abi.encodeCall(gateway.supplyWithSig, (p, signature));

    bytes[] memory res = gateway.multicall(calls);

    assertEq(res[0].length, 0);
    (uint256 returnedShares, uint256 returnedAmount) = abi.decode(res[1], (uint256, uint256));
    assertEq(returnedShares, expectedShares);
    assertEq(returnedAmount, p.amount);

    assertEq(_underlying(spoke1, reserveId).allowance(alice, address(gateway)), 0);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }
}
