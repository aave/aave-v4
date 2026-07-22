// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BytecodeLoader} from 'tests/utils/BytecodeLoader.sol';

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @notice Helper to deploy Hub from custom profile precompiled bytecode
contract DeployHub {
  /// @notice Deploys a Hub contract using CREATE2 and the stored bytecode with the provided deployment arguments.
  /// @param deployArgs The constructor arguments for the Hub contract, encoded as bytes.
  /// @param salt The salt to use for the CREATE2 deployment, allowing for deterministic address generation.
  /// @return The address of the deployed Hub contract.
  function deployHub(bytes memory deployArgs, bytes32 salt) public returns (address) {
    bytes memory bytecode = BytecodeLoader.loadHubBytecode();

    return Create2Utils.create2Deploy(salt, abi.encodePacked(bytecode, deployArgs));
  }
}
