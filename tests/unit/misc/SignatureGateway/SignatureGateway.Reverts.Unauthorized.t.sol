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
    EIP712Types.Supply memory p = _supplyData(spoke1, alice, _warpBeforeRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, alice, p.deadline, signature);
  }

  function test_withdrawWithSig_revertsWith_Unauthorized() public {
    EIP712Types.Withdraw memory p = _withdrawData(spoke1, alice, _warpBeforeRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p.reserveId, p.amount, alice, p.deadline, signature);
  }

  function test_borrowWithSig_revertsWith_Unauthorized() public {
    EIP712Types.Borrow memory p = _borrowData(spoke1, alice, _warpBeforeRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p.reserveId, p.amount, alice, p.deadline, signature);
  }

  function test_repayWithSig_revertsWith_Unauthorized() public {
    EIP712Types.Repay memory p = _repayData(spoke1, alice, _warpBeforeRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, alice, p.deadline, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_Unauthorized() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    EIP712Types.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(p.reserveId, p.useAsCollateral, alice, deadline, signature);
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_Unauthorized() public {
    EIP712Types.UpdateUserRiskPremium memory p = _updateRiskPremiumData(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(gateway))
    );
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(alice, p.deadline, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_Unauthorized() public {
    EIP712Types.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(gateway))
    );
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(alice, p.deadline, signature);
  }
}

contract SignatureGateway_Unauthorized_PositionManagerActive_Test is
  SignatureGateway_Unauthorized_PositionManagerNotActive_Test
{
  function setUp() public override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    assertTrue(spoke1.isPositionManagerActive(address(gateway)));
    assertFalse(spoke1.isPositionManager(alice, address(gateway)));
  }
}
