// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BatchTestProcedures} from 'tests/utils/BatchTestProcedures.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

/// @title PostDeploymentVerificationBase
/// @notice Abstract base for post-deployment verification tests.
///         Reads a JSON deployment report and verifies deployed contracts on a live fork.
abstract contract PostDeploymentVerificationBase is BatchTestProcedures {
  /// @dev Full path to the deployment report JSON
  string internal _reportFile;

  function setUp() public virtual override {
    _spokePositionUpdaterRoleSelectors = Roles.getSpokePositionUpdaterRoleSelectors();
    _spokeConfiguratorRoleSelectors = Roles.getSpokeConfiguratorRoleSelectors();
    _hubFeeMinterRoleSelectors = Roles.getHubFeeMinterRoleSelectors();
    _hubConfiguratorRoleSelectors = Roles.getHubConfiguratorRoleSelectors();
    _skipNativeWrapperCheck = true;
  }

  function _parseReportFromJson(
    string memory json
  ) internal view returns (OrchestrationReports.FullDeploymentReport memory report) {
    report.authorityBatchReport.accessManager = vm.parseJsonAddress(json, '$.accessManager');
    report.configuratorBatchReport.hubConfigurator = vm.parseJsonAddress(json, '$.hubConfigurator');
    report.configuratorBatchReport.spokeConfigurator = vm.parseJsonAddress(
      json,
      '$.spokeConfigurator'
    );
    report.treasurySpokeBatchReport.treasurySpoke = vm.parseJsonAddress(json, '$.treasurySpoke');
    report.feeSharesMinterBatchReport.feeSharesMinter = vm.parseJsonAddress(
      json,
      '$.feeSharesMinter'
    );
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
      report.hubInstanceBatchReports[i].report.hubImplementation = vm.parseJsonAddress(
        json,
        string.concat('$.hubImplementation.', label)
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
      report.spokeInstanceBatchReports[i].report.spokeImplementation = vm.parseJsonAddress(
        json,
        string.concat('$.spokeImplementation.', label)
      );
      report.spokeInstanceBatchReports[i].report.aaveOracle = vm.parseJsonAddress(
        json,
        string.concat('$.oracle.', label)
      );
    }
  }

  /// @notice Deploys all contracts, serializes the JSON report in memory, parses it back, and verifies.
  function _deployWriteReportAndVerify(
    InputUtils.FullDeployInputs memory sanitizedInputs
  ) internal {
    MetadataLogger logger = new MetadataLogger('');

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4({
        logger: logger,
        deployer: _deployer,
        deployInputs: sanitizedInputs,
        hubBytecode: BytecodeHelper.getHubBytecode(),
        spokeBytecode: BytecodeHelper.getSpokeBytecode()
      });
    vm.stopPrank();

    logger.writeJsonReportMarket(report);

    _inputs = sanitizedInputs;
    _verifyPostDeployment({
      report: _parseReportFromJson(logger.getJson()),
      inputs: sanitizedInputs
    });
  }

  /// @notice Deploys all contracts, writes the JSON report, reads it back, and runs verification.
  /// @param sanitizedInputs Deploy inputs after sanitization (zero-address defaulting, etc.).
  /// @param outputDir Directory for the JSON report file.
  /// @param fileName Base file name for the JSON report (no extension).
  function _deployWriteReportAndVerify(
    InputUtils.FullDeployInputs memory sanitizedInputs,
    string memory outputDir,
    string memory fileName
  ) internal {
    MetadataLogger logger = new MetadataLogger(outputDir);

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4({
        logger: logger,
        deployer: _deployer,
        deployInputs: sanitizedInputs,
        hubBytecode: BytecodeHelper.getHubBytecode(),
        spokeBytecode: BytecodeHelper.getSpokeBytecode()
      });
    vm.stopPrank();

    logger.writeJsonReportMarket(report);
    vm.createDir(outputDir, true);

    _reportFile = string.concat(outputDir, vm.toString(block.chainid), '-', fileName, '.json');
    logger.save({fileName: fileName, withTimestamp: false});

    _inputs = sanitizedInputs;
    _verifyPostDeployment({
      report: _parseReportFromJson(vm.readFile(_reportFile)),
      inputs: sanitizedInputs
    });
  }

  /// @notice Deploys all contracts and verifies the in-memory report directly.
  /// @param sanitizedInputs Deploy inputs after sanitization.
  function _deployAndVerify(InputUtils.FullDeployInputs memory sanitizedInputs) internal {
    _inputs = sanitizedInputs;

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4({
        logger: new MetadataLogger(''),
        deployer: _deployer,
        deployInputs: sanitizedInputs,
        hubBytecode: BytecodeHelper.getHubBytecode(),
        spokeBytecode: BytecodeHelper.getSpokeBytecode()
      });
    vm.stopPrank();
    _verifyPostDeployment({report: report, inputs: sanitizedInputs});
  }

  /// @dev Verifies the deployment report against the provided inputs.
  function _verifyPostDeployment(
    OrchestrationReports.FullDeploymentReport memory report,
    InputUtils.FullDeployInputs memory inputs
  ) internal view {
    _checkAddressesHaveCode({report: report});
    _checkDeployment({report: report, inputs: inputs});
    _checkRoles({report: report, inputs: inputs});
  }
}
