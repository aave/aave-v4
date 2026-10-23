// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4SpokeImplementationDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeImplementationDeployProcedure.sol';

contract AaveV4SpokeImplementationDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deploySpokeImplementation(
    address oracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) external returns (address) {
    return
      AaveV4SpokeImplementationDeployProcedure.deploySpokeImplementation(
        oracle,
        spokeBytecode,
        maxUserReservesLimit,
        salt
      );
  }
}
