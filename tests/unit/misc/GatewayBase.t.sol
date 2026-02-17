// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract GatewayBaseTest is Base {
  GatewayBaseWrapper public gateway;

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();

    gateway = new GatewayBaseWrapper(address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
  }

  function test_constructor() public view {
    assertEq(gateway.owner(), address(ADMIN));
    assertEq(gateway.pendingOwner(), address(0));

    assertEq(gateway.rescueGuardian(), address(ADMIN));
  }

  function test_registerSpoke_fuzz(address newSpoke) public {
    vm.assume(newSpoke != address(0));
    assertFalse(gateway.isSpokeRegistered(newSpoke));

    vm.expectEmit(address(gateway));
    emit IGatewayBase.SpokeRegistered(newSpoke, true);
    vm.prank(ADMIN);
    gateway.registerSpoke(newSpoke, true);

    assertTrue(gateway.isSpokeRegistered(newSpoke));
  }

  function test_registerSpoke_unregister() public {
    assertFalse(gateway.isSpokeRegistered(address(spoke1)));

    vm.expectEmit(address(gateway));
    emit IGatewayBase.SpokeRegistered(address(spoke1), true);
    vm.prank(ADMIN);
    gateway.registerSpoke(address(spoke1), true);

    assertTrue(gateway.isSpokeRegistered(address(spoke1)));

    vm.expectEmit(address(gateway));
    emit IGatewayBase.SpokeRegistered(address(spoke1), false);
    vm.prank(ADMIN);
    gateway.registerSpoke(address(spoke1), false);

    assertFalse(gateway.isSpokeRegistered(address(spoke1)));
  }

  function test_registerSpoke_revertsWith_OwnableUnauthorizedAccount() public {
    address user = vm.randomAddress();
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
    vm.prank(user);
    gateway.registerSpoke(address(spoke1), true);
  }

  function test_registerSpoke_revertsWith_InvalidAddress() public {
    vm.expectRevert(IGatewayBase.InvalidAddress.selector);
    vm.prank(ADMIN);
    gateway.registerSpoke(address(0), true);
  }

  function test_renouncePositionManagerRole() public {
    address user = vm.randomAddress();

    vm.prank(user);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(ADMIN);
    gateway.registerSpoke(address(spoke1), true);

    assertTrue(spoke1.isPositionManager(user, address(gateway)));

    vm.prank(ADMIN);
    gateway.renouncePositionManagerRole(address(spoke1), user);

    assertFalse(spoke1.isPositionManager(user, address(gateway)));
  }

  function test_renouncePositionManagerRole_revertsWith_OwnableUnauthorizedAccount() public {
    address user = vm.randomAddress();

    vm.prank(user);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(ADMIN);
    gateway.registerSpoke(address(spoke1), true);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
    vm.prank(user);
    gateway.renouncePositionManagerRole(address(spoke1), user);
  }

  function test_renouncePositionManagerRole_revertsWith_InvalidAddress() public {
    address user = vm.randomAddress();

    vm.prank(user);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(ADMIN);
    gateway.registerSpoke(address(spoke1), true);

    vm.expectRevert(IGatewayBase.InvalidAddress.selector);
    vm.prank(ADMIN);
    gateway.renouncePositionManagerRole(address(spoke1), address(0));
  }
}
