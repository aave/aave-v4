// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGateway_SpokeNotRegistered_Test is SignatureGatewayBaseTest {
  function setUp() public virtual override {
    super.setUp();

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(address(ADMIN));
    gateway.registerSpoke(address(spoke1), false);

    assertTrue(spoke1.isPositionManagerActive(address(gateway)));
    assertTrue(spoke1.isPositionManager(alice, address(gateway)));
    assertFalse(gateway.isSpokeRegistered(address(spoke1)));
  }

  function test_supplyWithSig_revertsWith_SpokeNotRegistered(EIP712Types.Supply memory p) public {
    bytes memory signature = vm.randomBytes(32);

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p, signature);
  }

  function test_withdrawWithSig_revertsWith_SpokeNotRegistered(
    EIP712Types.Withdraw memory p
  ) public {
    bytes memory signature = vm.randomBytes(32);

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p, signature);
  }

  function test_borrowWithSig_revertsWith_SpokeNotRegistered(EIP712Types.Borrow memory p) public {
    bytes memory signature = vm.randomBytes(32);

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p, signature);
  }

  function test_repayWithSig_revertsWith_SpokeNotRegistered(EIP712Types.Repay memory p) public {
    bytes memory signature = vm.randomBytes(32);

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_SpokeNotRegistered(
    EIP712Types.SetUsingAsCollateral memory p
  ) public {
    bytes memory signature = vm.randomBytes(32);

    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(p, signature);
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_SpokeNotRegistered(
    EIP712Types.UpdateUserRiskPremium memory p
  ) public {
    bytes memory signature = vm.randomBytes(32);

    vm.expectRevert(
      abi.encodeWithSelector(IGatewayBase.SpokeNotRegistered.selector, address(gateway))
    );
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_SpokeNotRegistered(
    EIP712Types.UpdateUserDynamicConfig memory p
  ) public {
    bytes memory signature = vm.randomBytes(32);

    vm.expectRevert(
      abi.encodeWithSelector(IGatewayBase.SpokeNotRegistered.selector, address(gateway))
    );
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p, signature);
  }
}
