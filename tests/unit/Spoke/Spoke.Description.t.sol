// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeDescriptionTest is SpokeBase {
  string internal constant NEW_DESCRIPTION = 'Updated Spoke Description';
  string internal constant EMPTY_DESCRIPTION = '';
  string internal constant LONG_DESCRIPTION =
    'This is a very long description that tests the system ability to handle longer strings for spoke descriptions';

  function test_updateDescription() public {
    assertEq(spoke1.description(), EMPTY_DESCRIPTION);
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
    vm.expectEmit(address(spoke1));
    emit ISpoke.DescriptionUpdated(newDescription);

    vm.prank(SPOKE_ADMIN);
    spoke1.updateDescription(newDescription);

    assertEq(spoke1.description(), newDescription, 'description');
  }

  function test_updateDescription_revertsWith_AccessManagedUnauthorized() public {
    test_updateDescription_fuzz_unauthorized(alice, NEW_DESCRIPTION);
  }

  function test_updateDescription_fuzz_unauthorized(
    address unauthorizedUser,
    string memory newDescription
  ) public {
    vm.assume(unauthorizedUser != SPOKE_ADMIN);
    assumeUnusedAddress(unauthorizedUser);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, unauthorizedUser)
    );
    vm.prank(unauthorizedUser);
    spoke1.updateDescription(newDescription);
  }
}
