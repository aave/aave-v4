// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4FeeSharesMinterDeployProcedure} from 'src/deployments/procedures/deploy/utils/AaveV4FeeSharesMinterDeployProcedure.sol';

contract AaveV4FeeSharesMinterDeployProcedureWrapper is AaveV4FeeSharesMinterDeployProcedure {
  bool public IS_TEST = true;

  function deployFeeSharesMinter(address owner, bytes32 salt) external returns (address) {
    return _deployFeeSharesMinter(owner, salt);
  }
}
