// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4TreasurySpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TreasurySpokeDeployProcedure.sol';

/// @title AaveV4TreasurySpokeBatch
/// @author Aave Labs
/// @notice Deploys the TreasurySpoke contract, producing a batch report.
contract AaveV4TreasurySpokeBatch is AaveV4TreasurySpokeDeployProcedure {
  BatchReports.TreasurySpokeBatchReport internal _report;

  /// @dev Constructor.
  /// @param owner_ The owner of the TreasurySpoke proxy admin and initializer.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  /// @param hub_ The hub connected with Treasury Spoke.
  constructor(address owner_, bytes32 salt_, address hub_) {
    address treasurySpoke = _deployTreasurySpoke({owner: owner_, salt: salt_, hub: hub_});
    _report = BatchReports.TreasurySpokeBatchReport({treasurySpoke: treasurySpoke});
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.TreasurySpokeBatchReport memory) {
    return _report;
  }
}
