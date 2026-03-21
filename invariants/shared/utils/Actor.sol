// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';

/// @notice Proxy contract for invariant suite actors to avoid aTester calling contracts
contract Actor {
  using SafeERC20 for IERC20;

  /// @dev Constructor approves the maximum amount of all tokens to all protocol contracts to avoid needing to approve in handlers
  constructor(address[] memory tokens, address[] memory contracts) payable {
    for (uint256 i = 0; i < tokens.length; ++i) {
      for (uint256 j = 0; j < contracts.length; ++j) {
        IERC20(tokens[i]).forceApprove(contracts[j], type(uint256).max);
      }
    }
  }

  /// @notice Helper function to proxy a call to a target contract, used to avoid Tester calling contracts
  function proxy(address target, bytes memory callData) public returns (bool, bytes memory) {
    (bool ok, bytes memory ret) = address(target).call(callData);
    _handleAssertionError(ok, ret);
    return (ok, ret);
  }

  /// @notice Helper function to proxy a call and value to a target contract, used to avoid Tester calling contracts
  function proxy(
    address target,
    bytes memory callData,
    uint256 value
  ) public payable returns (bool, bytes memory) {
    (bool ok, bytes memory ret) = address(target).call{value: value}(callData);
    _handleAssertionError(ok, ret);
    return (ok, ret);
  }

  /// @notice Checks if a call failed due to an assertion error and propagates the error if found.
  /// @param ok Indicates whether the call was successful.
  /// @param ret The data returned from the call.
  function _handleAssertionError(bool ok, bytes memory ret) internal pure {
    if (!ok && ret.length == 36) {
      bytes4 selector;
      uint256 code;
      assembly ('memory-safe') {
        selector := mload(add(ret, 0x20))
        code := mload(add(ret, 0x24))
      }

      if (selector == bytes4(0x4e487b71) && code == 1) {
        assert(false);
      }
    }
  }

  receive() external payable {}
}
