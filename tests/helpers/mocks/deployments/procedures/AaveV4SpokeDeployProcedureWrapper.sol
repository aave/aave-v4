// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';

contract AaveV4SpokeDeployProcedureWrapper is AaveV4SpokeDeployProcedure {
  bool public IS_TEST = true;

  function deployUpgradeableSpokeInstance(
    address proxyAdminOwner,
    address authority,
    address oracle,
    address hook,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) external returns (address spokeProxy, address spokeImplementation) {
    return
      _deployUpgradeableSpokeInstance(
        proxyAdminOwner,
        authority,
        oracle,
        hook,
        spokeBytecode,
        maxUserReservesLimit,
        salt
      );
  }
}
