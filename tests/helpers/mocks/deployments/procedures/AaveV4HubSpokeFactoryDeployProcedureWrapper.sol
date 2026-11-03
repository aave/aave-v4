// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4HubSpokeFactoryDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4HubSpokeFactoryDeployProcedure.sol';

contract AaveV4HubSpokeFactoryDeployProcedureWrapper is AaveV4HubSpokeFactoryDeployProcedure {
  bool public IS_TEST = true;

  function deployHubSpokeFactory(
    address hubImplementation,
    address spokeImplementation,
    address treasurySpokeImplementation,
    address tokenizationSpokeImplementation,
    bytes32 salt
  ) external returns (address) {
    return
      _deployHubSpokeFactory(
        hubImplementation,
        spokeImplementation,
        treasurySpokeImplementation,
        tokenizationSpokeImplementation,
        salt
      );
  }
}
