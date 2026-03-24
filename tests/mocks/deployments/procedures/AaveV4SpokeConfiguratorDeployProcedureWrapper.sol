// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeConfiguratorDeployProcedure.sol';

contract AaveV4SpokeConfiguratorDeployProcedureWrapper is AaveV4SpokeConfiguratorDeployProcedure {
  bool public IS_TEST = true;

  function deploySpokeConfigurator(address authority, bytes32 salt) external returns (address) {
    return _deploySpokeConfigurator(authority, salt);
  }
}
