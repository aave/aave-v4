// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';

abstract contract Multicall is IMulticall {
  // @inheritdoc IMulticall
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
