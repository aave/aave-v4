// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {PermissionedBorrowAccessManager} from 'src/access/PermissionedBorrowAccessManager.sol';
import {IBorrowerEligibility} from 'src/access/interfaces/IBorrowerEligibility.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

contract PermissionedBorrowAccessManagerTest is Test {
  address internal constant ADMIN = address(0xA11CE);
  address internal constant SPOKE = address(0x5A0CE);
  address internal constant ELIGIBILITY = address(0xE11B1E);
  address internal constant CALLER = address(0xCA11E2);
  address internal constant ON_BEHALF_OF = address(0xB0220);
  address internal constant OTHER_TARGET = address(0x0A7E2);

  uint64 internal constant GLOBAL_MANAGER_ROLE = 1;

  PermissionedBorrowAccessManager internal accessManager;

  function setUp() public {
    accessManager = new PermissionedBorrowAccessManager(
      ADMIN,
      ISpoke(SPOKE),
      IBorrowerEligibility(ELIGIBILITY)
    );
  }

  function test_canCall_borrow_whenPositionManagerAndEligible() public {
    _mockPositionManager(CALLER, ON_BEHALF_OF, true);
    _mockEligibility(ON_BEHALF_OF, true);

    (bool immediate, uint32 delay) = accessManager.canCall(
      CALLER,
      SPOKE,
      abi.encodeCall(ISpoke.borrow, (1, 100e6, ON_BEHALF_OF))
    );

    assertTrue(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_borrow_rejectsIneligiblePositionOwner() public {
    _mockPositionManager(CALLER, ON_BEHALF_OF, true);
    _mockEligibility(ON_BEHALF_OF, false);

    (bool immediate, uint32 delay) = accessManager.canCall(
      CALLER,
      SPOKE,
      abi.encodeCall(ISpoke.borrow, (1, 100e6, ON_BEHALF_OF))
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_borrow_rejectsCallerWithoutPositionApproval() public {
    _mockPositionManager(CALLER, ON_BEHALF_OF, false);
    _mockEligibility(ON_BEHALF_OF, true);

    (bool immediate, uint32 delay) = accessManager.canCall(
      CALLER,
      SPOKE,
      abi.encodeCall(ISpoke.borrow, (1, 100e6, ON_BEHALF_OF))
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_nonBorrowPositionAction_preservesPositionManagerApproval() public {
    _mockPositionManager(CALLER, ON_BEHALF_OF, true);

    (bool immediate, uint32 delay) = accessManager.canCall(
      CALLER,
      SPOKE,
      abi.encodeCall(ISpoke.withdraw, (1, 100e6, ON_BEHALF_OF))
    );

    assertTrue(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_explicitRoleDoesNotBypassPositionPolicy() public {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpoke.borrow.selector;

    vm.startPrank(ADMIN);
    accessManager.grantRole(GLOBAL_MANAGER_ROLE, CALLER, 0);
    accessManager.setTargetFunctionRole(SPOKE, selectors, GLOBAL_MANAGER_ROLE);
    vm.stopPrank();

    _mockPositionManager(CALLER, ON_BEHALF_OF, false);
    _mockEligibility(ON_BEHALF_OF, false);

    (bool immediate, uint32 delay) = accessManager.canCall(
      CALLER,
      SPOKE,
      abi.encodeCall(ISpoke.borrow, (1, 100e6, ON_BEHALF_OF))
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_rejectsUnknownTarget() public view {
    (bool immediate, uint32 delay) = accessManager.canCall(
      CALLER,
      OTHER_TARGET,
      abi.encodeCall(ISpoke.borrow, (1, 100e6, ON_BEHALF_OF))
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_rejectsUnknownSelector() public view {
    (bool immediate, uint32 delay) = accessManager.canCall(
      CALLER,
      SPOKE,
      abi.encodeWithSelector(
        bytes4(keccak256('unknown(uint256,uint256,address)')),
        1,
        2,
        ON_BEHALF_OF
      )
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_rejectsMalformedCalldata() public view {
    (bool immediate, uint32 delay) = accessManager.canCall(
      CALLER,
      SPOKE,
      abi.encodePacked(ISpoke.borrow.selector)
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_rejectsDirtyAddressCalldata() public view {
    bytes memory data = abi.encodeCall(ISpoke.borrow, (1, 100e6, ON_BEHALF_OF));
    assembly ('memory-safe') {
      mstore(add(data, 100), or(mload(add(data, 100)), shl(160, 1)))
    }

    (bool immediate, uint32 delay) = accessManager.canCall(CALLER, SPOKE, data);

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_selectorCanCall_retainsOrdinaryAccessManagerBehavior() public view {
    (bool immediate, uint32 delay) = accessManager.canCall(ADMIN, SPOKE, ISpoke.borrow.selector);

    assertTrue(immediate);
    assertEq(delay, 0);
  }

  function _mockPositionManager(address caller, address onBehalfOf, bool allowed) internal {
    vm.mockCall(
      SPOKE,
      abi.encodeCall(ISpoke.isPositionManager, (onBehalfOf, caller)),
      abi.encode(allowed)
    );
  }

  function _mockEligibility(address onBehalfOf, bool eligible) internal {
    vm.mockCall(
      ELIGIBILITY,
      abi.encodeCall(IBorrowerEligibility.isEligible, (onBehalfOf)),
      abi.encode(eligible)
    );
  }
}
