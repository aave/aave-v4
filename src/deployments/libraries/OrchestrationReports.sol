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
    BatchReports.SpokeProxyBatchReport report;
  }

  /// @dev label The Hub instance label.
  /// @dev report The batch-level deployment report for this Hub.
  struct HubDeploymentReport {
    string label;
    BatchReports.HubProxyBatchReport report;
  }

  /// @dev authorityBatchReport AccessManager deployment report.
  /// @dev hubConfiguratorBatchReport HubConfigurator deployment report.
  /// @dev spokeConfiguratorBatchReport SpokeConfigurator deployment report.
  /// @dev treasurySpokeBatchReport TreasurySpoke deployment report.
  /// @dev spokeDeploymentReports Per-spoke deployment reports.
  /// @dev hubDeploymentReports Per-hub deployment reports.
  /// @dev gatewaysBatchReport Gateway deployment report.
  /// @dev giverTakerPositionManagerBatchReport GiverPositionManager and TakerPositionManager deployment report.
  /// @dev configPositionManagerBatchReport ConfigPositionManager deployment report.
  /// @dev salt The salt used to derive deterministic contract addresses.
  struct FullDeploymentReport {
    BatchReports.AuthorityBatchReport authorityBatchReport;
    BatchReports.HubConfiguratorBatchReport hubConfiguratorBatchReport;
    BatchReports.SpokeConfiguratorBatchReport spokeConfiguratorBatchReport;
    BatchReports.TreasurySpokeBatchReport treasurySpokeBatchReport;
    SpokeDeploymentReport[] spokeDeploymentReports;
    HubDeploymentReport[] hubDeploymentReports;
    BatchReports.GatewaysBatchReport gatewaysBatchReport;
    BatchReports.GiverTakerPositionManagerBatchReport giverTakerPositionManagerBatchReport;
    BatchReports.ConfigPositionManagerBatchReport configPositionManagerBatchReport;
    bytes32 salt;
  }
}
