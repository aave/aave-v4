// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {
  IPermissionedPositionManager,
  PermissionedActions
} from 'src/position-manager/interfaces/IPermissionedPositionManager.sol';
import {PermissionedActionsMapWrapper} from 'tests/helpers/mocks/PermissionedActionsMapWrapper.sol';

contract PermissionedActionsMapTest is Test {
  uint256 internal constant ACTION_COUNT = 8;

  PermissionedActionsMapWrapper internal w;

  function setUp() public {
    w = new PermissionedActionsMapWrapper();
  }

  function test_action_bits() public view {
    for (uint256 i; i < ACTION_COUNT; ++i) {
      PermissionedActions actions = w.setPermissioned(
        PermissionedActions.wrap(0),
        IPermissionedPositionManager.Action(i),
        true
      );
      assertEq(PermissionedActions.unwrap(actions), 1 << i);
    }
  }

  function test_setPermissioned_fuzz(
    uint8 rawActions,
    uint256 actionIndex,
    bool permissioned
  ) public view {
    actionIndex = bound(actionIndex, 0, ACTION_COUNT - 1);
    uint8 mask = uint8(1 << actionIndex);

    PermissionedActions updated = w.setPermissioned(
      PermissionedActions.wrap(rawActions),
      IPermissionedPositionManager.Action(actionIndex),
      permissioned
    );

    uint8 expected = permissioned ? rawActions | mask : rawActions & ~mask;
    assertEq(PermissionedActions.unwrap(updated), expected);
  }

  function test_isPermissioned_fuzz(uint8 rawActions, uint256 actionIndex) public view {
    actionIndex = bound(actionIndex, 0, ACTION_COUNT - 1);

    assertEq(
      w.isPermissioned(
        PermissionedActions.wrap(rawActions),
        IPermissionedPositionManager.Action(actionIndex)
      ),
      (rawActions >> actionIndex) & 1 == 1
    );
  }
}
