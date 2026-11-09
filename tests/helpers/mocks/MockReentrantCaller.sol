// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {
  vmTransient,
  REENTRANCY_GUARD_SLOT,
  REENTRANCY_GUARD_ENTERED
} from 'tests/utils/VmTransient.sol';

contract MockReentrantCaller {
  using Address for address;

  error ReentrancyGuardNotEntered();

  address public immutable TARGET;
  bytes4 public immutable TARGET_SELECTOR;

  constructor(address target, bytes4 targetSelector) {
    TARGET = target;
    TARGET_SELECTOR = targetSelector;
  }

  fallback() external {
    if (vmTransient.loadTransient(TARGET, REENTRANCY_GUARD_SLOT) != REENTRANCY_GUARD_ENTERED) {
      revert ReentrancyGuardNotEntered();
    }
    TARGET.functionCall(bytes.concat(TARGET_SELECTOR, new bytes(1000)));
  }
}
