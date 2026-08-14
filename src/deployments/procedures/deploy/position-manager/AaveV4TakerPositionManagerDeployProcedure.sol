// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TakerPositionManager} from 'src/position-manager/TakerPositionManager.sol';

/// @title AaveV4TakerPositionManagerDeployProcedure
/// @author Aave Labs
/// @notice Deploys the TakerPositionManager contract.
contract AaveV4TakerPositionManagerDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new TakerPositionManager instance via CREATE2.
  /// @param owner The owner of the TakerPositionManager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed TakerPositionManager contract.
  function _deployTakerPositionManager(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2DeployIdempotent({
        salt: salt,
        bytecode: abi.encodePacked(type(TakerPositionManager).creationCode, abi.encode(owner))
      });
  }
}
