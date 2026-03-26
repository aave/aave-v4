// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchTestProcedures} from 'tests/utils/BatchTestProcedures.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

/// @title PostDeploymentVerificationBase
/// @notice Abstract base for post-deployment verification tests.
///         Reads a JSON deployment report and verifies deployed contracts on a live fork.
/// @dev Run with: forge test --match-contract <Subclass> --fork-url <RPC_URL>
abstract contract PostDeploymentVerificationBase is BatchTestProcedures {
  /// @dev Full path to the deployment report JSON
  string internal _reportFile;

  function setUp() public virtual override {
    _spokePositionUpdaterRoleSelectors = Roles.getSpokePositionUpdaterRoleSelectors();
    _spokeConfiguratorRoleSelectors = Roles.getSpokeConfiguratorRoleSelectors();
    _hubFeeMinterRoleSelectors = Roles.getHubFeeMinterRoleSelectors();
    _hubConfiguratorRoleSelectors = Roles.getHubConfiguratorRoleSelectors();
    _inputs = _getSanitizedDeployInputs();
    _postDeploymentCheck = true;
  }

  /// @dev Subclasses provide the expected deploy inputs (post-sanitization).
  function _getSanitizedDeployInputs() internal virtual returns (FullDeployInputs memory);

  function _parseReport()
    internal
    view
    returns (OrchestrationReports.FullDeploymentReport memory report)
  {
    require(bytes(_reportFile).length > 0, 'PostDeploymentVerificationBase: _reportFile not set');
    string memory json = vm.readFile(_reportFile);

    // Flat fields
    report.authorityBatchReport.accessManager = vm.parseJsonAddress(json, '$.accessManager');
    report.configuratorBatchReport.hubConfigurator = vm.parseJsonAddress(json, '$.hubConfigurator');
    report.configuratorBatchReport.spokeConfigurator = vm.parseJsonAddress(
      json,
      '$.spokeConfigurator'
    );
    report.treasurySpokeBatchReport.treasurySpoke = vm.parseJsonAddress(json, '$.treasurySpoke');
    report.salt = vm.parseJsonBytes32(json, '$.salt');

    // Optional fields (conditionally written by MetadataLogger)
    if (vm.keyExistsJson(json, '$.nativeTokenGateway')) {
      report.gatewaysBatchReport.nativeGateway = vm.parseJsonAddress(json, '$.nativeTokenGateway');
    }
    if (vm.keyExistsJson(json, '$.signatureGateway')) {
      report.gatewaysBatchReport.signatureGateway = vm.parseJsonAddress(json, '$.signatureGateway');
    }
    if (vm.keyExistsJson(json, '$.giverPositionManager')) {
      report.positionManagerBatchReport.giverPositionManager = vm.parseJsonAddress(
        json,
        '$.giverPositionManager'
      );
    }
    if (vm.keyExistsJson(json, '$.takerPositionManager')) {
      report.positionManagerBatchReport.takerPositionManager = vm.parseJsonAddress(
        json,
        '$.takerPositionManager'
      );
    }
    if (vm.keyExistsJson(json, '$.configPositionManager')) {
      report.positionManagerBatchReport.configPositionManager = vm.parseJsonAddress(
        json,
        '$.configPositionManager'
      );
    }

    uint256 hubCount = _inputs.hubLabels.length;
    report.hubInstanceBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; i++) {
      string memory label = _inputs.hubLabels[i];
      report.hubInstanceBatchReports[i].label = label;

      report.hubInstanceBatchReports[i].report.hubProxy = vm.parseJsonAddress(
        json,
        string.concat('$.hub.', label)
      );
      report.hubInstanceBatchReports[i].report.irStrategy = vm.parseJsonAddress(
        json,
        string.concat('$.irStrategy.', label)
      );
    }

    uint256 spokeCount = _inputs.spokeLabels.length;
    report.spokeInstanceBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; i++) {
      string memory label = _inputs.spokeLabels[i];
      report.spokeInstanceBatchReports[i].label = label;

      report.spokeInstanceBatchReports[i].report.spokeProxy = vm.parseJsonAddress(
        json,
        string.concat('$.spoke.', label)
      );
      report.spokeInstanceBatchReports[i].report.aaveOracle = vm.parseJsonAddress(
        json,
        string.concat('$.oracle.', label)
      );
    }
  }

  function testPostDeploymentCheck() public view {
    OrchestrationReports.FullDeploymentReport memory report = _parseReport();
    // Implementation addresses not included in output json report, therefore skip its checks
    _checkAllAddressesHaveCode({report: report});
    _checkDeployment({report: report, inputs: _inputs});
    _checkRoles({report: report, inputs: _inputs});
  }
}
