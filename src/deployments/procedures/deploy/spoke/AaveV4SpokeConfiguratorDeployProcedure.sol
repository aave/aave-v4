// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ISpokeConfiguratorInstance} from 'src/deployments/utils/interfaces/ISpokeConfiguratorInstance.sol';

/// @title AaveV4SpokeConfiguratorDeployProcedure
/// @author Aave Labs
/// @notice Deploys the upgradeable SpokeConfigurator contract for configuring Spoke instances.
contract AaveV4SpokeConfiguratorDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a SpokeConfigurator implementation via CREATE2 and sets up a transparent proxy.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param authority The access control authority address used to initialize the SpokeConfigurator.
  /// @param spokeConfiguratorBytecode The creation bytecode of the SpokeConfigurator implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return spokeConfiguratorProxy The address of the deployed transparent proxy.
  /// @return spokeConfiguratorImplementation The address of the deployed SpokeConfigurator implementation contract.
  function _deployUpgradeableSpokeConfigurator(
    address proxyAdminOwner,
    address authority,
    bytes memory spokeConfiguratorBytecode,
    bytes32 salt
  ) internal returns (address spokeConfiguratorProxy, address spokeConfiguratorImplementation) {
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(authority != address(0), 'invalid authority');
    spokeConfiguratorImplementation = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: spokeConfiguratorBytecode
    });
    spokeConfiguratorProxy = Create2Utils.proxify({
      salt: salt,
      logic: spokeConfiguratorImplementation,
      initialOwner: proxyAdminOwner,
      data: abi.encodeCall(ISpokeConfiguratorInstance.initialize, (authority))
    });
    // Other `initialize(address)` contracts would deploy silently; only a SpokeConfigurator has this getter.
    (bool success, ) = spokeConfiguratorProxy.staticcall(
      abi.encodeCall(ISpokeConfiguratorInstance.SPOKE_CONFIGURATOR_REVISION, ())
    );
    require(success, 'invalid spoke configurator bytecode');
    return (spokeConfiguratorProxy, spokeConfiguratorImplementation);
  }
}
