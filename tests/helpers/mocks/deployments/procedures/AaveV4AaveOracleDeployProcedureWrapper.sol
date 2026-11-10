// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';

contract AaveV4AaveOracleDeployProcedureWrapper is AaveV4AaveOracleDeployProcedure {
  bool public IS_TEST = true;

  function deployAaveOracle(uint8 decimals, bytes32 salt) external returns (address) {
    return _deployAaveOracle(decimals, salt);
  }
}
