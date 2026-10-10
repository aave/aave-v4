// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';

/// @title AaveV4HubDeployProcedure
/// @author Aave Labs
/// @notice Deploys an upgradeable Hub instance behind a transparent proxy.
contract AaveV4HubDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a Hub implementation via CREATE2 and sets up a transparent proxy.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param authority The access control authority address used to initialize the Hub.
  /// @param hubBytecode The creation bytecode of the Hub implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return hubProxy The address of the deployed transparent proxy.
  /// @return hubImplementation The address of the deployed Hub implementation contract.
  function _deployUpgradeableHubInstance(
    address proxyAdminOwner,
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (address hubProxy, address hubImplementation) {
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(authority != address(0), 'invalid authority');
    hubImplementation = Create2Utils.create2DeployIdempotent({salt: salt, bytecode: hubBytecode});
    hubProxy = Create2Utils.proxify({
      salt: salt,
      logic: hubImplementation,
      initialOwner: proxyAdminOwner,
      data: abi.encodeCall(IHubInstance.initialize, (authority))
    });
    return (hubProxy, hubImplementation);
  }
}
