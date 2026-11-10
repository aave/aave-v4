// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';

/// @title AaveV4DeployBabylonHub
/// @author Aave Labs
/// @notice Deploys the Babylon market without its BabylonSpoke: the AccessManager, the
/// configurators, the TreasurySpoke and the Hubs, with roles and ownership kept by the deployer
/// until `AaveV4BabylonHandover`. `AaveV4DeployBabylonSpoke` deploys the BabylonSpoke.
contract AaveV4DeployBabylonHub is AaveV4DeployBatchBaseScript {
  constructor() AaveV4DeployBatchBaseScript('babylon-hub') {}

  /// @notice Deploys the market without the Spoke bytecodes, so it runs without linked libraries.
  function run() external override {
    _validateChainId();
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    InputUtils.FullDeployInputs memory inputs = _getDeployInputs();
    require(
      inputs.spokeLabels.length == 0 && inputs.babylonSpokeLabels.length == 0,
      'hub deploy lists spokes'
    );

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    inputs = _loadWarningsAndSanitizeInputs(inputs, deployer);

    logger.log('CHAIN ID', block.chainid);
    logger.log('deployer', deployer);
    logger.logHeader1('starting Aave V4 batch deployment');

    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4({
        logger: logger,
        deployer: deployer,
        deployInputs: inputs,
        hubBytecode: BytecodeHelper.getHubBytecode(),
        spokeBytecode: '',
        babylonSpokeBytecode: ''
      });
    vm.stopBroadcast();
    logger.writeJsonReportMarket(report);
    _logDeploySummary(logger);
    logger.logHeader1('batch deployment completed');
    logger.logHeader1('saving logs');
    logger.save({fileName: _outputFileName, withTimestamp: true});
  }

  function _getDeployInputs() internal view override returns (InputUtils.FullDeployInputs memory) {
    return AaveV4BabylonConfig.deployInputs(_config());
  }

  function _loadWarningsAndSanitizeInputs(
    InputUtils.FullDeployInputs memory inputs,
    address deployer
  ) internal virtual override returns (InputUtils.FullDeployInputs memory) {
    AaveV4BabylonConfig.requireDeployer(_config(), deployer);
    return super._loadWarningsAndSanitizeInputs(inputs, deployer);
  }

  /// @dev The chain is validated by the config lookup.
  function _expectedChainId() internal view override returns (uint256) {
    return _config().chainId;
  }

  function _config() internal view virtual returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read();
  }
}
