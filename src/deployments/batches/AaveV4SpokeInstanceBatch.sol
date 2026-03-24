// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';
import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

contract AaveV4SpokeInstanceBatch is AaveV4SpokeDeployProcedure, AaveV4AaveOracleDeployProcedure {
  BatchReports.SpokeInstanceBatchReport internal _report;

  constructor(
    address spokeProxyAdminOwner_,
    address authority_,
    bytes memory spokeBytecode_,
    uint8 oracleDecimals_,
    uint16 maxUserReservesLimit_,
    bytes32 salt_
  ) {
    address aaveOracle = _deployAaveOracle(oracleDecimals_);
    (address spokeProxy, address spokeImplementation) = _deployUpgradeableSpokeInstance({
      spokeProxyAdminOwner: spokeProxyAdminOwner_,
      authority: authority_,
      oracle: aaveOracle,
      spokeBytecode: spokeBytecode_,
      salt: salt_,
      maxUserReservesLimit: maxUserReservesLimit_
    });
    IAaveOracle(aaveOracle).setSpoke(spokeProxy);

    require(ISpoke(spokeProxy).ORACLE() == aaveOracle, 'spoke oracle mismatch');
    require(IAaveOracle(aaveOracle).spoke() == spokeProxy, 'oracle spoke mismatch');

    _report = BatchReports.SpokeInstanceBatchReport({
      aaveOracle: aaveOracle,
      spokeImplementation: spokeImplementation,
      spokeProxy: spokeProxy
    });
  }

  function getReport() external view returns (BatchReports.SpokeInstanceBatchReport memory) {
    return _report;
  }
}
