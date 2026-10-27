// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';

contract AaveV4SpokeDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployUpgradeableSpokeInstance(
    address proxyAdminOwner,
    address authority,
    address oracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) external returns (address spokeProxy, address spokeImplementation) {
    return
      AaveV4SpokeDeployProcedure.deployUpgradeableSpokeInstance(
        proxyAdminOwner,
        authority,
        oracle,
        spokeBytecode,
        maxUserReservesLimit,
        salt
      );
  }
}
