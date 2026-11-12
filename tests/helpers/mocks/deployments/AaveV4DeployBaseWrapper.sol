// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

contract AaveV4DeployBaseWrapper {
  bool public IS_TEST = true;

  function deployAaveOracleBatch(
    address owner,
    uint8 oracleDecimals,
    bytes32 salt
  ) external returns (BatchReports.AaveOracleBatchReport memory) {
    return
      AaveV4DeployBase.deployAaveOracleBatch({
        owner: owner,
        oracleDecimals: oracleDecimals,
        salt: salt
      });
  }
}
