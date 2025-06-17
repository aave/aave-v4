// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowTest is SpokeBase {
  function testAccess() public {
    // Show that any address cannot call
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.restrictedFunction();

    // Show that the hub admin can call
    vm.prank(HUB_ADMIN);
    spoke1.restrictedFunction();

    // The hub admin can grant access to restricted functions via roles
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpoke.restrictedFunction.selector;

    vm.startPrank(HUB_ADMIN);
    accessManager.setTargetFunctionRole(address(spoke1), selectors, Roles.RESTRICTED_ROLE);
    accessManager.grantRole(Roles.RESTRICTED_ROLE, bob, 0);
    vm.stopPrank();

    // Now Bob can call the restricted function
    vm.prank(bob);
    spoke1.restrictedFunction();
  }

  /// @dev Bob has the role to call the restricted function, but we change what the role can do
  function testAccess_revoke_role_ability() public {
    // Grant Bob the role to call the restricted function
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpoke.restrictedFunction.selector;

    vm.startPrank(HUB_ADMIN);
    accessManager.setTargetFunctionRole(address(spoke1), selectors, Roles.RESTRICTED_ROLE);
    accessManager.grantRole(Roles.RESTRICTED_ROLE, bob, 0);
    vm.stopPrank();

    // Bob can call the restricted function
    vm.prank(bob);
    spoke1.restrictedFunction();

    // Now we change what the role can do, removing the ability to call the restricted function
    vm.startPrank(HUB_ADMIN);
    accessManager.setTargetFunctionRole(address(spoke1), selectors, Roles.ADMIN_ROLE);
    vm.stopPrank();

    // Bob should no longer be able to call the restricted function
    vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, bob));
    vm.prank(bob);
    spoke1.restrictedFunction();
  }

  /// @dev Bob has the role to call the restricted function, but then we remove the role from Bob
  function testAccess_revoke_role_from_bob() public {
    // Grant Bob the role to call the restricted function
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpoke.restrictedFunction.selector;
    vm.startPrank(HUB_ADMIN);
    accessManager.setTargetFunctionRole(address(spoke1), selectors, Roles.RESTRICTED_ROLE);
    accessManager.grantRole(Roles.RESTRICTED_ROLE, bob, 0);
    vm.stopPrank();

    // Bob can call the restricted function
    vm.prank(bob);
    spoke1.restrictedFunction();

    // Now we remove the role from Bob
    vm.startPrank(HUB_ADMIN);
    accessManager.revokeRole(Roles.RESTRICTED_ROLE, bob);
    vm.stopPrank();

    // Bob should no longer be able to call the restricted function
    vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, bob));
    vm.prank(bob);
    spoke1.restrictedFunction();
  }

  // TODO: Showcase Alice being an admin of the restricted role
}
