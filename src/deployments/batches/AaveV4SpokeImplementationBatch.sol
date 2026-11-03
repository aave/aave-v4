// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';

/// @title AaveV4SpokeImplementationBatch
/// @author Aave Labs
/// @notice Deploys the canonical Spoke implementation, producing a batch report.
contract AaveV4SpokeImplementationBatch is AaveV4SpokeDeployProcedure {
  BatchReports.SpokeImplementationBatchReport internal _report;

  /// @dev Constructor.
  /// @param spokeBytecode_ The creation bytecode of the Spoke implementation.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(bytes memory spokeBytecode_, bytes32 salt_) {
    _report = BatchReports.SpokeImplementationBatchReport({
      spokeImplementation: _deploySpokeImplementation(spokeBytecode_, salt_)
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.SpokeImplementationBatchReport memory) {
    return _report;
  }
}
