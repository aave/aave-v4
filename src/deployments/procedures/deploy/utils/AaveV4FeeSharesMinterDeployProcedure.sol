// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {FeeSharesMinter} from 'src/utils/FeeSharesMinter.sol';

/// @title AaveV4FeeSharesMinterDeployProcedure
/// @author Aave Labs
/// @notice Deploys the FeeSharesMinter contract.
contract AaveV4FeeSharesMinterDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new FeeSharesMinter instance via CREATE2.
  /// @param owner The owner of the FeeSharesMinter.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed FeeSharesMinter contract.
  function _deployFeeSharesMinter(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: abi.encodePacked(type(FeeSharesMinter).creationCode, abi.encode(owner))
      });
  }
}
