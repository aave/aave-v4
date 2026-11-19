// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeConfiguratorDeployProcedure.sol';

/// @title AaveV4SpokeConfiguratorBatch
/// @author Aave Labs
/// @notice Deploys the SpokeConfigurator contract, producing a batch report.
contract AaveV4SpokeConfiguratorBatch is AaveV4SpokeConfiguratorDeployProcedure {
  BatchReports.SpokeConfiguratorBatchReport internal _report;

  /// @dev Constructor.
  /// @param authority_ The access-control authority for the SpokeConfigurator.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address authority_, bytes32 salt_) {
    _report = BatchReports.SpokeConfiguratorBatchReport({
      spokeConfigurator: _deploySpokeConfigurator({authority: authority_, salt: salt_})
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.SpokeConfiguratorBatchReport memory) {
    return _report;
  }
}
