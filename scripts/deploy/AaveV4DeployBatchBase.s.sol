// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';

import {Script} from 'forge-std/Script.sol';

/// @title AaveV4DeployBatchBaseScript
/// @author Aave Labs
/// @notice Base script for deploying Aave V4.
abstract contract AaveV4DeployBatchBaseScript is Script {
  /// @dev Thrown when deployNativeTokenGateway is true but nativeWrapper is address(0), causing deployment to revert.
  error NativeWrapperRequired();

  struct Lines {
    string[] s;
  }

  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal _outputFileName;
  Lines internal _promptLines;
  Lines internal _summaryLines;

  /// @dev Constructor.
  /// @param outputFileName_ The base file name for deployment output logs.
  constructor(string memory outputFileName_) {
    _outputFileName = outputFileName_;
  }

  /// @notice Main entry point. Deploys all Aave V4 contracts and writes the deployment report.
  function run() external virtual {
    _validateChainId();
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    InputUtils.FullDeployInputs memory inputs = _getDeployInputs();

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    inputs = _loadWarningsAndSanitizeInputs(inputs, deployer);

    logger.log('CHAIN ID', block.chainid);
    logger.log('deployer', deployer);
    logger.logHeader1('starting Aave V4 batch deployment');

    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(
        logger,
        deployer,
        inputs,
        BytecodeHelper.getHubBytecode(),
        BytecodeHelper.getSpokeBytecode()
      );
    vm.stopBroadcast();
    logger.writeJsonReportMarket(report);
    _logDeploySummary(logger);
    logger.logHeader1('batch deployment completed');
    logger.logHeader1('saving logs');
    logger.save({fileName: _outputFileName, withTimestamp: true});
  }

  /// @dev Override to provide deployment inputs from any source.
  function _getDeployInputs() internal virtual returns (InputUtils.FullDeployInputs memory);

  /// @dev Override to return the expected chain ID for this script.
  function _expectedChainId() internal view virtual returns (uint256);

  function _validateChainId() internal view virtual {
    uint256 expected = _expectedChainId();
    require(block.chainid == expected, 'chain id mismatch');
  }

  function _loadWarningsAndSanitizeInputs(
    InputUtils.FullDeployInputs memory inputs,
    address deployer
  ) internal virtual returns (InputUtils.FullDeployInputs memory) {
    string memory message = ' is zero address';
    string memory outcome = string.concat('; defaulting to deployer [', vm.toString(deployer), ']');

    InputUtils.FullDeployInputs memory sanitizedInputs = inputs;

    // Validate label uniqueness (duplicate labels produce identical CREATE2 salts)
    InputUtils.validateUniqueLabels(inputs.hubLabels, 'hub');
    InputUtils.validateUniqueLabels(inputs.spokeLabels, 'spoke');

    _appendSummary('========== DEPLOYMENT SUMMARY ==========');
    _logHubs(inputs);
    _logSpokes(inputs);
    _logNativeTokenGateway(inputs);
    _logSignatureGateway(inputs);
    _logPositionManagers(inputs);
    _logRoles(inputs);
    _appendSummary('--------------------------------------------------');

    // Sanitize zero addresses
    if (inputs.grantRoles) {
      if (inputs.accessManagerAdmin == address(0)) {
        _logWarning(string.concat('access manager admin', message, outcome));
        sanitizedInputs.accessManagerAdmin = deployer;
      }
      if (inputs.hubConfiguratorAdmin == address(0)) {
        _logWarning(string.concat('hub configurator admin', message, outcome));
        sanitizedInputs.hubConfiguratorAdmin = deployer;
      }
      if (inputs.spokeConfiguratorAdmin == address(0)) {
        _logWarning(string.concat('spoke configurator admin', message, outcome));
        sanitizedInputs.spokeConfiguratorAdmin = deployer;
      }
      if (inputs.proxyAdminOwner == address(0)) {
        _logWarning(string.concat('proxy admin owner', message, outcome));
        sanitizedInputs.proxyAdminOwner = deployer;
      }
      if (inputs.treasurySpokeOwner == address(0)) {
        _logWarning(string.concat('treasury spoke owner', message, outcome));
        sanitizedInputs.treasurySpokeOwner = deployer;
      }
      if (inputs.spokeAdmin == address(0)) {
        _logWarning(string.concat('spoke admin', message, outcome));
        sanitizedInputs.spokeAdmin = deployer;
      }
      if (inputs.hubAdmin == address(0)) {
        _logWarning(string.concat('hub admin', message, outcome));
        sanitizedInputs.hubAdmin = deployer;
      }
    } else {
      // when grantRoles is false, roles are deferred to a later governance action
      // These three admin addresses are still required at deploy time so they default to the deployer
      // ACCESS_MANAGER_ADMIN_ROLE is also retained by the deployer
      _logWarning('roles: deferred (not granted during deployment)');
      _logWarning(string.concat('treasury spoke owner', message, outcome));
      sanitizedInputs.treasurySpokeOwner = deployer;

      _logWarning(string.concat('proxy admin owner', message, outcome));
      sanitizedInputs.proxyAdminOwner = deployer;
    }
    if (inputs.gatewayOwner == address(0)) {
      _logWarning(string.concat('gateway owner', message, outcome));
      sanitizedInputs.gatewayOwner = deployer;
    }
    if (inputs.positionManagerOwner == address(0)) {
      _logWarning(string.concat('position manager owner', message, outcome));
      sanitizedInputs.positionManagerOwner = deployer;
    }
    if (inputs.salt == bytes32(0)) {
      _logWarning('salt is zero');
    }

    _executeUserPrompt();
    return sanitizedInputs;
  }

  function _logHubs(InputUtils.FullDeployInputs memory inputs) internal {
    if (inputs.hubLabels.length > 0) {
      _appendSummary(string.concat('hubs to deploy: ', vm.toString(inputs.hubLabels.length)));
      for (uint256 i; i < inputs.hubLabels.length; i++) {
        _appendSummary(string.concat('  - ', inputs.hubLabels[i]));
      }
    } else {
      _logWarning('no hubs will be deployed');
    }
  }

  function _logSpokes(InputUtils.FullDeployInputs memory inputs) internal {
    if (inputs.spokeLabels.length > 0) {
      _appendSummary(string.concat('spokes to deploy: ', vm.toString(inputs.spokeLabels.length)));
      for (uint256 i; i < inputs.spokeLabels.length; i++) {
        _appendSummary(string.concat('  - ', inputs.spokeLabels[i]));
      }
    } else {
      _logWarning('no spokes will be deployed');
    }
  }

  function _logNativeTokenGateway(InputUtils.FullDeployInputs memory inputs) internal {
    if (inputs.deployNativeTokenGateway) {
      require(inputs.nativeWrapper != address(0), NativeWrapperRequired());
      _appendSummary('nativeTokenGateway will be deployed');
    } else {
      _appendSummary('nativeTokenGateway: skipped (deployNativeTokenGateway is false)');
    }
  }

  function _logSignatureGateway(InputUtils.FullDeployInputs memory inputs) internal {
    if (inputs.deploySignatureGateway) {
      _appendSummary('signatureGateway will be deployed');
    } else {
      _appendSummary('signatureGateway: skipped (deploySignatureGateway is false)');
    }
  }

  function _logPositionManagers(InputUtils.FullDeployInputs memory inputs) internal {
    if (inputs.deployPositionManagers) {
      _appendSummary('positionManagers (giver/taker/config) will be deployed');
    } else {
      _appendSummary('positionManagers: skipped (deployPositionManagers is false)');
    }
  }

  function _logRoles(InputUtils.FullDeployInputs memory inputs) internal {
    if (inputs.grantRoles) {
      _appendSummary('roles: will be granted during deployment');
    } else {
      _appendSummary('roles: deferred (not granted during deployment)');
    }
  }

  function _executeUserPrompt() internal virtual {
    if (_promptLines.s.length > 0) {
      string memory ack = vm.prompt(
        string.concat(_joinLines(_promptLines), "\nenter 'y' to continue")
      );
      if (keccak256(bytes(ack)) != keccak256(bytes('y'))) {
        revert('user did not acknowledge. Please try again.');
      }
    }
  }

  function _appendSummary(string memory line) internal virtual {
    _promptLines.s.push(line);
    _summaryLines.s.push(line);
  }

  function _logWarning(string memory warning) internal virtual {
    _promptLines.s.push(string.concat('WARNING: ', warning));
  }

  /// @dev Writes the deployment summary to the logger (called after deployment).
  function _logDeploySummary(MetadataLogger logger) internal virtual {
    for (uint256 i; i < _summaryLines.s.length; i++) {
      logger.log(_summaryLines.s[i]);
    }
  }

  function _joinLines(Lines storage lines) internal view virtual returns (string memory) {
    uint256 n = lines.s.length;
    if (n == 0) {
      return '';
    }
    string memory out = lines.s[0];
    for (uint256 i = 1; i < n; i++) {
      out = string.concat(out, '\n', lines.s[i]);
    }
    return string.concat(out, '\n');
  }
}
