// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title BatchReports Library
/// @author Aave Labs
/// @notice Report structs returned by each deployment batch, including deployed contract addresses.
library BatchReports {
  /// @dev accessManager The deployed AccessManagerEnumerable contract address.
  struct AuthorityBatchReport {
    address accessManager;
  }

  /// @dev hubConfigurator The deployed HubConfigurator contract address.
  /// @dev spokeConfigurator The deployed SpokeConfigurator contract address.
  struct ConfiguratorBatchReport {
    address hubConfigurator;
    address spokeConfigurator;
  }

  /// @dev spokeProxy The Spoke proxy deployed through the HubSpokeFactory.
  /// @dev spokeImplementation The canonical Spoke implementation the proxy points to.
  /// @dev aaveOracle The AaveOracle bound to the Spoke proxy.
  struct SpokeInstanceBatchReport {
    address spokeProxy;
    address spokeImplementation;
    address aaveOracle;
  }

  /// @dev hubProxy The Hub proxy deployed through the HubSpokeFactory.
  /// @dev hubImplementation The canonical Hub implementation the proxy points to.
  /// @dev irStrategy The InterestRateStrategy bound to the Hub proxy.
  struct HubInstanceBatchReport {
    address hubProxy;
    address hubImplementation;
    address irStrategy;
  }

  /// @dev treasurySpoke The TreasurySpoke proxy deployed through the HubSpokeFactory.
  struct TreasurySpokeBatchReport {
    address treasurySpoke;
  }

  /// @dev hubImplementation The deployed canonical Hub implementation contract address.
  struct HubImplementationBatchReport {
    address hubImplementation;
  }

  /// @dev spokeImplementation The deployed canonical Spoke implementation contract address.
  struct SpokeImplementationBatchReport {
    address spokeImplementation;
  }

  /// @dev hubSpokeFactory The deployed HubSpokeFactory proxy contract address.
  /// @dev hubSpokeFactoryImplementation The deployed HubSpokeFactory implementation contract address.
  /// @dev treasurySpokeImplementation The deployed canonical TreasurySpoke implementation contract address.
  struct HubSpokeFactoryBatchReport {
    address hubSpokeFactory;
    address hubSpokeFactoryImplementation;
    address treasurySpokeImplementation;
  }

  /// @dev signatureGateway The deployed SignatureGateway contract address.
  /// @dev nativeGateway The deployed NativeTokenGateway contract address.
  struct GatewaysBatchReport {
    address signatureGateway;
    address nativeGateway;
  }

  /// @dev giverPositionManager The deployed GiverPositionManager contract address.
  /// @dev takerPositionManager The deployed TakerPositionManager contract address.
  /// @dev configPositionManager The deployed ConfigPositionManager contract address.
  struct PositionManagerBatchReport {
    address giverPositionManager;
    address takerPositionManager;
    address configPositionManager;
  }

  /// @dev tokenizationSpokeImplementation The deployed canonical TokenizationSpoke implementation contract address.
  struct TokenizationSpokeImplementationBatchReport {
    address tokenizationSpokeImplementation;
  }
}
