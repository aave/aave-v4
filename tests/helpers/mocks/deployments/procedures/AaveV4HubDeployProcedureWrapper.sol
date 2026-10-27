// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';

contract AaveV4HubDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployHub(
    address proxyAdminOwner,
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) external returns (address hubProxy, address hubImplementation) {
    return AaveV4HubDeployProcedure.deployUpgradeableHubInstance(proxyAdminOwner, authority, hubBytecode, salt);
  }
}
