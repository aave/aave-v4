// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PermissionedActionsMap} from 'src/position-manager/libraries/PermissionedActionsMap.sol';
import {
  IPermissionedPositionManager,
  PermissionedActions
} from 'src/position-manager/interfaces/IPermissionedPositionManager.sol';

contract PermissionedActionsMapWrapper {
  using PermissionedActionsMap for PermissionedActions;

  function setPermissioned(
    PermissionedActions self,
    IPermissionedPositionManager.Action action,
    bool permissioned
  ) external pure returns (PermissionedActions) {
    return self.setPermissioned(action, permissioned);
  }

  function isPermissioned(
    PermissionedActions self,
    IPermissionedPositionManager.Action action
  ) external pure returns (bool) {
    return self.isPermissioned(action);
  }
}
