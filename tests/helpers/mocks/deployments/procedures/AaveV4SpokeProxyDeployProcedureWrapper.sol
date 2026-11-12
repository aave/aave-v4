// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4SpokeProxyDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeProxyDeployProcedure.sol';

contract AaveV4SpokeProxyDeployProcedureWrapper is AaveV4SpokeProxyDeployProcedure {
  bool public IS_TEST = true;

  function deploySpokeProxy(
    address proxyAdminOwner,
    address authority,
    address spokeImplementation,
    bytes32 spokeInitCodeHash,
    bytes32 salt
  ) external returns (address) {
    return
      _deploySpokeProxy(proxyAdminOwner, authority, spokeImplementation, spokeInitCodeHash, salt);
  }
}
