// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4EmergencyStewardDeployProcedure} from 'src/deployments/procedures/deploy/emergency/AaveV4EmergencyStewardDeployProcedure.sol';

/// @title AaveV4EmergencyStewardBatch
/// @author Aave Labs
/// @notice Deploys the EmergencySteward contract, producing a batch report.
contract AaveV4EmergencyStewardBatch is AaveV4EmergencyStewardDeployProcedure {
  BatchReports.EmergencyStewardBatchReport internal _report;

  /// @dev Constructor.
  /// @param authority_ The access control authority for the EmergencySteward.
  /// @param spokeConfigurator_ The address of the SpokeConfigurator the EmergencySteward calls.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address authority_, address spokeConfigurator_, bytes32 salt_) {
    address emergencySteward = _deployEmergencySteward({
      authority: authority_,
      spokeConfigurator: spokeConfigurator_,
      salt: salt_
    });
    _report = BatchReports.EmergencyStewardBatchReport({emergencySteward: emergencySteward});
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.EmergencyStewardBatchReport memory) {
    return _report;
  }
}
