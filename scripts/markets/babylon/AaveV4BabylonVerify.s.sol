// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';

/// @title AaveV4BabylonVerify
/// @author Aave Labs
/// @notice Asserts that the deployed, configured and handed-over Babylon market matches its config.
/// @dev Read-only. Run last, after the admin accepted TreasurySpoke ownership.
contract AaveV4BabylonVerify is Script {
  function run() external view {
    AaveV4BabylonConfig.Config memory config = _config();
    require(config.admin != address(0), 'admin unset');
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(config);

    AaveV4BabylonVerification.verifyDeployment(config, deployment);
    AaveV4BabylonVerification.verifyRoles(deployment, config.admin);
    AaveV4BabylonVerification.verifyProxyAdmins(deployment, config.admin);
    AaveV4BabylonVerification.verifyTreasurySpokeOwner({
      deployment: deployment,
      owner: config.admin,
      allowPending: false
    });
    AaveV4BabylonVerification.verifyMarketConfig(deployment, _marketConfig(config, deployment));
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
}
