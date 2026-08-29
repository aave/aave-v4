// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4FeeSharesMinterDeployProcedure} from 'src/deployments/procedures/deploy/utils/AaveV4FeeSharesMinterDeployProcedure.sol';

/// @title AaveV4FeeSharesMinterBatch
/// @author Aave Labs
/// @notice Deploys the FeeSharesMinter contract, producing a batch report.
contract AaveV4FeeSharesMinterBatch is AaveV4FeeSharesMinterDeployProcedure {
  BatchReports.FeeSharesMinterBatchReport internal _report;

  /// @dev Constructor.
  /// @param owner_ The owner of the FeeSharesMinter.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address owner_, bytes32 salt_) {
    address feeSharesMinter = _deployFeeSharesMinter({owner: owner_, salt: salt_});
    _report = BatchReports.FeeSharesMinterBatchReport({feeSharesMinter: feeSharesMinter});
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.FeeSharesMinterBatchReport memory) {
    return _report;
  }
}
