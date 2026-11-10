// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {HubSpokeFactory} from 'src/factory/HubSpokeFactory.sol';

/// @title AaveV4HubSpokeFactoryDeployProcedure
/// @author Aave Labs
/// @notice Deploys an upgradeable HubSpokeFactory behind a transparent proxy, bound to the canonical implementations.
contract AaveV4HubSpokeFactoryDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a HubSpokeFactory implementation via CREATE2 and sets up a transparent proxy.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param authority The access control authority address used to initialize the HubSpokeFactory.
  /// @param hubImplementation The canonical HubInstance implementation.
  /// @param spokeImplementation The canonical SpokeInstance implementation.
  /// @param treasurySpokeImplementation The canonical TreasurySpokeInstance implementation.
  /// @param tokenizationSpokeImplementation The canonical TokenizationSpokeInstance implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return hubSpokeFactoryProxy The address of the deployed transparent proxy.
  /// @return hubSpokeFactoryImplementation The address of the deployed HubSpokeFactory implementation contract.
  function _deployUpgradeableHubSpokeFactory(
    address proxyAdminOwner,
    address authority,
    address hubImplementation,
    address spokeImplementation,
    address treasurySpokeImplementation,
    address tokenizationSpokeImplementation,
    bytes32 salt
  ) internal returns (address hubSpokeFactoryProxy, address hubSpokeFactoryImplementation) {
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(authority != address(0), 'invalid authority');
    hubSpokeFactoryImplementation = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: type(HubSpokeFactory).creationCode
    });
    hubSpokeFactoryProxy = Create2Utils.proxify({
      salt: salt,
      logic: hubSpokeFactoryImplementation,
      initialOwner: proxyAdminOwner,
      data: abi.encodeCall(
        HubSpokeFactory.initialize,
        (
          authority,
          hubImplementation,
          spokeImplementation,
          treasurySpokeImplementation,
          tokenizationSpokeImplementation
        )
      )
    });
    return (hubSpokeFactoryProxy, hubSpokeFactoryImplementation);
  }
}
