// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMulticall {
  /**
   * @notice Call multiple functions in the current contract and return the data from all of them if they all succeed.
   * @param data The encoded function data for each of the calls to make to this contract.
   * @return results The results from each of the calls passed in via data.
   */
  function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}
