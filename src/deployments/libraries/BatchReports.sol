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
  struct HubConfiguratorBatchReport {
    address hubConfigurator;
  }

  /// @dev spokeConfigurator The deployed SpokeConfigurator contract address.
  struct SpokeConfiguratorBatchReport {
    address spokeConfigurator;
  }

  /// @dev aaveOracleBatch The batch that deployed the AaveOracle and binds it to its Spoke.
  /// @dev aaveOracle The deployed AaveOracle contract address.
  struct AaveOracleBatchReport {
    address aaveOracleBatch;
    address aaveOracle;
  }

  /// @dev spokeProxy The deployed Spoke proxy contract address.
  /// @dev spokeImplementation The deployed Spoke implementation contract address.
  /// @dev aaveOracle The deployed AaveOracle contract address.
  struct SpokeInstanceBatchReport {
    address spokeProxy;
    address spokeImplementation;
    address aaveOracle;
  }

  /// @dev hubProxy The deployed Hub proxy contract address.
  /// @dev hubImplementation The deployed Hub implementation contract address.
  /// @dev irStrategy The deployed InterestRateStrategy contract address.
  struct HubInstanceBatchReport {
    address hubProxy;
    address hubImplementation;
    address irStrategy;
  }

  /// @dev treasurySpoke The deployed TreasurySpoke contract address.
  struct TreasurySpokeBatchReport {
    address treasurySpoke;
  }

  /// @dev signatureGateway The deployed SignatureGateway contract address.
  /// @dev nativeGateway The deployed NativeTokenGateway contract address.
  struct GatewaysBatchReport {
    address signatureGateway;
    address nativeGateway;
  }

  /// @dev giverPositionManager The deployed GiverPositionManager contract address.
  struct GiverPositionManagerBatchReport {
    address giverPositionManager;
  }

  /// @dev takerPositionManager The deployed TakerPositionManager contract address.
  struct TakerPositionManagerBatchReport {
    address takerPositionManager;
  }

  /// @dev configPositionManager The deployed ConfigPositionManager contract address.
  struct ConfigPositionManagerBatchReport {
    address configPositionManager;
  }

  /// @dev tokenizationSpokeImplementation The deployed TokenizationSpoke implementation contract address.
  /// @dev tokenizationSpokeProxy The deployed TokenizationSpoke proxy contract address.
  struct TokenizationSpokeBatchReport {
    address tokenizationSpokeProxy;
    address tokenizationSpokeImplementation;
  }
}
