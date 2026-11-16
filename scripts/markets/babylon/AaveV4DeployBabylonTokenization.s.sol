// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script, console} from 'forge-std/Script.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title AaveV4DeployBabylonTokenization
/// @author Aave Labs
/// @notice Deploys the configured TokenizationSpokes of the Babylon market with the config admin as
/// ProxyAdmin owner, and writes the deployment report with them added.
/// @dev Run by the deployer after `AaveV4BabylonConfigure`, since a TokenizationSpoke requires its asset
/// listed on the Hub. Connecting the TokenizationSpokes on the Hub is left to governance.
contract AaveV4DeployBabylonTokenization is Script {
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';

  function run() external {
    AaveV4BabylonConfig.Config memory config = _config();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(config);
    AaveV4BabylonConfig.MarketConfig memory marketConfig = _marketConfig(config, deployment);
    AaveV4BabylonConfig.TokenizationSpoke[] memory tokenizationSpokes = marketConfig
      .tokenizationSpokes;
    require(tokenizationSpokes.length > 0, 'no tokenization spokes');
    require(
      config.admin != address(0) && config.admin != config.deployer,
      'invalid proxy admin owner'
    );
    for (uint256 i; i < tokenizationSpokes.length; ++i) {
      (address proxy, ) = AaveV4BabylonConfig.readTokenizationSpoke(
        config,
        tokenizationSpokes[i].symbol
      );
      require(proxy == address(0), 'tokenization spoke already in report');
      // reverts unless the asset is listed
      IHub(tokenizationSpokes[i].hub).getAssetId(tokenizationSpokes[i].underlying);
    }

    BatchReports.TokenizationSpokeBatchReport[]
      memory reports = new BatchReports.TokenizationSpokeBatchReport[](tokenizationSpokes.length);
    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    AaveV4BabylonConfig.requireDeployer(config, deployer);
    bytes32 salt = AaveV4DeployOrchestration._deriveSalt({deployer: deployer, salt: config.salt});
    for (uint256 i; i < tokenizationSpokes.length; ++i) {
      reports[i] = AaveV4DeployBase.deployTokenizationSpokeBatch({
        hub: tokenizationSpokes[i].hub,
        underlying: tokenizationSpokes[i].underlying,
        proxyAdminOwner: config.admin,
        shareName: tokenizationSpokes[i].name,
        shareSymbol: tokenizationSpokes[i].symbol,
        salt: AaveV4DeployOrchestration._deriveChildSalt({
          baseSalt: salt,
          contractType: 'tokenizationSpoke',
          label: tokenizationSpokes[i].symbol
        })
      });
    }
    vm.stopBroadcast();

    config.report = _writeReport({
      config: config,
      tokenizationSpokes: tokenizationSpokes,
      reports: reports
    });
    AaveV4BabylonVerification.verifyTokenizationSpokes({
      config: config,
      marketConfig: marketConfig,
      owner: config.admin
    });
  }

  function _config() internal view virtual returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read();
  }

  function _marketConfig(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view virtual returns (AaveV4BabylonConfig.MarketConfig memory) {
    return AaveV4BabylonConfig.readMarketConfig(config, deployment);
  }

  /// @dev Writes a copy of the report with every TokenizationSpoke and its implementation, keyed by the
  /// share token symbol, and returns its path.
  function _writeReport(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.TokenizationSpoke[] memory tokenizationSpokes,
    BatchReports.TokenizationSpokeBatchReport[] memory reports
  ) internal returns (string memory path) {
    string memory proxies;
    string memory implementations;
    for (uint256 i; i < tokenizationSpokes.length; ++i) {
      proxies = vm.serializeAddress(
        'tokenizationSpoke',
        tokenizationSpokes[i].symbol,
        reports[i].tokenizationSpokeProxy
      );
      implementations = vm.serializeAddress(
        'tokenizationSpokeImplementation',
        tokenizationSpokes[i].symbol,
        reports[i].tokenizationSpokeImplementation
      );
    }
    vm.serializeJson('babylonReport', vm.readFile(config.report));
    vm.serializeString('babylonReport', 'tokenizationSpoke', proxies);
    string memory json = vm.serializeString(
      'babylonReport',
      'tokenizationSpokeImplementation',
      implementations
    );
    path = _outputReport(config);
    vm.createDir(OUTPUT_DIR, true);
    vm.writeJson(json, path);
    console.log('report written to %s', path);
  }

  function _outputReport(
    AaveV4BabylonConfig.Config memory
  ) internal virtual returns (string memory) {
    return
      string.concat(
        OUTPUT_DIR,
        'babylon-tokenization-',
        vm.toString(vm.unixTime() / 1000),
        '.json'
      );
  }
}
