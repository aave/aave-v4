// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title OrchestrationReports Library
/// @author Aave Labs
/// @notice Deployment reports produced by the orchestration layer, holding the deployed contract addresses.
library OrchestrationReports {
  /// @dev label The Spoke instance label.
  /// @dev spokeProxy The deployed Spoke proxy contract address.
  /// @dev spokeImplementation The deployed Spoke implementation contract address.
  /// @dev aaveOracle The deployed AaveOracle contract address.
  struct SpokeDeploymentReport {
    string label;
    address spokeProxy;
    address spokeImplementation;
    address aaveOracle;
  }

  /// @dev label The Hub instance label.
  /// @dev hubProxy The deployed Hub proxy contract address.
  /// @dev hubImplementation The deployed Hub implementation contract address.
  /// @dev irStrategy The deployed InterestRateStrategy contract address.
  struct HubDeploymentReport {
    string label;
    address hubProxy;
    address hubImplementation;
    address irStrategy;
  }

  /// @dev salt The salt used to derive deterministic contract addresses.
  /// @dev accessManager The deployed AccessManagerEnumerable contract address.
  /// @dev hubConfigurator The deployed HubConfigurator contract address.
  /// @dev spokeConfigurator The deployed SpokeConfigurator contract address.
  /// @dev treasurySpoke The deployed TreasurySpoke contract address.
  /// @dev hubs Per-hub deployment reports.
  /// @dev spokes Per-spoke deployment reports.
  /// @dev signatureGateway The deployed SignatureGateway contract address, zero if not deployed.
  /// @dev nativeGateway The deployed NativeTokenGateway contract address, zero if not deployed.
  /// @dev giverPositionManager The deployed GiverPositionManager contract address, zero if not deployed.
  /// @dev takerPositionManager The deployed TakerPositionManager contract address, zero if not deployed.
  /// @dev configPositionManager The deployed ConfigPositionManager contract address, zero if not deployed.
  struct FullDeploymentReport {
    bytes32 salt;
    address accessManager;
    address hubConfigurator;
    address spokeConfigurator;
    address treasurySpoke;
    HubDeploymentReport[] hubs;
    SpokeDeploymentReport[] spokes;
    address signatureGateway;
    address nativeGateway;
    address giverPositionManager;
    address takerPositionManager;
    address configPositionManager;
  }
}
