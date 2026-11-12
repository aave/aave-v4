// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

/// @title MetadataLogger
/// @author Aave Labs
/// @notice Extends Logger with structured custom JSON report formatting for full deployment outputs.
contract MetadataLogger is Logger {
  /// @dev Constructor.
  /// @param outputPath_ The directory path for JSON output files.
  constructor(string memory outputPath_) Logger(outputPath_) {}

  /// @notice Writes a structured JSON report for a full market deployment.
  /// @param report The full deployment report containing all deployed addresses.
  function writeJsonReportMarket(OrchestrationReports.FullDeploymentReport memory report) public {
    _write('salt', report.salt);
    _write('accessManager', report.accessManager);
    _write('hubConfigurator', report.hubConfigurator);
    _write('spokeConfigurator', report.spokeConfigurator);
    _write('treasurySpoke', report.treasurySpoke);

    // Group hubs by property type
    uint256 hubLen = report.hubs.length;
    Logger.AddressEntry[] memory hubEntries = new Logger.AddressEntry[](hubLen);
    Logger.AddressEntry[] memory hubImplEntries = new Logger.AddressEntry[](hubLen);
    Logger.AddressEntry[] memory irEntries = new Logger.AddressEntry[](hubLen);
    for (uint256 i; i < hubLen; i++) {
      hubEntries[i] = Logger.AddressEntry({
        label: report.hubs[i].label,
        value: report.hubs[i].hubProxy
      });
      hubImplEntries[i] = Logger.AddressEntry({
        label: report.hubs[i].label,
        value: report.hubs[i].hubImplementation
      });
      irEntries[i] = Logger.AddressEntry({
        label: report.hubs[i].label,
        value: report.hubs[i].irStrategy
      });
    }
    _writeGroup('hub', hubEntries);
    _writeGroup('hubImplementation', hubImplEntries);
    _writeGroup('irStrategy', irEntries);

    // Group spokes by property type
    uint256 spokeLen = report.spokes.length;
    Logger.AddressEntry[] memory spokeEntries = new Logger.AddressEntry[](spokeLen);
    Logger.AddressEntry[] memory spokeImplEntries = new Logger.AddressEntry[](spokeLen);
    Logger.AddressEntry[] memory oracleEntries = new Logger.AddressEntry[](spokeLen);
    for (uint256 i; i < spokeLen; i++) {
      spokeEntries[i] = Logger.AddressEntry({
        label: report.spokes[i].label,
        value: report.spokes[i].spokeProxy
      });
      spokeImplEntries[i] = Logger.AddressEntry({
        label: report.spokes[i].label,
        value: report.spokes[i].spokeImplementation
      });
      oracleEntries[i] = Logger.AddressEntry({
        label: report.spokes[i].label,
        value: report.spokes[i].aaveOracle
      });
    }
    _writeGroup('spoke', spokeEntries);
    _writeGroup('spokeImplementation', spokeImplEntries);
    _writeGroup('oracle', oracleEntries);

    if (report.signatureGateway != address(0)) {
      _write('signatureGateway', report.signatureGateway);
    }
    if (report.nativeGateway != address(0)) {
      _write('nativeTokenGateway', report.nativeGateway);
    }
    if (report.giverPositionManager != address(0)) {
      _write('giverPositionManager', report.giverPositionManager);
    }
    if (report.takerPositionManager != address(0)) {
      _write('takerPositionManager', report.takerPositionManager);
    }
    if (report.configPositionManager != address(0)) {
      _write('configPositionManager', report.configPositionManager);
    }
  }
}
