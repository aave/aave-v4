// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @dev Gate mock which restricts configured selectors to eligible `onBehalfOf` users,
/// optionally capping the action amount.
contract MockSpokeGate is ISpokeGate {
  mapping(bytes4 selector => bool) public gated;
  mapping(address user => bool) public eligible;
  uint256 public maxActionAmount = type(uint256).max;

  function setGated(bytes4 selector, bool value) external {
    gated[selector] = value;
  }

  function setEligible(address user, bool value) external {
    eligible[user] = value;
  }

  function setMaxActionAmount(uint256 value) external {
    maxActionAmount = value;
  }

  function isActionAllowed(
    bytes4 selector,
    address,
    address onBehalfOf,
    uint256,
    uint256 amount
  ) external view returns (bool) {
    return !gated[selector] || (eligible[onBehalfOf] && amount <= maxActionAmount);
  }
}
