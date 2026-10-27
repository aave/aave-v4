// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeConfiguratorDeployProcedure.sol';

contract AaveV4SpokeConfiguratorDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deploySpokeConfigurator(address authority, bytes32 salt) external returns (address) {
    return AaveV4SpokeConfiguratorDeployProcedure.deploySpokeConfigurator(authority, salt);
  }
}
