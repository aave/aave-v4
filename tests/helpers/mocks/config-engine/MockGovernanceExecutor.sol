// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Minimal replica of the aave-governance-v3 Executor. Owned by the PayloadsController and
/// executes payloads via delegatecall, so inside the payload `address(this)` is the Executor
/// while `msg.sender` remains the PayloadsController.
contract MockGovernanceExecutor {
  address public immutable OWNER;

  error OnlyOwner();
  error FailedActionExecution();

  constructor(address owner) {
    OWNER = owner;
  }

  function executeTransaction(
    address target,
    bytes memory data
  ) external payable returns (bytes memory) {
    require(msg.sender == OWNER, OnlyOwner());
    (bool success, bytes memory resultData) = target.delegatecall(data);
    require(success, FailedActionExecution());
    return resultData;
  }
}
