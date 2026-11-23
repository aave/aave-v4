// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

/// @title OrchestrationReports Library
/// @author Aave Labs
/// @notice Aggregated deployment reports produced by the orchestration layer.
library OrchestrationReports {
  /// @dev spokeProxy The Spoke proxy deployed through the HubSpokeFactory.
  /// @dev spokeImplementation The canonical Spoke implementation the proxy points to.
  /// @dev aaveOracle The AaveOracle bound to the Spoke proxy.
  struct SpokeInstanceReport {
    address spokeProxy;
    address spokeImplementation;
    address aaveOracle;
  }

  /// @dev hubProxy The Hub proxy deployed through the HubSpokeFactory.
  /// @dev hubImplementation The canonical Hub implementation the proxy points to.
  /// @dev irStrategy The InterestRateStrategy bound to the Hub proxy.
  struct HubInstanceReport {
    address hubProxy;
    address hubImplementation;
    address irStrategy;
  }

  /// @dev treasurySpoke The TreasurySpoke proxy deployed through the HubSpokeFactory.
  struct TreasurySpokeReport {
    address treasurySpoke;
  }

  /// @dev label The Spoke instance label.
  /// @dev report The deployment report for this Spoke.
  struct SpokeDeploymentReport {
    string label;
    SpokeInstanceReport report;
  }

  /// @dev label The Hub instance label.
  /// @dev report The deployment report for this Hub.
  struct HubDeploymentReport {
    string label;
    HubInstanceReport report;
  }

  /// @dev authorityBatchReport AccessManager deployment report.
  /// @dev configuratorBatchReport Configurator deployment report.
  /// @dev hubImplementationBatchReport Canonical Hub implementation deployment report.
  /// @dev spokeImplementationBatchReport Canonical Spoke implementation deployment report.
  /// @dev tokenizationSpokeImplementationBatchReport Canonical TokenizationSpoke implementation deployment report.
  /// @dev hubSpokeFactoryBatchReport HubSpokeFactory and canonical TreasurySpoke implementation deployment report.
  /// @dev treasurySpokeReport TreasurySpoke deployment report.
  /// @dev spokeDeploymentReports Per-spoke deployment reports.
  /// @dev hubDeploymentReports Per-hub deployment reports.
  /// @dev gatewaysBatchReport Gateway deployment report.
  /// @dev positionManagerBatchReport PositionManager deployment report.
  /// @dev salt The salt used to derive deterministic contract addresses.
  struct FullDeploymentReport {
    BatchReports.AuthorityBatchReport authorityBatchReport;
    BatchReports.ConfiguratorBatchReport configuratorBatchReport;
    BatchReports.HubImplementationBatchReport hubImplementationBatchReport;
    BatchReports.SpokeImplementationBatchReport spokeImplementationBatchReport;
    BatchReports.TokenizationSpokeImplementationBatchReport tokenizationSpokeImplementationBatchReport;
    BatchReports.HubSpokeFactoryBatchReport hubSpokeFactoryBatchReport;
    TreasurySpokeReport treasurySpokeReport;
    SpokeDeploymentReport[] spokeDeploymentReports;
    HubDeploymentReport[] hubDeploymentReports;
    BatchReports.GatewaysBatchReport gatewaysBatchReport;
    BatchReports.PositionManagerBatchReport positionManagerBatchReport;
    bytes32 salt;
  }
}
