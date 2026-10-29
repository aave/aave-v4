// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';

contract AaveV4HubDeployProcedureWrapper is AaveV4HubDeployProcedure {
  bool public IS_TEST = true;

  function deployHubProxy(
    address proxyAdminOwner,
    address authority,
    address hubImplementation,
    bytes32 hubInitCodeHash,
    bytes32 salt
  ) external returns (address) {
    return _deployHubProxy(proxyAdminOwner, authority, hubImplementation, hubInitCodeHash, salt);
  }
}
