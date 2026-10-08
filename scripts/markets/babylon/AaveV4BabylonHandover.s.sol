// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';

/// @title AaveV4BabylonHandover
/// @author Aave Labs
/// @notice Hands the Babylon market from the deployer over to the configured admin.
/// @dev Grants the roles `grantRoles = true` would have granted, transfers every ProxyAdmin, nominates
/// the admin as TreasurySpoke owner and removes every role the deployer holds. The admin must then
/// call `acceptOwnership` on the TreasurySpoke.
contract AaveV4BabylonHandover is Script {
  /// @dev ERC-1967 admin slot, `bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)`.
  bytes32 internal constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  function run() external {
    AaveV4BabylonConfig.Config memory config = _config();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(config);

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    _handover({deployment: deployment, deployer: deployer, admin: config.admin});
    vm.stopBroadcast();

    _verify({deployment: deployment, deployer: deployer, admin: config.admin});
    console.log('AaveV4BabylonHandover: admin must accept TreasurySpoke ownership', config.admin);
  }

  function _config() internal view virtual returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read();
  }

  function _handover(
    AaveV4BabylonConfig.Deployment memory deployment,
    address deployer,
    address admin
  ) internal {
    require(admin != address(0), 'admin unset');
    require(admin != deployer, 'admin is deployer');
    address accessManager = deployment.accessManager;

    AaveV4HubRolesProcedure.grantHubAllRoles({accessManager: accessManager, admin: admin});
    AaveV4HubRolesProcedure.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: deployment.hubConfigurator
    });
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: accessManager,
      admin: admin
    });
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles({accessManager: accessManager, admin: admin});
    AaveV4SpokeRolesProcedure.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: deployment.spokeConfigurator
    });
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: accessManager,
      admin: admin
    });

    _transferProxyAdmin(deployment.hub, deployer, admin);
    _transferProxyAdmin(deployment.babylonSpoke, deployer, admin);
    _transferProxyAdmin(deployment.treasurySpoke, deployer, admin);
    Ownable2StepUpgradeable(deployment.treasurySpoke).transferOwnership(admin);

    _revokeDeployerRoles(accessManager, deployer);
    AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
      accessManager: accessManager,
      adminToAdd: admin,
      adminToRemove: deployer
    });
  }

  function _verify(
    AaveV4BabylonConfig.Deployment memory deployment,
    address deployer,
    address admin
  ) internal view {
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(deployment.accessManager);
    (bool adminIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, admin);
    require(adminIsAdmin, 'admin is not AccessManager admin');
    (bool deployerIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, deployer);
    require(!deployerIsAdmin, 'deployer is AccessManager admin');
    uint256 roleCount = accessManager.getRoleCount();
    for (uint256 i; i < roleCount; ++i) {
      (bool hasRole, ) = accessManager.hasRole(accessManager.getRole(i), deployer);
      require(!hasRole, 'deployer holds a role');
    }

    require(_proxyAdmin(deployment.hub).owner() == admin, 'hub proxy admin owner');
    require(
      _proxyAdmin(deployment.babylonSpoke).owner() == admin,
      'babylon spoke proxy admin owner'
    );
    require(
      _proxyAdmin(deployment.treasurySpoke).owner() == admin,
      'treasury spoke proxy admin owner'
    );
    Ownable2StepUpgradeable treasurySpoke = Ownable2StepUpgradeable(deployment.treasurySpoke);
    require(
      treasurySpoke.owner() == admin || treasurySpoke.pendingOwner() == admin,
      'treasury spoke owner'
    );
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
    return ProxyAdmin(address(uint160(uint256(vm.load(proxy, ADMIN_SLOT)))));
  }
}
