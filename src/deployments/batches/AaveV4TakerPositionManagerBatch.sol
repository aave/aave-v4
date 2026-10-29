// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4TakerPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4TakerPositionManagerDeployProcedure.sol';

/// @title AaveV4TakerPositionManagerBatch
/// @author Aave Labs
/// @notice Deploys the TakerPositionManager contract, producing a batch report.
contract AaveV4TakerPositionManagerBatch is AaveV4TakerPositionManagerDeployProcedure {
  BatchReports.TakerPositionManagerBatchReport internal _report;

  /// @dev Constructor.
  /// @param owner_ The owner of the TakerPositionManager.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address owner_, bytes32 salt_) {
    _report = BatchReports.TakerPositionManagerBatchReport({
      takerPositionManager: _deployTakerPositionManager({owner: owner_, salt: salt_})
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.TakerPositionManagerBatchReport memory) {
    return _report;
  }
}
