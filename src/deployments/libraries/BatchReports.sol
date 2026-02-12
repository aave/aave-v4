// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library BatchReports {
  struct AccessBatchReport {
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

  struct HubBatchReport {
    address hub;
    address irStrategy;
    address treasurySpoke;
  }

  struct GatewaysBatchReport {
    address signatureGateway;
    address nativeGateway;
  }

  struct TokenizationSpokeBatchReport {
    address tokenizationSpokeImplementation;
    address tokenizationSpokeProxy;
  }
}
