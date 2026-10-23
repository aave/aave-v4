// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';

/// @title AaveV4HubDeployProcedure
/// @author Aave Labs
/// @notice Deploys the transparent proxy of a Hub instance.
/// @dev The implementation is deployed in its own transaction (see `AaveV4DeployBase.deployHubImplementation`)
///      so that each step fits on chains with a per-transaction gas cap.
contract AaveV4HubDeployProcedure {
  /// @notice Deploys a transparent proxy for an already deployed Hub implementation via CREATE2.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param authority The access control authority address used to initialize the Hub.
  /// @param hubImplementation The address of the deployed Hub implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed transparent proxy.
  function _deployHubProxy(
    address proxyAdminOwner,
    address authority,
    address hubImplementation,
    bytes32 salt
  ) internal returns (address) {
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(authority != address(0), 'invalid authority');
    require(hubImplementation.code.length > 0, 'invalid hub implementation');
    return
      Create2Utils.proxify({
        salt: salt,
        logic: hubImplementation,
        initialOwner: proxyAdminOwner,
        data: abi.encodeCall(IHubInstance.initialize, (authority))
      });
  }
}
