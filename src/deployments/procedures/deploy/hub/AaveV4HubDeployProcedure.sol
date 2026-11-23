// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title AaveV4HubDeployProcedure
/// @author Aave Labs
/// @notice Deploys the canonical Hub implementation.
contract AaveV4HubDeployProcedure {
  /// @notice Deploys the canonical Hub implementation via CREATE2.
  /// @param hubBytecode The creation bytecode of the Hub implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed Hub implementation contract.
  function _deployHubImplementation(
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (address) {
    return Create2Utils.create2Deploy({salt: salt, bytecode: hubBytecode});
  }
}
