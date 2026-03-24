// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';
import {AaveV4InterestRateStrategyDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4InterestRateStrategyDeployProcedure.sol';

contract AaveV4HubInstanceBatch is
  AaveV4HubDeployProcedure,
  AaveV4InterestRateStrategyDeployProcedure
{
  BatchReports.HubInstanceBatchReport internal _report;

  constructor(
    address hubProxyAdminOwner_,
    address authority_,
    bytes memory hubBytecode_,
    bytes32 salt_
  ) {
    (address hubProxy, address hubImplementation) = _deployUpgradeableHubInstance({
      hubProxyAdminOwner: hubProxyAdminOwner_,
      authority: authority_,
      hubBytecode: hubBytecode_,
      salt: salt_
    });
    address irStrategy = _deployInterestRateStrategy({hub: hubProxy, salt: salt_});

    _report = BatchReports.HubInstanceBatchReport({
      hubImplementation: hubImplementation,
      hubProxy: hubProxy,
      irStrategy: irStrategy
    });
  }

  function getReport() external view returns (BatchReports.HubInstanceBatchReport memory) {
    return _report;
  }
}
