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
}
