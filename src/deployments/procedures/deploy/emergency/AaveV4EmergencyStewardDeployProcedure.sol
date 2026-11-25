// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {EmergencySteward} from 'src/emergency/EmergencySteward.sol';

/// @title AaveV4EmergencyStewardDeployProcedure
/// @author Aave Labs
/// @notice Deploys the EmergencySteward contract.
contract AaveV4EmergencyStewardDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new EmergencySteward instance via CREATE2.
  /// @param authority The access control authority address.
  /// @param spokeConfigurator The address of the SpokeConfigurator the EmergencySteward calls.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed EmergencySteward contract.
  function _deployEmergencySteward(
    address authority,
    address spokeConfigurator,
    bytes32 salt
  ) internal returns (address) {
    require(authority != address(0), 'invalid authority');
    require(spokeConfigurator != address(0), 'invalid spoke configurator');
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: abi.encodePacked(
          type(EmergencySteward).creationCode,
          abi.encode(authority, spokeConfigurator)
        )
      });
  }
}
