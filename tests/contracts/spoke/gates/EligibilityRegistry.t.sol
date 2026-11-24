// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

contract EligibilityRegistryTest is PermissionedSpokeBase {
  function _accounts(address account) internal pure returns (address[] memory accounts) {
    accounts = new address[](1);
    accounts[0] = account;
  }

  function test_updateEligibility_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, bob));
    vm.prank(bob);
    registry.updateEligibility(_accounts(alice), IEligibilityRegistry.Status.ACTIVE, 1);
  }

  function test_updateEligibility() public {
    uint40 validUntil = uint40(block.timestamp + 10);
    vm.expectEmit(address(registry));
    emit IEligibilityRegistry.UpdateEligibility(
      alice,
      IEligibilityRegistry.Status.ACTIVE,
      validUntil
    );
    vm.prank(COMPLIANCE);
    registry.updateEligibility(_accounts(alice), IEligibilityRegistry.Status.ACTIVE, validUntil);

    IEligibilityRegistry.Entry memory entry = registry.getEntry(alice);
    assertEq(uint8(entry.status), uint8(IEligibilityRegistry.Status.ACTIVE));
    assertEq(entry.validUntil, validUntil);
    assertEq(uint8(registry.getStatus(alice)), uint8(IEligibilityRegistry.Status.ACTIVE));
  }

  function test_getStatus_expiredKycReadsAsOffboarded() public {
    vm.prank(COMPLIANCE);
    registry.updateEligibility(
      _accounts(alice),
      IEligibilityRegistry.Status.ACTIVE,
      uint40(block.timestamp + 10)
    );
    skip(11);
    assertEq(uint8(registry.getStatus(alice)), uint8(IEligibilityRegistry.Status.OFFBOARDED));
    assertEq(uint8(registry.getEntry(alice).status), uint8(IEligibilityRegistry.Status.ACTIVE));
  }

  function test_updateReserveManager_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, bob));
    vm.prank(bob);
    registry.updateReserveManager(address(1), 0, bob, AuthKind.ACTION_REPAY);
  }

  function test_updateReserveManager_revertsWith_InvalidAddress() public {
    vm.startPrank(COMPLIANCE);
    vm.expectRevert(IEligibilityRegistry.InvalidAddress.selector);
    registry.updateReserveManager(address(0), 0, bob, AuthKind.ACTION_REPAY);
    vm.expectRevert(IEligibilityRegistry.InvalidAddress.selector);
    registry.updateReserveManager(address(1), 0, address(0), AuthKind.ACTION_REPAY);
    vm.stopPrank();
  }

  function test_updateReserveManager_revertsWith_InvalidActions() public {
    vm.expectRevert(IEligibilityRegistry.InvalidActions.selector);
    vm.prank(COMPLIANCE);
    registry.updateReserveManager(address(1), 0, bob, AuthKind.ALL_ACTIONS + 1);
  }

  function test_updateReserveManager() public {
    vm.expectEmit(address(registry));
    emit IEligibilityRegistry.UpdateReserveManager(address(1), 2, bob, AuthKind.ALL_ACTIONS);
    vm.prank(COMPLIANCE);
    registry.updateReserveManager(address(1), 2, bob, AuthKind.ALL_ACTIONS);
    assertEq(registry.getReserveManagerActions(address(1), 2, bob), AuthKind.ALL_ACTIONS);
  }
}
