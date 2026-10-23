// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';
import {AaveV4InterestRateStrategyDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4InterestRateStrategyDeployProcedure.sol';

/// @title AaveV4HubInstanceBatch
/// @author Aave Labs
/// @notice Deploys a Hub proxy in front of an already deployed implementation and its InterestRateStrategy, producing a batch report.
contract AaveV4HubInstanceBatch is
  AaveV4HubDeployProcedure,
  AaveV4InterestRateStrategyDeployProcedure
{
  BatchReports.HubInstanceBatchReport internal _report;

  /// @dev Constructor.
  /// @param proxyAdminOwner_ The owner of the proxy admin.
  /// @param authority_ The access-control authority for the Hub.
  /// @param hubImplementation_ The address of the deployed Hub implementation.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(
    address proxyAdminOwner_,
    address authority_,
    address hubImplementation_,
    bytes32 salt_
  ) {
    address hubProxy = _deployHubProxy({
      proxyAdminOwner: proxyAdminOwner_,
      authority: authority_,
      hubImplementation: hubImplementation_,
      salt: salt_
    });
    address irStrategy = _deployInterestRateStrategy({hub: hubProxy, salt: salt_});

    _report = BatchReports.HubInstanceBatchReport({
      hubImplementation: hubImplementation_,
      hubProxy: hubProxy,
      irStrategy: irStrategy
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.HubInstanceBatchReport memory) {
    return _report;
  }
}
