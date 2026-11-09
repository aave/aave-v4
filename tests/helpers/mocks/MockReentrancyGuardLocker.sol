// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {
  vmTransient,
  REENTRANCY_GUARD_SLOT,
  REENTRANCY_GUARD_ENTERED
} from 'tests/utils/VmTransient.sol';

contract MockReentrancyGuardLocker {
  using Address for address;

  /// @dev Test isolation gives each top-level call fresh transient storage, so the lock is set in this frame.
  function lockAndCall(address target, bytes calldata data) external {
    vmTransient.storeTransient(target, REENTRANCY_GUARD_SLOT, REENTRANCY_GUARD_ENTERED);
    target.functionCall(data);
  }
}
