// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4AccessManagerEnumerableDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4AccessManagerEnumerableDeployProcedure.sol';

contract AaveV4AccessManagerEnumerableDeployProcedureWrapper {
  bool public IS_TEST = true;
  function deployAccessManagerEnumerable(address admin, bytes32 salt) external returns (address) {
    return AaveV4AccessManagerEnumerableDeployProcedure.deployAccessManagerEnumerable(admin, salt);
  }
}
