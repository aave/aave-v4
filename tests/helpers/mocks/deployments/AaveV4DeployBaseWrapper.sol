// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

contract AaveV4DeployBaseWrapper {
  bool public IS_TEST = true;

  function deploySpokeInstanceBatch(
    address proxyAdminOwner,
    address authority,
    bytes memory spokeBytecode,
    uint8 oracleDecimals,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) external returns (BatchReports.SpokeInstanceBatchReport memory) {
    return
      AaveV4DeployBase.deploySpokeInstanceBatch({
        proxyAdminOwner: proxyAdminOwner,
        authority: authority,
        spokeBytecode: spokeBytecode,
        oracleDecimals: oracleDecimals,
        maxUserReservesLimit: maxUserReservesLimit,
        salt: salt
      });
  }
}
