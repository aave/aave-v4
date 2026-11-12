// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';

contract MetadataLoggerTest is Test {
  string internal constant OUTPUT_DIR = 'output/reports/deployments/test/';

  function _fullReport()
    internal
    returns (OrchestrationReports.FullDeploymentReport memory report)
  {
    report.salt = keccak256('test-salt');
    report.accessManager = makeAddr('accessManager');
    report.hubConfigurator = makeAddr('hubConfigurator');
    report.spokeConfigurator = makeAddr('spokeConfigurator');
    report.treasurySpoke = makeAddr('treasurySpoke');

    report.hubs = new OrchestrationReports.HubDeploymentReport[](2);
    report.hubs[0].label = 'core';
    report.hubs[0].hubProxy = makeAddr('hub-core');
    report.hubs[0].hubImplementation = makeAddr('hubImpl-core');
    report.hubs[0].irStrategy = makeAddr('ir-core');
    report.hubs[1].label = 'prime';
    report.hubs[1].hubProxy = makeAddr('hub-prime');
    report.hubs[1].hubImplementation = makeAddr('hubImpl-prime');
    report.hubs[1].irStrategy = makeAddr('ir-prime');

    report.spokes = new OrchestrationReports.SpokeDeploymentReport[](2);
    report.spokes[0].label = 'mainnet';
    report.spokes[0].spokeProxy = makeAddr('spoke-mainnet');
    report.spokes[0].spokeImplementation = makeAddr('spokeImpl-mainnet');
    report.spokes[0].aaveOracle = makeAddr('oracle-mainnet');
    report.spokes[1].label = 'lrt';
    report.spokes[1].spokeProxy = makeAddr('spoke-lrt');
    report.spokes[1].spokeImplementation = makeAddr('spokeImpl-lrt');
    report.spokes[1].aaveOracle = makeAddr('oracle-lrt');

    report.nativeGateway = makeAddr('nativeGateway');
    report.signatureGateway = makeAddr('signatureGateway');

    report.giverPositionManager = makeAddr('giverPM');
    report.takerPositionManager = makeAddr('takerPM');
    report.configPositionManager = makeAddr('configPM');
  }

  function test_writeJsonReportMarket_fullReport() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    // Core fields
    assertEq(vm.parseJsonBytes32(json, '$.salt'), report.salt);
    assertEq(vm.parseJsonAddress(json, '$.accessManager'), report.accessManager);
    assertEq(vm.parseJsonAddress(json, '$.hubConfigurator'), report.hubConfigurator);
    assertEq(vm.parseJsonAddress(json, '$.spokeConfigurator'), report.spokeConfigurator);
    assertEq(vm.parseJsonAddress(json, '$.treasurySpoke'), report.treasurySpoke);

    // Hubs
    assertEq(vm.parseJsonAddress(json, '$.hub.core'), report.hubs[0].hubProxy);
    assertEq(
      vm.parseJsonAddress(json, '$.hubImplementation.core'),
      report.hubs[0].hubImplementation
    );
    assertEq(vm.parseJsonAddress(json, '$.irStrategy.core'), report.hubs[0].irStrategy);
    assertEq(vm.parseJsonAddress(json, '$.hub.prime'), report.hubs[1].hubProxy);

    // Spokes
    assertEq(vm.parseJsonAddress(json, '$.spoke.mainnet'), report.spokes[0].spokeProxy);
    assertEq(
      vm.parseJsonAddress(json, '$.spokeImplementation.mainnet'),
      report.spokes[0].spokeImplementation
    );
    assertEq(vm.parseJsonAddress(json, '$.oracle.mainnet'), report.spokes[0].aaveOracle);
    assertEq(vm.parseJsonAddress(json, '$.spoke.lrt'), report.spokes[1].spokeProxy);

    // Gateways
    assertEq(vm.parseJsonAddress(json, '$.nativeTokenGateway'), report.nativeGateway);
    assertEq(vm.parseJsonAddress(json, '$.signatureGateway'), report.signatureGateway);

    // Position Managers
    assertEq(vm.parseJsonAddress(json, '$.giverPositionManager'), report.giverPositionManager);
    assertEq(vm.parseJsonAddress(json, '$.takerPositionManager'), report.takerPositionManager);
    assertEq(vm.parseJsonAddress(json, '$.configPositionManager'), report.configPositionManager);
  }

  function test_writeJsonReportMarket_noGateways() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();
    report.nativeGateway = address(0);
    report.signatureGateway = address(0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    assertFalse(vm.keyExistsJson(json, '$.nativeTokenGateway'));
    assertFalse(vm.keyExistsJson(json, '$.signatureGateway'));
    // Core fields still present
    assertEq(vm.parseJsonAddress(json, '$.accessManager'), report.accessManager);
  }

  function test_writeJsonReportMarket_noPositionManagers() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();
    report.giverPositionManager = address(0);
    report.takerPositionManager = address(0);
    report.configPositionManager = address(0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    assertFalse(vm.keyExistsJson(json, '$.giverPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.takerPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.configPositionManager'));
  }

  function test_writeJsonReportMarket_noOptionalFields() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report = _fullReport();
    report.nativeGateway = address(0);
    report.signatureGateway = address(0);
    report.giverPositionManager = address(0);
    report.takerPositionManager = address(0);
    report.configPositionManager = address(0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    // No optional fields
    assertFalse(vm.keyExistsJson(json, '$.nativeTokenGateway'));
    assertFalse(vm.keyExistsJson(json, '$.signatureGateway'));
    assertFalse(vm.keyExistsJson(json, '$.giverPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.takerPositionManager'));
    assertFalse(vm.keyExistsJson(json, '$.configPositionManager'));

    // Core fields present
    assertEq(vm.parseJsonAddress(json, '$.accessManager'), report.accessManager);
    assertTrue(vm.keyExistsJson(json, '$.hub'));
    assertTrue(vm.keyExistsJson(json, '$.spoke'));
  }

  function test_writeJsonReportMarket_singleHubSingleSpoke() public {
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    OrchestrationReports.FullDeploymentReport memory report;

    report.salt = keccak256('single');
    report.accessManager = makeAddr('am');
    report.hubConfigurator = makeAddr('hc');
    report.spokeConfigurator = makeAddr('sc');
    report.treasurySpoke = makeAddr('ts');

    report.hubs = new OrchestrationReports.HubDeploymentReport[](1);
    report.hubs[0].label = 'only';
    report.hubs[0].hubProxy = makeAddr('hub-only');
    report.hubs[0].hubImplementation = makeAddr('hubImpl-only');
    report.hubs[0].irStrategy = makeAddr('ir-only');

    report.spokes = new OrchestrationReports.SpokeDeploymentReport[](1);
    report.spokes[0].label = 'solo';
    report.spokes[0].spokeProxy = makeAddr('spoke-solo');
    report.spokes[0].spokeImplementation = makeAddr('spokeImpl-solo');
    report.spokes[0].aaveOracle = makeAddr('oracle-solo');

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
    report.accessManager = makeAddr('am');
    report.hubConfigurator = makeAddr('hc');
    report.spokeConfigurator = makeAddr('sc');
    report.treasurySpoke = makeAddr('ts');
    report.hubs = new OrchestrationReports.HubDeploymentReport[](0);
    report.spokes = new OrchestrationReports.SpokeDeploymentReport[](0);

    logger.writeJsonReportMarket(report);
    string memory json = logger.getJson();

    assertEq(vm.parseJsonAddress(json, '$.accessManager'), makeAddr('am'));
    assertEq(vm.parseJsonBytes32(json, '$.salt'), keccak256('empty'));
  }
}
