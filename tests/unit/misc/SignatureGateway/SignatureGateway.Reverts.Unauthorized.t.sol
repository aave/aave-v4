// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGateway_Unauthorized_PositionManagerNotActive_Test is SignatureGatewayBaseTest {
  function setUp() public virtual override {
    super.setUp();
    _approveAllUnderlying(spoke1, alice, address(gateway));

    assertFalse(spoke1.isPositionManagerActive(address(gateway)));
    assertFalse(spoke1.isPositionManager(alice, address(gateway)));
  }

  function test_supplyWithSig_revertsWith_Unauthorized() public {
    ISignatureGateway.SupplyAction memory p = _supplyAction(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p, signature);
  }

  function test_withdrawWithSig_revertsWith_Unauthorized() public {
    ISignatureGateway.WithdrawAction memory p = _withdrawAction(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p, signature);
  }

  function test_borrowWithSig_revertsWith_Unauthorized() public {
    ISignatureGateway.BorrowAction memory p = _borrowAction(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p, signature);
  }

  function test_repayWithSig_revertsWith_Unauthorized() public {
    ISignatureGateway.RepayAction memory p = _repayAction(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_Unauthorized() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    ISignatureGateway.SetUsingAsCollateralAction memory p = _setAsCollateralAction(
      spoke1,
      alice,
      deadline
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(p, signature);
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_Unauthorized() public {
    ISignatureGateway.UpdateUserRiskPremiumAction memory p = _updateRiskPremiumAction(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(gateway))
    );
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_Unauthorized() public {
    ISignatureGateway.UpdateUserDynamicConfigAction memory p = _updateDynamicConfigAction(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(gateway))
    );
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p, signature);
  }
}

contract SignatureGateway_Unauthorized_PositionManagerActive_Test is
  SignatureGateway_Unauthorized_PositionManagerNotActive_Test
{
  function setUp() public override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(address(ADMIN));
    gateway.registerSpoke(address(spoke1), true);
    assertTrue(spoke1.isPositionManagerActive(address(gateway)));
    assertFalse(spoke1.isPositionManager(alice, address(gateway)));
  }
}
