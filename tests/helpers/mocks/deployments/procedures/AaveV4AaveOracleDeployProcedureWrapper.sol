// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';

contract AaveV4AaveOracleDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployAaveOracle(
    address owner,
    uint8 decimals,
    bytes32 salt
  ) external returns (address aaveOracleDeployer, address aaveOracle) {
    return AaveV4AaveOracleDeployProcedure.deployAaveOracle(owner, decimals, salt);
  }

  function setAaveOracleSpoke(address aaveOracleDeployer, address spoke) external {
    AaveV4AaveOracleDeployProcedure.setAaveOracleSpoke(aaveOracleDeployer, spoke);
  }
}
