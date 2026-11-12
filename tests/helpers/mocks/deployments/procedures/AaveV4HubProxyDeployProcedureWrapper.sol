// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4HubProxyDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubProxyDeployProcedure.sol';

contract AaveV4HubProxyDeployProcedureWrapper is AaveV4HubProxyDeployProcedure {
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
