// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {vmTransient} from 'tests/utils/VmTransient.sol';

contract MockTransientStoreCaller {
  using Address for address;

  /// @dev Test isolation gives each top-level call fresh transient storage, so the value is stored in this frame.
  function storeAndCall(address target, bytes32 slot, bytes32 value, bytes calldata data) external {
    vmTransient.storeTransient(target, slot, value);
    target.functionCall(data);
  }
}
