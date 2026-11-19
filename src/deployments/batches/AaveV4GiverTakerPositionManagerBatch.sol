// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4GiverPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4GiverPositionManagerDeployProcedure.sol';
import {AaveV4TakerPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4TakerPositionManagerDeployProcedure.sol';

/// @title AaveV4GiverTakerPositionManagerBatch
/// @author Aave Labs
/// @notice Deploys the GiverPositionManager and TakerPositionManager contracts, producing a batch report.
contract AaveV4GiverTakerPositionManagerBatch is
  AaveV4GiverPositionManagerDeployProcedure,
  AaveV4TakerPositionManagerDeployProcedure
{
  BatchReports.GiverTakerPositionManagerBatchReport internal _report;

  /// @dev Constructor.
  /// @param owner_ The owner of the GiverPositionManager and TakerPositionManager.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address owner_, bytes32 salt_) {
    _report = BatchReports.GiverTakerPositionManagerBatchReport({
      giverPositionManager: _deployGiverPositionManager({owner: owner_, salt: salt_}),
      takerPositionManager: _deployTakerPositionManager({owner: owner_, salt: salt_})
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport()
    external
    view
    returns (BatchReports.GiverTakerPositionManagerBatchReport memory)
  {
    return _report;
  }
}
