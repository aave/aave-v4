// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4ConfigPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4ConfigPositionManagerDeployProcedure.sol';

/// @title AaveV4ConfigPositionManagerBatch
/// @author Aave Labs
/// @notice Deploys the ConfigPositionManager contract, producing a batch report.
contract AaveV4ConfigPositionManagerBatch is AaveV4ConfigPositionManagerDeployProcedure {
  BatchReports.ConfigPositionManagerBatchReport internal _report;

  /// @dev Constructor.
  /// @param owner_ The owner of the ConfigPositionManager.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address owner_, bytes32 salt_) {
    _report = BatchReports.ConfigPositionManagerBatchReport({
      configPositionManager: _deployConfigPositionManager({owner: owner_, salt: salt_})
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport()
    external
    view
    returns (BatchReports.ConfigPositionManagerBatchReport memory)
  {
    return _report;
  }
}
