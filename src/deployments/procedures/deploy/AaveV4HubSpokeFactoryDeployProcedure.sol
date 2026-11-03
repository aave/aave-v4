// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {HubSpokeFactory} from 'src/deployments/factory/HubSpokeFactory.sol';

/// @title AaveV4HubSpokeFactoryDeployProcedure
/// @author Aave Labs
/// @notice Deploys the HubSpokeFactory bound to the canonical implementations.
contract AaveV4HubSpokeFactoryDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys the HubSpokeFactory via CREATE2.
  /// @param hubImplementation The canonical HubInstance implementation.
  /// @param spokeImplementation The canonical SpokeInstance implementation.
  /// @param treasurySpokeImplementation The canonical TreasurySpokeInstance implementation.
  /// @param tokenizationSpokeImplementation The canonical TokenizationSpokeInstance implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed HubSpokeFactory.
  function _deployHubSpokeFactory(
    address hubImplementation,
    address spokeImplementation,
    address treasurySpokeImplementation,
    address tokenizationSpokeImplementation,
    bytes32 salt
  ) internal returns (address) {
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: abi.encodePacked(
          type(HubSpokeFactory).creationCode,
          abi.encode(
            hubImplementation,
            spokeImplementation,
            treasurySpokeImplementation,
            tokenizationSpokeImplementation
          )
        )
      });
  }
}
