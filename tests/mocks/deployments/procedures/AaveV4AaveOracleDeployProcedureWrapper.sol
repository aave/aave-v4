// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';

contract AaveV4AaveOracleDeployProcedureWrapper is AaveV4AaveOracleDeployProcedure {
  bool public IS_TEST = true;

  function deployAaveOracle(uint8 decimals) external returns (address) {
    return _deployAaveOracle(decimals);
  }
}
