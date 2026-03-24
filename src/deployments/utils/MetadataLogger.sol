// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

contract MetadataLogger is Logger {
  constructor(string memory outputPath_) Logger(outputPath_) {}

  function writeJsonReportMarket(OrchestrationReports.FullDeploymentReport memory report) public {
    _write('salt', report.salt);
    _write('accessManager', report.authorityBatchReport.accessManager);
    _write('hubConfigurator', report.configuratorBatchReport.hubConfigurator);
    _write('spokeConfigurator', report.configuratorBatchReport.spokeConfigurator);
    _write('treasurySpoke', report.treasurySpokeBatchReport.treasurySpoke);

    // Group hubs by property type
    uint256 hubLen = report.hubInstanceBatchReports.length;
    Logger.AddressEntry[] memory hubEntries = new Logger.AddressEntry[](hubLen);
    Logger.AddressEntry[] memory irEntries = new Logger.AddressEntry[](hubLen);
    for (uint256 i; i < hubLen; i++) {
      hubEntries[i] = Logger.AddressEntry({
        label: report.hubInstanceBatchReports[i].label,
        value: report.hubInstanceBatchReports[i].report.hubProxy
      });
      irEntries[i] = Logger.AddressEntry({
        label: report.hubInstanceBatchReports[i].label,
        value: report.hubInstanceBatchReports[i].report.irStrategy
      });
    }
    _writeGroup('hub', hubEntries);
    _writeGroup('irStrategy', irEntries);

    // Group spokes by property type
    uint256 spokeLen = report.spokeInstanceBatchReports.length;
    Logger.AddressEntry[] memory spokeEntries = new Logger.AddressEntry[](spokeLen);
    Logger.AddressEntry[] memory oracleEntries = new Logger.AddressEntry[](spokeLen);
    for (uint256 i; i < spokeLen; i++) {
      spokeEntries[i] = Logger.AddressEntry({
        label: report.spokeInstanceBatchReports[i].label,
        value: report.spokeInstanceBatchReports[i].report.spokeProxy
      });
      oracleEntries[i] = Logger.AddressEntry({
        label: report.spokeInstanceBatchReports[i].label,
        value: report.spokeInstanceBatchReports[i].report.aaveOracle
      });
    }
    _writeGroup('spoke', spokeEntries);
    _writeGroup('oracle', oracleEntries);

    if (report.gatewaysBatchReport.signatureGateway != address(0)) {
      _write('signatureGateway', report.gatewaysBatchReport.signatureGateway);
    }
    if (report.gatewaysBatchReport.nativeGateway != address(0)) {
      _write('nativeTokenGateway', report.gatewaysBatchReport.nativeGateway);
    }
    if (report.positionManagerBatchReport.giverPositionManager != address(0)) {
      _write('giverPositionManager', report.positionManagerBatchReport.giverPositionManager);
    }
    if (report.positionManagerBatchReport.takerPositionManager != address(0)) {
      _write('takerPositionManager', report.positionManagerBatchReport.takerPositionManager);
    }
    if (report.positionManagerBatchReport.configPositionManager != address(0)) {
      _write('configPositionManager', report.positionManagerBatchReport.configPositionManager);
    }
  }
}
