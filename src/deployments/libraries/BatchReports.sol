// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library BatchReports {
  struct AuthorityBatchReport {
    address accessManager;
  }

  struct ConfiguratorBatchReport {
    address hubConfigurator;
    address spokeConfigurator;
  }

  struct SpokeInstanceBatchReport {
    address spokeImplementation;
    address spokeProxy;
    address aaveOracle;
  }

  struct HubInstanceBatchReport {
    address hubImplementation;
    address hubProxy;
    address irStrategy;
  }

  struct TreasurySpokeBatchReport {
    address treasurySpoke;
  }

  struct GatewaysBatchReport {
    address signatureGateway;
    address nativeGateway;
  }

  struct PositionManagerBatchReport {
    address giverPositionManager;
    address takerPositionManager;
    address configPositionManager;
  }

  struct TokenizationSpokeBatchReport {
    address tokenizationSpokeImplementation;
    address tokenizationSpokeProxy;
  }
}
