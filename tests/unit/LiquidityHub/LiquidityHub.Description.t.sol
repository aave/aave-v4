// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubDescriptionTest is LiquidityHubBase {
  string internal constant NEW_DESCRIPTION = 'Updated Spoke Description';
  string internal constant EMPTY_DESCRIPTION = '';
  string internal constant LONG_DESCRIPTION =
    'This is a very long description that tests the system ability to handle longer strings for spoke descriptions';

  function test_updateDescription() public {
    assertEq(hub.description(), EMPTY_DESCRIPTION);
    test_updateDescription_fuzz(NEW_DESCRIPTION);
  }

  function test_updateDescription_emptyString() public {
    test_updateDescription_fuzz(NEW_DESCRIPTION);
    test_updateDescription_fuzz(EMPTY_DESCRIPTION);
  }

  function test_updateDescription_longString() public {
    test_updateDescription_fuzz(LONG_DESCRIPTION);
  }

  function test_updateDescription_sameValue() public {
    test_updateDescription_fuzz(NEW_DESCRIPTION);
    test_updateDescription_fuzz(NEW_DESCRIPTION);
  }

  function test_updateDescription_fuzz(string memory newDescription) public {
    vm.expectEmit(address(hub));
    emit ILiquidityHub.DescriptionUpdated(newDescription);

    vm.prank(HUB_ADMIN);
    hub.updateDescription(newDescription);

    assertEq(hub.description(), newDescription, 'Fuzz description update failed');
  }

  function test_updateDescription_revertsWith_AccessManagedUnauthorized() public {
    test_updateDescription_fuzz_unauthorized(alice, NEW_DESCRIPTION);
  }

  function test_updateDescription_fuzz_unauthorized(
    address unauthorizedUser,
    string memory newDescription
  ) public {
    vm.assume(unauthorizedUser != HUB_ADMIN);
    assumeUnusedAddress(unauthorizedUser);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, unauthorizedUser)
    );
    vm.prank(unauthorizedUser);
    hub.updateDescription(newDescription);
  }
}
