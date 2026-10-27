// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4HubConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubConfiguratorDeployProcedure.sol';

contract AaveV4HubConfiguratorDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployHubConfigurator(address authority, bytes32 salt) external returns (address) {
    return AaveV4HubConfiguratorDeployProcedure.deployHubConfigurator(authority, salt);
  }
}
