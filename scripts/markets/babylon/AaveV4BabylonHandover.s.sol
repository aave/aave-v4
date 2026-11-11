// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';

/// @title AaveV4BabylonHandover
/// @author Aave Labs
/// @notice Hands the Babylon market from the deployer over to the configured admin.
/// @dev Transfers every ProxyAdmin, nominates the admin as TreasurySpoke owner and removes every role
/// the deployer holds. With a configured fee receiver, the deployed TreasurySpoke is unused and it and
/// its ProxyAdmin stay with the deployer. Without `authority`, it first grants the admin the configurator domain admin
/// roles and the configurators their Hub and Spoke roles, then hands the AccessManager admin role to
/// the admin. With `authority`, it moves the Hubs and the BabylonSpoke to that AccessManager and the
/// deployer renounces the deployed one, which keeps no admin. Without a configured fee receiver, the
/// admin must then call `acceptOwnership` on the TreasurySpoke. The role end state is in `AaveV4BabylonVerification`.
contract AaveV4BabylonHandover is Script {
  function run() external {
    AaveV4BabylonConfig.Config memory config = _config();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(config);

    AaveV4BabylonVerification.verifyDeployment({
      config: config,
      deployment: deployment,
      authority: deployment.accessManager
    });

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    AaveV4BabylonConfig.requireDeployer(config, deployer);
    _handover({config: config, deployment: deployment, deployer: deployer});
    vm.stopBroadcast();

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
        deployer: deployer
      });
    }
    AaveV4BabylonVerification.verifyProxyAdmins({
      deployment: deployment,
      owner: config.admin,
      externalSpokes: _externalSpokes(config, deployment),
      externalFeeReceiver: config.feeReceiver,
      treasurySpokeOwner: AaveV4BabylonConfig.treasurySpokeOwner(config)
    });
    AaveV4BabylonVerification.verifyTreasurySpokeOwner({
      deployment: deployment,
      owner: AaveV4BabylonConfig.treasurySpokeOwner(config),
      allowPending: config.feeReceiver == address(0)
    });
    if (config.feeReceiver == address(0)) {
      console.log('AaveV4BabylonHandover: admin must accept TreasurySpoke ownership', config.admin);
    }
  }

  function _config() internal view virtual returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read();
  }

  function _externalSpokes(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view virtual returns (AaveV4BabylonConfig.ExternalSpoke[] memory) {
    return AaveV4BabylonConfig.readExternalSpokes(config, deployment);
  }

  function _handover(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment,
    address deployer
  ) internal {
    address admin = config.admin;
    require(admin != address(0), 'admin unset');
    require(admin != deployer, 'admin is deployer');
    if (config.authority == address(0)) {
      _grantAdminRoles(deployment, admin);
    } else {
      require(config.authority != deployment.accessManager, 'authority is the deployed one');
      require(config.authority.code.length > 0, 'authority code');
    }

    for (uint256 i; i < deployment.hubs.length; ++i) {
      _transferProxyAdmin(deployment.hubs[i], deployer, admin);
    }
    _transferProxyAdmin(deployment.babylonSpoke, deployer, admin);
    if (config.feeReceiver == address(0)) {
      _transferProxyAdmin(deployment.treasurySpoke, deployer, admin);
      Ownable2StepUpgradeable(deployment.treasurySpoke).transferOwnership(admin);
    }

    address accessManager = deployment.accessManager;
    if (config.authority == address(0)) {
      _revokeDeployerRoles(accessManager, deployer);
      AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
        accessManager: accessManager,
        adminToAdd: admin,
        adminToRemove: deployer
      });
    } else {
      for (uint256 i; i < deployment.hubs.length; ++i) {
        IAccessManager(accessManager).updateAuthority(deployment.hubs[i], config.authority);
      }
      IAccessManager(accessManager).updateAuthority(deployment.babylonSpoke, config.authority);
      _revokeDeployerRoles(accessManager, deployer);
      IAccessManager(accessManager).renounceRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, deployer);
    }
  }

  function _grantAdminRoles(
    AaveV4BabylonConfig.Deployment memory deployment,
    address admin
  ) internal {
    address accessManager = deployment.accessManager;
    AaveV4HubRolesProcedure.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: deployment.hubConfigurator
    });
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: accessManager,
      admin: admin
    });
    AaveV4SpokeRolesProcedure.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: deployment.spokeConfigurator
    });
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: accessManager,
      admin: admin
    });
  }

  function _transferProxyAdmin(address proxy, address deployer, address admin) internal {
    ProxyAdmin proxyAdmin = _proxyAdmin(proxy);
    require(proxyAdmin.owner() == deployer, 'proxy admin not owned by deployer');
    proxyAdmin.transferOwnership(admin);
  }

  /// @dev Revokes every enumerated role the deployer holds. The admin role is not enumerated.
  function _revokeDeployerRoles(address accessManager, address deployer) internal {
    IAccessManagerEnumerable manager = IAccessManagerEnumerable(accessManager);
    uint256 roleCount = manager.getRoleCount();
    for (uint256 i; i < roleCount; ++i) {
      uint64 roleId = manager.getRole(i);
      (bool hasRole, ) = manager.hasRole(roleId, deployer);
      if (hasRole) {
        manager.revokeRole(roleId, deployer);
      }
    }
  }

  function _proxyAdmin(address proxy) internal view returns (ProxyAdmin) {
    return ProxyAdmin(AaveV4BabylonVerification.getProxyAdmin(proxy));
  }
}
