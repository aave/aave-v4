// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4HubConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubConfiguratorDeployProcedure.sol';

contract AaveV4HubConfiguratorDeployProcedureWrapper is AaveV4HubConfiguratorDeployProcedure {
  bool public IS_TEST = true;

  function deployHubConfigurator(address authority, bytes32 salt) external returns (address) {
    return _deployHubConfigurator(authority, salt);
  }
}
