// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title AaveV4DeployBabylon
/// @author Aave Labs
/// @notice Deploys the Babylon market: one Hub and one BabylonSpoke, with roles and ownership kept
/// by the deployer until `AaveV4BabylonHandover`.
contract AaveV4DeployBabylon is AaveV4DeployBatchBaseScript {
  constructor() AaveV4DeployBatchBaseScript('babylon') {}

  function _getDeployInputs() internal view override returns (InputUtils.FullDeployInputs memory) {
    return AaveV4BabylonConfig.deployInputs(_config());
  }

  /// @dev The chain is validated by the config lookup.
  function _expectedChainId() internal view override returns (uint256) {
    AaveV4BabylonConfig.path();
    return block.chainid;
  }

  function _config() internal view virtual returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read();
  }
}
