// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title AaveV4BabylonConfigure
/// @author Aave Labs
/// @notice Lists the configured assets on the Babylon Hubs and adds them as BabylonSpoke reserves.
/// @dev Run by the deployer before `AaveV4BabylonHandover`. Grants the deployer the configurator
/// domain admin roles and the configurators their Hub and Spoke roles. The handover revokes the
/// deployer roles. Every asset's fee receiver is the TreasurySpoke.
contract AaveV4BabylonConfigure is Script {
  function run() external {
    AaveV4BabylonConfig.Config memory config = _config();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(config);
    AaveV4BabylonConfig.MarketConfig memory marketConfig = _marketConfig(config, deployment);
    AaveV4BabylonVerification.verifyDeployment(config, deployment);
    _requireNoDelays(deployment.accessManager);

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    _grantRoles(deployment, deployer);
    _configure(deployment, marketConfig);
    vm.stopBroadcast();

    AaveV4BabylonVerification.verifyMarketConfig(deployment, marketConfig);
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

  /// @dev A role grant delay or AccessManager admin delay would defer the role grants below, so every
  /// configuration call afterwards would revert.
  function _requireNoDelays(address accessManager) internal view {
    IAccessManager manager = IAccessManager(accessManager);
    require(manager.getTargetAdminDelay(accessManager) == 0, 'unexpected admin delay');
    require(
      manager.getRoleGrantDelay(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE) == 0 &&
        manager.getRoleGrantDelay(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE) == 0 &&
        manager.getRoleGrantDelay(Roles.HUB_CONFIGURATOR_ROLE) == 0 &&
        manager.getRoleGrantDelay(Roles.SPOKE_CONFIGURATOR_ROLE) == 0,
      'unexpected grant delay'
    );
  }

  function _grantRoles(
    AaveV4BabylonConfig.Deployment memory deployment,
    address deployer
  ) internal {
    address accessManager = deployment.accessManager;
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: accessManager,
      admin: deployer
    });
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: accessManager,
      admin: deployer
    });
    AaveV4HubRolesProcedure.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: deployment.hubConfigurator
    });
    AaveV4SpokeRolesProcedure.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: deployment.spokeConfigurator
    });
  }

  function _configure(
    AaveV4BabylonConfig.Deployment memory deployment,
    AaveV4BabylonConfig.MarketConfig memory marketConfig
  ) internal {
    require(ISpoke(deployment.babylonSpoke).getReserveCount() == 0, 'babylon spoke has reserves');
    IHubConfigurator hubConfigurator = IHubConfigurator(deployment.hubConfigurator);
    ISpokeConfigurator spokeConfigurator = ISpokeConfigurator(deployment.spokeConfigurator);

    for (uint256 i; i < marketConfig.reserves.length; ++i) {
      AaveV4BabylonConfig.ReserveListing memory listing = marketConfig.reserves[i];
      uint256 assetId = hubConfigurator.addAsset({
        hub: listing.hub,
        underlying: listing.underlying,
        feeReceiver: deployment.treasurySpoke,
        liquidityFee: listing.liquidityFee,
        irStrategy: listing.irStrategy,
        irData: abi.encode(listing.irData)
      });
      hubConfigurator.addSpoke({
        hub: listing.hub,
        spoke: deployment.babylonSpoke,
        assetId: assetId,
        config: listing.spokeConfig
      });
      uint256 reserveId = spokeConfigurator.addReserve({
        spoke: deployment.babylonSpoke,
        hub: listing.hub,
        assetId: assetId,
        priceSource: listing.priceSource,
        config: listing.reserveConfig,
        dynamicConfig: listing.dynamicConfig
      });
      require(reserveId == i, 'unexpected reserve id');
    }

    spokeConfigurator.updateLiquidationConfig(
      deployment.babylonSpoke,
      marketConfig.liquidationConfig
    );
  }
}
