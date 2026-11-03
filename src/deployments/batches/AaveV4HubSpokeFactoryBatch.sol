// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4HubSpokeFactoryDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4HubSpokeFactoryDeployProcedure.sol';
import {AaveV4TreasurySpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TreasurySpokeDeployProcedure.sol';

/// @title AaveV4HubSpokeFactoryBatch
/// @author Aave Labs
/// @notice Deploys the canonical TreasurySpoke implementation and the HubSpokeFactory, producing a batch report.
contract AaveV4HubSpokeFactoryBatch is
  AaveV4HubSpokeFactoryDeployProcedure,
  AaveV4TreasurySpokeDeployProcedure
{
  BatchReports.HubSpokeFactoryBatchReport internal _report;

  /// @dev Constructor.
  /// @param hubImplementation_ The canonical HubInstance implementation.
  /// @param spokeImplementation_ The canonical SpokeInstance implementation.
  /// @param tokenizationSpokeImplementation_ The canonical TokenizationSpokeInstance implementation.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(
    address hubImplementation_,
    address spokeImplementation_,
    address tokenizationSpokeImplementation_,
    bytes32 salt_
  ) {
    address treasurySpokeImplementation = _deployTreasurySpokeImplementation(salt_);
    _report = BatchReports.HubSpokeFactoryBatchReport({
      hubSpokeFactory: _deployHubSpokeFactory({
        hubImplementation: hubImplementation_,
        spokeImplementation: spokeImplementation_,
        treasurySpokeImplementation: treasurySpokeImplementation,
        tokenizationSpokeImplementation: tokenizationSpokeImplementation_,
        salt: salt_
      }),
      treasurySpokeImplementation: treasurySpokeImplementation
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.HubSpokeFactoryBatchReport memory) {
    return _report;
  }
}
