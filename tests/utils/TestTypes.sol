// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

library TestTypes {
  struct TokenList {
    WETH9 weth;
    TestnetERC20 usdx;
    TestnetERC20 dai;
    TestnetERC20 wbtc;
    TestnetERC20 usdy;
    TestnetERC20 usdz;
  }

  struct SpokeReserveId {
    address spoke;
    uint256 reserveId;
  }

  struct TestTokensBatchReport {
    address weth;
    address[] tokens;
  }

  struct TestTokenInput {
    string name;
    string symbol;
    uint8 decimals;
  }

  struct TestHubReport {
    address hub;
    address irStrategy;
  }

  struct TestSpokeReport {
    address spoke;
    address aaveOracle;
  }

  struct TestGatewaysReport {
    address signatureGateway;
    address nativeGateway;
  }

  struct TestConfiguratorReport {
    address hubConfigurator;
    address spokeConfigurator;
  }

  struct TestEnvReport {
    address accessManager;
    address treasurySpoke;
    TestHubReport[] hubReports;
    TestSpokeReport[] spokeReports;
    TestGatewaysReport gatewaysReport;
    TestConfiguratorReport configuratorReport;
  }

  struct TestTokensReport {
    address weth;
    address[] testTokens;
  }
}
