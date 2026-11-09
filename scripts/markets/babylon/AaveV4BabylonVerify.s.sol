// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';

/// @title AaveV4BabylonVerify
/// @author Aave Labs
/// @notice Asserts that the deployed, configured and handed-over Babylon market matches its config.
/// @dev Read-only. Run last, after the admin accepted TreasurySpoke ownership when it was transferred.
contract AaveV4BabylonVerify is Script {
  function run() external view {
    AaveV4BabylonConfig.Config memory config = _config();
    require(config.admin != address(0), 'admin unset');
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(config);
    AaveV4BabylonConfig.MarketConfig memory marketConfig = _marketConfig(config, deployment);

    AaveV4BabylonVerification.verifyDeployment({
      config: config,
      deployment: deployment,
      authority: AaveV4BabylonConfig.finalAuthority(config, deployment)
    });
    if (config.authority == address(0)) {
      AaveV4BabylonVerification.verifyRoles(deployment, config.admin);
    } else {
      AaveV4BabylonVerification.verifyAbandonedAccessManager({
        deployment: deployment,
        admin: config.admin,
        deployer: config.deployer
      });
    }
    AaveV4BabylonVerification.verifyProxyAdmins({
      deployment: deployment,
      owner: config.admin,
      externalSpokes: marketConfig.externalSpokes,
      externalFeeReceiver: config.feeReceiver,
      treasurySpokeOwner: AaveV4BabylonConfig.treasurySpokeOwner(config)
    });
    AaveV4BabylonVerification.verifyTreasurySpokeOwner({
      deployment: deployment,
      owner: AaveV4BabylonConfig.treasurySpokeOwner(config),
      allowPending: false
    });
    AaveV4BabylonVerification.verifyMarketConfig({
      deployment: deployment,
      marketConfig: marketConfig,
      feeReceiver: AaveV4BabylonConfig.feeReceiver(config, deployment)
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
}
