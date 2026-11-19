// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4HubConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubConfiguratorDeployProcedure.sol';

/// @title AaveV4HubConfiguratorBatch
/// @author Aave Labs
/// @notice Deploys the HubConfigurator contract, producing a batch report.
contract AaveV4HubConfiguratorBatch is AaveV4HubConfiguratorDeployProcedure {
  BatchReports.HubConfiguratorBatchReport internal _report;

  /// @dev Constructor.
  /// @param authority_ The access-control authority for the HubConfigurator.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address authority_, bytes32 salt_) {
    _report = BatchReports.HubConfiguratorBatchReport({
      hubConfigurator: _deployHubConfigurator({authority: authority_, salt: salt_})
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.HubConfiguratorBatchReport memory) {
    return _report;
  }
}
