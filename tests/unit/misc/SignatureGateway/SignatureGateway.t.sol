// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGatewayTest is SignatureGatewayBaseTest {
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

    uint256 currentNonce = gateway.nonces(user);

    vm.prank(user);
    gateway.useNonce();

    assertEq(gateway.nonces(user), MathUtils.uncheckedAdd(currentNonce, 1));
  }

  function test_renouncePositionManagerRole_revertsWith_OnlyOwner() public {
    address caller = vm.randomAddress();
    while (caller == ADMIN) caller = vm.randomAddress();

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    gateway.renounceSelfAsUserPositionManager(alice);
  }

  function test_renouncePositionManagerRole() public {
    address who = vm.randomAddress();
    vm.expectCall(address(spoke1), abi.encodeCall(ISpoke.renouncePositionManagerRole, (who)));
    vm.prank(ADMIN);
    gateway.renounceSelfAsUserPositionManager(who);
  }

  function test_supplyWithSig() public {
    EIP712Types.Supply memory p = _supplyData(spoke1, alice, _warpBeforeRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);

    uint256 shares = _hub(spoke1, p.reserveId).previewAddByAssets(
      _assetId(spoke1, p.reserveId),
      p.amount
    );

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(p.reserveId, address(gateway), alice, shares);

    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, alice, p.deadline, signature);

    assertEq(gateway.nonces(alice), p.nonce + 1);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_withdrawWithSig() public {
    EIP712Types.Withdraw memory p = _withdrawData(spoke1, alice, _warpBeforeRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    Utils.supply(spoke1, p.reserveId, alice, p.amount + 1, alice);

    uint256 shares = _hub(spoke1, p.reserveId).previewRemoveByAssets(
      _assetId(spoke1, p.reserveId),
      p.amount
    );
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(p.reserveId, address(gateway), alice, shares);

    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p.reserveId, p.amount, alice, p.deadline, signature);

    assertEq(gateway.nonces(alice), p.nonce + 1);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_borrowWithSig() public {
    EIP712Types.Borrow memory p = _borrowData(spoke1, alice, _warpBeforeRandomDeadline());
    p.reserveId = _daiReserveId(spoke1);
    p.amount = 1e18;
    Utils.supplyCollateral(spoke1, p.reserveId, alice, p.amount * 2, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      p.reserveId,
      address(gateway),
      alice,
      _hub(spoke1, p.reserveId).previewDrawByAssets(_assetId(spoke1, p.reserveId), p.amount)
    );

    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p.reserveId, p.amount, alice, p.deadline, signature);

    assertEq(gateway.nonces(alice), p.nonce + 1);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_repayWithSig() public {
    EIP712Types.Repay memory p = _repayData(spoke1, alice, _warpBeforeRandomDeadline());
    p.reserveId = _daiReserveId(spoke1);
    p.amount = 1e18;
    Utils.supplyCollateral(spoke1, p.reserveId, alice, p.amount * 2, alice);
    Utils.borrow(spoke1, p.reserveId, alice, p.amount, alice);
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    skip(vm.randomUint(0, MAX_SKIP_TIME));

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      spoke1,
      p.reserveId,
      alice,
      p.amount
    );
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Repay(
      p.reserveId,
      address(gateway),
      alice,
      _hub(spoke1, p.reserveId).previewRestoreByAssets(_assetId(spoke1, p.reserveId), baseRestored),
      _getExpectedPremiumDelta(spoke1, alice, p.reserveId, premiumRestored)
    );

    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, alice, p.deadline, signature);

    assertEq(gateway.nonces(alice), p.nonce + 1);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_setUsingAsCollateralWithSig() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    EIP712Types.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, alice, deadline);
    p.reserveId = _daiReserveId(spoke1);
    Utils.supplyCollateral(spoke1, p.reserveId, alice, 1e18, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    if (spoke1.isUsingAsCollateral(p.reserveId, alice) != p.useAsCollateral) {
      vm.expectEmit(address(spoke1));
      emit ISpoke.UsingAsCollateral(p.reserveId, address(gateway), alice, p.useAsCollateral);
    }

    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(
      p.reserveId,
      p.useAsCollateral,
      alice,
      p.deadline,
      signature
    );

    assertEq(gateway.nonces(alice), p.nonce + 1);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_updateUserRiskPremiumWithSig() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    EIP712Types.UpdateUserRiskPremium memory p = _updateRiskPremiumData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectEmit(address(spoke1));
    emit ISpoke.UserRiskPremiumUpdate(alice, 0);

    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(alice, p.deadline, signature);

    assertEq(gateway.nonces(alice), p.nonce + 1);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_updateUserDynamicConfigWithSig() public {
    EIP712Types.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);

    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(alice, p.deadline, signature);

    assertEq(gateway.nonces(alice), p.nonce + 1);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    EIP712Types.SetUserPositionManager memory p = EIP712Types.SetUserPositionManager({
      positionManager: address(gateway),
      user: alice,
      approve: true,
      nonce: spoke1.nonces(address(alice)), // note: this typed sig is forwarded to spoke
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(alice, address(gateway), p.approve);

    vm.prank(vm.randomAddress());
    gateway.setSelfAsUserPositionManagerWithSig(alice, p.approve, p.deadline, signature);

    assertEq(spoke1.nonces(alice), p.nonce + 1);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }
}
