// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4DeployBabylonHub
/// @author Aave Labs
/// @notice Deploys the Babylon market without its BabylonSpoke: the AccessManager, the
/// configurators, the TreasurySpoke and the Hubs, with roles and ownership kept by the deployer
/// until `AaveV4BabylonHandover`. `AaveV4DeployBabylonSpoke` deploys the BabylonSpoke.
contract AaveV4DeployBabylonHub is AaveV4DeployBatchBaseScript {
  constructor() AaveV4DeployBatchBaseScript('babylon-hub') {}

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
