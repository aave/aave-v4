// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';

contract AaveV4SpokeDeployProcedureWrapper is AaveV4SpokeDeployProcedure {
  bool public IS_TEST = true;

  function deploySpokeImplementation(
    bytes memory spokeBytecode,
    bytes32 salt
  ) external returns (address) {
    return _deploySpokeImplementation(spokeBytecode, salt);
  }
}
