// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {IHubConfiguratorInstance} from 'src/deployments/utils/interfaces/IHubConfiguratorInstance.sol';

/// @title AaveV4HubConfiguratorDeployProcedure
/// @author Aave Labs
/// @notice Deploys the upgradeable HubConfigurator contract for configuring the Hub.
contract AaveV4HubConfiguratorDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a HubConfigurator implementation via CREATE2 and sets up a transparent proxy.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param authority The access control authority address used to initialize the HubConfigurator.
  /// @param hubConfiguratorBytecode The creation bytecode of the HubConfigurator implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return hubConfiguratorProxy The address of the deployed transparent proxy.
  /// @return hubConfiguratorImplementation The address of the deployed HubConfigurator implementation contract.
  function _deployUpgradeableHubConfigurator(
    address proxyAdminOwner,
    address authority,
    bytes memory hubConfiguratorBytecode,
    bytes32 salt
  ) internal returns (address hubConfiguratorProxy, address hubConfiguratorImplementation) {
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(authority != address(0), 'invalid authority');
    hubConfiguratorImplementation = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: hubConfiguratorBytecode
    });
    hubConfiguratorProxy = Create2Utils.proxify({
      salt: salt,
      logic: hubConfiguratorImplementation,
      initialOwner: proxyAdminOwner,
      data: abi.encodeCall(IHubConfiguratorInstance.initialize, (authority))
    });
    // Other `initialize(address)` contracts would deploy silently; only a HubConfigurator has this getter.
    (bool success, ) = hubConfiguratorProxy.staticcall(
      abi.encodeCall(IHubConfiguratorInstance.HUB_CONFIGURATOR_REVISION, ())
    );
    require(success, 'invalid hub configurator bytecode');
    return (hubConfiguratorProxy, hubConfiguratorImplementation);
  }
}
