// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

contract MetadataLoggerTest is Test {
  string internal constant OUTPUT_DIR = 'output/reports/deployments/test/';

  function _fullReport()
    internal
    returns (OrchestrationReports.FullDeploymentReport memory report)
  {
    report.salt = keccak256('test-salt');
    report.authorityBatchReport.accessManager = makeAddr('accessManager');
    report.configuratorBatchReport.hubConfigurator = makeAddr('hubConfigurator');
    report.configuratorBatchReport.spokeConfigurator = makeAddr('spokeConfigurator');
    report.treasurySpokeBatchReport.treasurySpoke = makeAddr('treasurySpoke');

    report.hubInstanceBatchReports = new OrchestrationReports.HubDeploymentReport[](2);
    report.hubInstanceBatchReports[0].label = 'core';
    report.hubInstanceBatchReports[0].report.hubProxy = makeAddr('hub-core');
    report.hubInstanceBatchReports[0].report.hubImplementation = makeAddr('hubImpl-core');
    report.hubInstanceBatchReports[0].report.irStrategy = makeAddr('ir-core');
    report.hubInstanceBatchReports[1].label = 'prime';
    report.hubInstanceBatchReports[1].report.hubProxy = makeAddr('hub-prime');
    report.hubInstanceBatchReports[1].report.hubImplementation = makeAddr('hubImpl-prime');
    report.hubInstanceBatchReports[1].report.irStrategy = makeAddr('ir-prime');

    report.spokeInstanceBatchReports = new OrchestrationReports.SpokeDeploymentReport[](2);
    report.spokeInstanceBatchReports[0].label = 'mainnet';
    report.spokeInstanceBatchReports[0].report.spokeProxy = makeAddr('spoke-mainnet');
    report.spokeInstanceBatchReports[0].report.spokeImplementation = makeAddr('spokeImpl-mainnet');
    report.spokeInstanceBatchReports[0].report.aaveOracle = makeAddr('oracle-mainnet');
    report.spokeInstanceBatchReports[1].label = 'lrt';
    report.spokeInstanceBatchReports[1].report.spokeProxy = makeAddr('spoke-lrt');
    report.spokeInstanceBatchReports[1].report.spokeImplementation = makeAddr('spokeImpl-lrt');
    report.spokeInstanceBatchReports[1].report.aaveOracle = makeAddr('oracle-lrt');

    report.gatewaysBatchReport.nativeGateway = makeAddr('nativeGateway');
    report.gatewaysBatchReport.signatureGateway = makeAddr('signatureGateway');

    report.positionManagerBatchReport.giverPositionManager = makeAddr('giverPM');
    report.positionManagerBatchReport.takerPositionManager = makeAddr('takerPM');
    report.positionManagerBatchReport.configPositionManager = makeAddr('configPM');

    report.tokenizationSpokeBeaconBatchReport.tokenizationSpokeBeacon = makeAddr(
      'tokenizationSpokeBeacon'
    );
    report.tokenizationSpokeBeaconBatchReport.tokenizationSpokeImplementation = makeAddr(
      'tokenizationSpokeImpl'
    );
  }

  function test_writeJsonReportMarket_fullReport() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    // Core fields
    assertEq(vm.parseJsonBytes32(json, '$.salt'), report.salt);
    assertEq(
      vm.parseJsonAddress(json, '$.accessManager'),
      report.authorityBatchReport.accessManager
    );
    assertEq(
      vm.parseJsonAddress(json, '$.hubConfigurator'),
      report.configuratorBatchReport.hubConfigurator
    );
    assertEq(
      vm.parseJsonAddress(json, '$.spokeConfigurator'),
      report.configuratorBatchReport.spokeConfigurator
    );
    assertEq(
      vm.parseJsonAddress(json, '$.treasurySpoke'),
      report.treasurySpokeBatchReport.treasurySpoke
    );

    // Hubs
    assertEq(
      vm.parseJsonAddress(json, '$.hub.core'),
      report.hubInstanceBatchReports[0].report.hubProxy
    );
    assertEq(
      vm.parseJsonAddress(json, '$.hubImplementation.core'),
      report.hubInstanceBatchReports[0].report.hubImplementation
    );
    assertEq(
      vm.parseJsonAddress(json, '$.irStrategy.core'),
      report.hubInstanceBatchReports[0].report.irStrategy
    );
    assertEq(
      vm.parseJsonAddress(json, '$.hub.prime'),
      report.hubInstanceBatchReports[1].report.hubProxy
    );

    // Spokes
    assertEq(
      vm.parseJsonAddress(json, '$.spoke.mainnet'),
      report.spokeInstanceBatchReports[0].report.spokeProxy
    );
    assertEq(
      vm.parseJsonAddress(json, '$.spokeImplementation.mainnet'),
      report.spokeInstanceBatchReports[0].report.spokeImplementation
    );
    assertEq(
      vm.parseJsonAddress(json, '$.oracle.mainnet'),
      report.spokeInstanceBatchReports[0].report.aaveOracle
    );
    assertEq(
      vm.parseJsonAddress(json, '$.spoke.lrt'),
      report.spokeInstanceBatchReports[1].report.spokeProxy
    );

    // Gateways
    assertEq(
      vm.parseJsonAddress(json, '$.nativeTokenGateway'),
      report.gatewaysBatchReport.nativeGateway
    );
    assertEq(
      vm.parseJsonAddress(json, '$.signatureGateway'),
      report.gatewaysBatchReport.signatureGateway
    );

    // Position Managers
    assertEq(
      vm.parseJsonAddress(json, '$.giverPositionManager'),
      report.positionManagerBatchReport.giverPositionManager
    );
    assertEq(
      vm.parseJsonAddress(json, '$.takerPositionManager'),
      report.positionManagerBatchReport.takerPositionManager
    );
    assertEq(
      vm.parseJsonAddress(json, '$.configPositionManager'),
      report.positionManagerBatchReport.configPositionManager
    );

    // TokenizationSpoke beacon + implementation
    assertEq(
      vm.parseJsonAddress(json, '$.tokenizationSpokeBeacon'),
      report.tokenizationSpokeBeaconBatchReport.tokenizationSpokeBeacon
    );
    assertEq(
      vm.parseJsonAddress(json, '$.tokenizationSpokeImplementation'),
      report.tokenizationSpokeBeaconBatchReport.tokenizationSpokeImplementation
    );
  }

  function test_writeJsonReportMarket_noTokenizationSpokeBeacon() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();
    report.tokenizationSpokeBeaconBatchReport.tokenizationSpokeBeacon = address(0);
    report.tokenizationSpokeBeaconBatchReport.tokenizationSpokeImplementation = address(0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    assertFalse(vm.keyExistsJson(json, '$.tokenizationSpokeBeacon'));
    assertFalse(vm.keyExistsJson(json, '$.tokenizationSpokeImplementation'));
  }

  function test_writeJsonReportMarket_noGateways() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();
    report.gatewaysBatchReport.nativeGateway = address(0);
    report.gatewaysBatchReport.signatureGateway = address(0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    assertFalse(vm.keyExistsJson(json, '$.nativeTokenGateway'));
    assertFalse(vm.keyExistsJson(json, '$.signatureGateway'));
    // Core fields still present
    assertEq(
      vm.parseJsonAddress(json, '$.accessManager'),
      report.authorityBatchReport.accessManager
    );
  }

  function test_writeJsonReportMarket_noPositionManagers() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();
    report.positionManagerBatchReport.giverPositionManager = address(0);
    report.positionManagerBatchReport.takerPositionManager = address(0);
    report.positionManagerBatchReport.configPositionManager = address(0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    assertFalse(vm.keyExistsJson(json, '$.giverPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.takerPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.configPositionManager'));
  }

  function test_writeJsonReportMarket_noOptionalFields() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();
    report.gatewaysBatchReport.nativeGateway = address(0);
    report.gatewaysBatchReport.signatureGateway = address(0);
    report.positionManagerBatchReport.giverPositionManager = address(0);
    report.positionManagerBatchReport.takerPositionManager = address(0);
    report.positionManagerBatchReport.configPositionManager = address(0);
    report.tokenizationSpokeBeaconBatchReport.tokenizationSpokeBeacon = address(0);
    report.tokenizationSpokeBeaconBatchReport.tokenizationSpokeImplementation = address(0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    // No optional fields
    assertFalse(vm.keyExistsJson(json, '$.nativeTokenGateway'));
    assertFalse(vm.keyExistsJson(json, '$.signatureGateway'));
    assertFalse(vm.keyExistsJson(json, '$.giverPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.takerPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.configPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.tokenizationSpokeBeacon'));
    assertFalse(vm.keyExistsJson(json, '$.tokenizationSpokeImplementation'));

    // Core fields present
    assertEq(
      vm.parseJsonAddress(json, '$.accessManager'),
      report.authorityBatchReport.accessManager
    );
    assertTrue(vm.keyExistsJson(json, '$.hub'));
    assertTrue(vm.keyExistsJson(json, '$.spoke'));
  }

  function test_writeJsonReportMarket_singleHubSingleSpoke() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report;

    report.salt = keccak256('single');
    report.authorityBatchReport.accessManager = makeAddr('am');
    report.configuratorBatchReport.hubConfigurator = makeAddr('hc');
    report.configuratorBatchReport.spokeConfigurator = makeAddr('sc');
    report.treasurySpokeBatchReport.treasurySpoke = makeAddr('ts');

    report.hubInstanceBatchReports = new OrchestrationReports.HubDeploymentReport[](1);
    report.hubInstanceBatchReports[0].label = 'only';
    report.hubInstanceBatchReports[0].report.hubProxy = makeAddr('hub-only');
    report.hubInstanceBatchReports[0].report.hubImplementation = makeAddr('hubImpl-only');
    report.hubInstanceBatchReports[0].report.irStrategy = makeAddr('ir-only');

    report.spokeInstanceBatchReports = new OrchestrationReports.SpokeDeploymentReport[](1);
    report.spokeInstanceBatchReports[0].label = 'solo';
    report.spokeInstanceBatchReports[0].report.spokeProxy = makeAddr('spoke-solo');
    report.spokeInstanceBatchReports[0].report.spokeImplementation = makeAddr('spokeImpl-solo');
    report.spokeInstanceBatchReports[0].report.aaveOracle = makeAddr('oracle-solo');

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    assertEq(vm.parseJsonAddress(json, '$.hub.only'), makeAddr('hub-only'));
    assertEq(vm.parseJsonAddress(json, '$.spoke.solo'), makeAddr('spoke-solo'));
    assertEq(vm.parseJsonAddress(json, '$.oracle.solo'), makeAddr('oracle-solo'));
  }

  function test_writeJsonReportMarket_emptyHubsAndSpokes() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report;

    report.salt = keccak256('empty');
    report.authorityBatchReport.accessManager = makeAddr('am');
    report.configuratorBatchReport.hubConfigurator = makeAddr('hc');
    report.configuratorBatchReport.spokeConfigurator = makeAddr('sc');
    report.treasurySpokeBatchReport.treasurySpoke = makeAddr('ts');
    report.hubInstanceBatchReports = new OrchestrationReports.HubDeploymentReport[](0);
    report.spokeInstanceBatchReports = new OrchestrationReports.SpokeDeploymentReport[](0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    assertEq(vm.parseJsonAddress(json, '$.accessManager'), makeAddr('am'));
    assertEq(vm.parseJsonBytes32(json, '$.salt'), keccak256('empty'));
  }
}
