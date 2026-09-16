// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ConfigPositionManager} from 'src/position-manager/ConfigPositionManager.sol';

/// @title AaveV4ConfigPositionManagerDeployProcedure
/// @author Aave Labs
/// @notice Deploys the ConfigPositionManager contract.
contract AaveV4ConfigPositionManagerDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new ConfigPositionManager instance via CREATE2.
  /// @param owner The owner of the ConfigPositionManager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed ConfigPositionManager contract.
  function _deployConfigPositionManager(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2DeployIdempotent({
        salt: salt,
        bytecode: abi.encodePacked(type(ConfigPositionManager).creationCode, abi.encode(owner))
      });
  }
}
