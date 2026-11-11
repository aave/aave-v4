// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title AaveV4SpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys the canonical Spoke implementation.
contract AaveV4SpokeDeployProcedure {
  /// @notice Deploys the canonical Spoke implementation via CREATE2.
  /// @param spokeBytecode The creation bytecode of the Spoke implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed Spoke implementation contract.
  function _deploySpokeImplementation(
    bytes memory spokeBytecode,
    bytes32 salt
  ) internal returns (address) {
    return Create2Utils.create2Deploy({salt: salt, bytecode: spokeBytecode});
  }
}
