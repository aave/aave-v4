// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4HubImplementationDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubImplementationDeployProcedure.sol';

contract AaveV4HubImplementationDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployHubImplementation(
    bytes memory hubBytecode,
    bytes32 salt
  ) external returns (address) {
    return AaveV4HubImplementationDeployProcedure.deployHubImplementation(hubBytecode, salt);
  }
}
