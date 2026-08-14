// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @dev Local measurement helper: Horizon-style manager where a fixed global manager
/// may act on behalf of any user.
contract GlobalManagerAccessManager is AccessManagerEnumerable {
  ISpoke public immutable SPOKE;
  address public immutable GLOBAL_MANAGER;

  constructor(
    address initialAdmin_,
    ISpoke spoke_,
    address globalManager_
  ) AccessManagerEnumerable(initialAdmin_) {
    SPOKE = spoke_;
    GLOBAL_MANAGER = globalManager_;
  }

  function _isPositionActionAllowed(
    address caller,
    address target,
    bytes calldata data
  ) internal view override returns (bool handled, bool allowed) {
    if (target != address(SPOKE)) return super._isPositionActionAllowed(caller, target, data);
    if (caller == GLOBAL_MANAGER) return (true, true);
    return super._isPositionActionAllowed(caller, target, data);
  }
}
