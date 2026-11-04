// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {GiverPositionManager} from 'src/position-manager/GiverPositionManager.sol';

/// @title AaveV4GiverPositionManagerDeployProcedure
/// @author Aave Labs
/// @notice Deploys the GiverPositionManager contract.
contract AaveV4GiverPositionManagerDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new GiverPositionManager instance via CREATE2.
  /// @param owner The owner of the GiverPositionManager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed GiverPositionManager contract.
  function _deployGiverPositionManager(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2DeployIdempotent({
        salt: salt,
        bytecode: abi.encodePacked(type(GiverPositionManager).creationCode, abi.encode(owner))
      });
  }
}
