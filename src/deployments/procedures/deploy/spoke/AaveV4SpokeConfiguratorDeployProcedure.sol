// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {SpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';

/// @title AaveV4SpokeConfiguratorDeployProcedure
/// @author Aave Labs
/// @notice Deploys the SpokeConfigurator contract for configuring Spoke instances.
contract AaveV4SpokeConfiguratorDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new SpokeConfigurator via CREATE2.
  /// @param authority The access control authority address.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed SpokeConfigurator contract.
  function _deploySpokeConfigurator(address authority, bytes32 salt) internal returns (address) {
    require(authority != address(0), 'invalid authority');
    bytes memory creationCode = vm.envOr('TEST_VYPER', false)
      ? vm.getCode('SpokeConfigurator.vy:SpokeConfigurator')
      : type(SpokeConfigurator).creationCode;
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(creationCode, abi.encode(authority))
      );
  }
}
