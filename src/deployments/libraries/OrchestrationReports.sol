// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

/// @title OrchestrationReports Library
/// @author Aave Labs
/// @notice Aggregated deployment reports produced by the orchestration layer.
library OrchestrationReports {
  /// @dev label The Spoke instance label.
  /// @dev report The batch-level deployment report for this Spoke.
  struct SpokeDeploymentReport {
    string label;
    BatchReports.SpokeInstanceBatchReport report;
  }

  /// @dev label The Hub instance label.
  /// @dev report The batch-level deployment report for this Hub.
  struct HubDeploymentReport {
    string label;
    BatchReports.HubInstanceBatchReport report;
  }

  /// @dev authorityBatchReport AccessManager deployment report.
  /// @dev hubConfiguratorBatchReport HubConfigurator deployment report.
  /// @dev spokeConfiguratorBatchReport SpokeConfigurator deployment report.
  /// @dev treasurySpokeBatchReport TreasurySpoke deployment report.
  /// @dev spokeInstanceBatchReports Per-spoke deployment reports.
  /// @dev hubInstanceBatchReports Per-hub deployment reports.
  /// @dev gatewaysBatchReport Gateway deployment report.
  /// @dev giverPositionManagerBatchReport GiverPositionManager deployment report.
  /// @dev takerPositionManagerBatchReport TakerPositionManager deployment report.
  /// @dev configPositionManagerBatchReport ConfigPositionManager deployment report.
  /// @dev salt The salt used to derive deterministic contract addresses.
  struct FullDeploymentReport {
    BatchReports.AuthorityBatchReport authorityBatchReport;
    BatchReports.HubConfiguratorBatchReport hubConfiguratorBatchReport;
    BatchReports.SpokeConfiguratorBatchReport spokeConfiguratorBatchReport;
    BatchReports.TreasurySpokeBatchReport treasurySpokeBatchReport;
    SpokeDeploymentReport[] spokeInstanceBatchReports;
    HubDeploymentReport[] hubInstanceBatchReports;
    BatchReports.GatewaysBatchReport gatewaysBatchReport;
    BatchReports.GiverPositionManagerBatchReport giverPositionManagerBatchReport;
    BatchReports.TakerPositionManagerBatchReport takerPositionManagerBatchReport;
    BatchReports.ConfigPositionManagerBatchReport configPositionManagerBatchReport;
    bytes32 salt;
  }
}
