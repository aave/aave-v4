// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

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
    address who = vm.randomAddress();
    vm.expectCall(address(spoke1), abi.encodeCall(ISpoke.renouncePositionManagerRole, (who)));
    vm.prank(ADMIN);
    gateway.renouncePositionManagerRole(address(spoke1), who);
  }

  function test_supplyWithSig() public {
    EIP712Types.Supply memory p = _supplyData(spoke1, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);

    uint256 shares = _hub(spoke1, p.reserveId).previewAddByAssets(
      _spokeAssetId(spoke1, p.reserveId),
      p.amount
    );

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(p.reserveId, address(gateway), alice, shares, p.amount);

    vm.prank(vm.randomAddress());
    (returnValues.shares, returnValues.amount) = gateway.supplyWithSig(p, signature);

    assertEq(returnValues.shares, shares);
    assertEq(returnValues.amount, p.amount);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_withdrawWithSig() public {
    EIP712Types.Withdraw memory p = _withdrawData(spoke1, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    Utils.supply(spoke1, p.reserveId, alice, p.amount + 1, alice);

    uint256 shares = _hub(spoke1, p.reserveId).previewRemoveByAssets(
      _spokeAssetId(spoke1, p.reserveId),
      p.amount
    );
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(p.reserveId, address(gateway), alice, shares, p.amount);

    vm.prank(vm.randomAddress());
    (returnValues.shares, returnValues.amount) = gateway.withdrawWithSig(p, signature);

    assertEq(returnValues.shares, shares);
    assertEq(returnValues.amount, p.amount);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_borrowWithSig() public {
    EIP712Types.Borrow memory p = _borrowData(spoke1, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf);
    p.reserveId = _daiReserveId(spoke1);
    p.amount = 1e18;
    Utils.supplyCollateral(spoke1, p.reserveId, alice, p.amount * 2, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    uint256 shares = _hub(spoke1, p.reserveId).previewDrawByAssets(
      _spokeAssetId(spoke1, p.reserveId),
      p.amount
    );
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(p.reserveId, address(gateway), alice, shares, p.amount);

    vm.prank(vm.randomAddress());
    (returnValues.shares, returnValues.amount) = gateway.borrowWithSig(p, signature);

    assertEq(returnValues.shares, shares);
    assertEq(returnValues.amount, p.amount);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_repayWithSig() public {
    EIP712Types.Repay memory p = _repayData(spoke1, alice, _warpBeforeRandomDeadline());
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
      _spokeAssetId(spoke1, p.reserveId),
      baseRestored
    );
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
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
    EIP712Types.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, alice, deadline);
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
    EIP712Types.UpdateUserRiskPremium memory p = _updateRiskPremiumData(spoke1, alice, deadline);
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
    EIP712Types.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
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
    EIP712Types.SetUserPositionManager memory p = EIP712Types.SetUserPositionManager({
      positionManager: address(gateway),
      user: alice,
      approve: true,
      nonce: spoke1.nonces(address(alice), _randomNonceKey()), // note: this typed sig is forwarded to spoke
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(alice, address(gateway), p.approve);

    vm.prank(vm.randomAddress());
    gateway.setSelfAsUserPositionManagerWithSig(address(spoke1), p, signature);

    _assertNonceIncrement(ISignatureGateway(address(spoke1)), alice, p.nonce); // note: nonce consumed on spoke
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }
}
