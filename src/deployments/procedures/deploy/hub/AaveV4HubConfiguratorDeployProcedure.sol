// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {HubConfigurator} from 'src/hub/HubConfigurator.sol';

/// @title AaveV4HubConfiguratorDeployProcedure
/// @author Aave Labs
/// @notice Deploys the HubConfigurator contract for configuring the Hub.
contract AaveV4HubConfiguratorDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new HubConfigurator instance via CREATE2.
  /// @param authority The access control authority address.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed HubConfigurator contract.
  function _deployHubConfigurator(address authority, bytes32 salt) internal returns (address) {
    require(authority != address(0), 'invalid authority');
    bytes memory creationCode = vm.envOr('TEST_VYPER', false)
      ? vm.getCode('HubConfigurator.vy:HubConfigurator')
      : type(HubConfigurator).creationCode;
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(creationCode, abi.encode(authority))
      );
  }
}
