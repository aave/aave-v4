// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from 'src/dependencies/openzeppelin/Address.sol';

/// @dev Stands in for the governance Executor in engine unit tests: every call is delegatecalled
/// into the config engine, so the engine runs in this contract's context and its delegatecall-only
/// guard passes. Reverts bubble up unchanged.
contract ConfigEngineDelegateCaller {
  address public immutable ENGINE;

  constructor(address engine) {
    ENGINE = engine;
  }

  fallback(bytes calldata data) external returns (bytes memory) {
    return Address.functionDelegateCall(ENGINE, data);
  }
}
