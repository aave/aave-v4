// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4TokenizationSpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeDeployProcedure.sol';

/// @title AaveV4TokenizationSpokeImplementationBatch
/// @author Aave Labs
/// @notice Deploys the canonical TokenizationSpoke implementation, producing a batch report.
contract AaveV4TokenizationSpokeImplementationBatch is AaveV4TokenizationSpokeDeployProcedure {
  BatchReports.TokenizationSpokeImplementationBatchReport internal _report;

  /// @dev Constructor.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(bytes32 salt_) {
    _report = BatchReports.TokenizationSpokeImplementationBatchReport({
      tokenizationSpokeImplementation: _deployTokenizationSpokeImplementation(salt_)
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport()
    external
    view
    returns (BatchReports.TokenizationSpokeImplementationBatchReport memory)
  {
    return _report;
  }
}
