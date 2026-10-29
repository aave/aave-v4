// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4GiverPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4GiverPositionManagerDeployProcedure.sol';

/// @title AaveV4GiverPositionManagerBatch
/// @author Aave Labs
/// @notice Deploys the GiverPositionManager contract, producing a batch report.
contract AaveV4GiverPositionManagerBatch is AaveV4GiverPositionManagerDeployProcedure {
  BatchReports.GiverPositionManagerBatchReport internal _report;

  /// @dev Constructor.
  /// @param owner_ The owner of the GiverPositionManager.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address owner_, bytes32 salt_) {
    _report = BatchReports.GiverPositionManagerBatchReport({
      giverPositionManager: _deployGiverPositionManager({owner: owner_, salt: salt_})
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.GiverPositionManagerBatchReport memory) {
    return _report;
  }
}
