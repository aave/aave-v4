// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title AaveV4HubImplementationDeployProcedure Library
/// @author Aave Labs
/// @notice Deploys a Hub implementation in its own transaction.
/// @dev A library rather than a batch base: the implementation is close to the 24 KB code size limit, so it does not
///      share a transaction with other contracts on chains with a per-transaction gas cap.
library AaveV4HubImplementationDeployProcedure {
  /// @notice Deploys a Hub implementation via CREATE2.
  /// @param hubBytecode The creation bytecode of the HubInstance contract.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed Hub implementation.
  function deployHubImplementation(
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (address) {
    return Create2Utils.create2Deploy({salt: salt, bytecode: hubBytecode});
  }
}
