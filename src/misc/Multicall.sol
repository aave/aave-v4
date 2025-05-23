// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';

/**
 * @title Multicall
 * @author Aave Labs, inspired by the OpenZeppelin Multicall contract
 * @notice This contract allows for batching multiple calls into a single call.
 */
abstract contract Multicall is IMulticall {
  /// @inheritdoc IMulticall
  function multicall(bytes[] calldata data) external returns (bytes[] memory) {
    bytes[] memory results = new bytes[](data.length);
    for (uint256 i; i < data.length; ++i) {
      (bool ok, bytes memory res) = address(this).delegatecall(data[i]);

      assembly ('memory-safe') {
        if iszero(ok) {
          revert(add(res, 32), mload(res)) // bubble up first revert
        }
      }

      results[i] = res;
    }
  }
}
