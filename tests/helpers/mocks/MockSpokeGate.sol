// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @dev Gate mock:
/// - `globalManager`s are allowed to act on behalf of any user (e.g. an RWA manager)
/// - `gated` selectors additionally require the position owner to be `eligible`
/// - otherwise allows users to manage their own positions
contract MockSpokeGate is ISpokeGate {
  mapping(address caller => bool) public globalManager;
  mapping(bytes4 selector => bool) public gated;
  mapping(address user => bool) public eligible;

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
    return caller == onBehalfOf;
  }
}
