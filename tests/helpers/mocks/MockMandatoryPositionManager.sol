// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMandatoryPositionManager} from 'src/spoke/interfaces/IMandatoryPositionManager.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @dev Mandatory position manager mock:
/// - `globalManager`s are allowed to act on behalf of any user (e.g. an RWA manager)
/// - `gated` selectors additionally require the position owner to be `eligible`
/// - otherwise falls back to the Spoke's default position manager authorization
contract MockMandatoryPositionManager is IMandatoryPositionManager {
  ISpoke public immutable SPOKE;

  mapping(address caller => bool) public globalManager;
  mapping(bytes4 selector => bool) public gated;
  mapping(address user => bool) public eligible;

  constructor(ISpoke spoke) {
    SPOKE = spoke;
  }

  function setGlobalManager(address caller, bool value) external {
    globalManager[caller] = value;
  }

  function setGated(bytes4 selector, bool value) external {
    gated[selector] = value;
  }

  function setEligible(address user, bool value) external {
    eligible[user] = value;
  }

  function isCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata data
  ) external view returns (bool) {
    if (globalManager[caller]) return true;
    if (gated[bytes4(data)] && !eligible[onBehalfOf]) return false;
    return SPOKE.isPositionManager(onBehalfOf, caller);
  }
}
