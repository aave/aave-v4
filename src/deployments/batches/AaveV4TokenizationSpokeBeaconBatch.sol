// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4TokenizationSpokeBeaconDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeBeaconDeployProcedure.sol';

/// @title AaveV4TokenizationSpokeBeaconBatch
/// @author Aave Labs
/// @notice Deploys the shared TokenizationSpoke implementation and its UpgradeableBeacon, producing a batch report.
contract AaveV4TokenizationSpokeBeaconBatch is AaveV4TokenizationSpokeBeaconDeployProcedure {
  BatchReports.TokenizationSpokeBeaconBatchReport internal _report;

  /// @dev Constructor.
  /// @param beaconOwner_ The owner of the beacon, able to upgrade the shared implementation.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address beaconOwner_, bytes32 salt_) {
    (
      address tokenizationSpokeBeacon,
      address tokenizationSpokeImplementation
    ) = _deployTokenizationSpokeBeacon({beaconOwner: beaconOwner_, salt: salt_});

    _report = BatchReports.TokenizationSpokeBeaconBatchReport({
      tokenizationSpokeImplementation: tokenizationSpokeImplementation,
      tokenizationSpokeBeacon: tokenizationSpokeBeacon
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport()
    external
    view
    returns (BatchReports.TokenizationSpokeBeaconBatchReport memory)
  {
    return _report;
  }
}
