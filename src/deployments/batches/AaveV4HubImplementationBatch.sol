// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';

/// @title AaveV4HubImplementationBatch
/// @author Aave Labs
/// @notice Deploys the canonical Hub implementation, producing a batch report.
contract AaveV4HubImplementationBatch is AaveV4HubDeployProcedure {
  BatchReports.HubImplementationBatchReport internal _report;

  /// @dev Constructor.
  /// @param hubBytecode_ The creation bytecode of the Hub implementation.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(bytes memory hubBytecode_, bytes32 salt_) {
    _report = BatchReports.HubImplementationBatchReport({
      hubImplementation: _deployHubImplementation(hubBytecode_, salt_)
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.HubImplementationBatchReport memory) {
    return _report;
  }
}
