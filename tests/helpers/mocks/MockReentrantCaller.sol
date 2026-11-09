// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {vmTransient} from 'tests/utils/VmTransient.sol';

contract MockReentrantCaller {
  using Address for address;

  error ReentrancyGuardNotEntered();

  address public immutable TARGET;
  bytes4 public immutable TARGET_SELECTOR;
  bytes32 public immutable GUARD_SLOT;

  constructor(address target, bytes4 targetSelector, bytes32 guardSlot) {
    TARGET = target;
    TARGET_SELECTOR = targetSelector;
    GUARD_SLOT = guardSlot;
  }

  fallback() external {
    if (vmTransient.loadTransient(TARGET, GUARD_SLOT) == bytes32(0)) {
      revert ReentrancyGuardNotEntered();
    }
    TARGET.functionCall(bytes.concat(TARGET_SELECTOR, new bytes(1000)));
  }
}
