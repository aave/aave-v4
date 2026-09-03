// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ArcConfigInputs} from 'scripts/config/ArcConfigInputs.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title ArcHandover
/// @author Aave Labs
/// @notice Hands an Arc market over from the deployer to the Security Council, and proves the
/// deployer holds nothing afterwards.
/// @dev Runs after `ArcConfiguration`. The deployer only ever holds the AccessManager admin role,
/// so the handover is roles only: every ownership was set to the Council at deploy time. Roles reach
/// their end-state holders before the deployer drops its own, because revoking the AccessManager
/// admin role first would strand the rest.
library ArcHandover {
  /// @notice Thrown when the deployer still holds a role after the handover.
  error RoleNotRelinquished(uint64 role);
  /// @notice Thrown when a role did not reach its end-state holder.
  error RoleNotGranted(uint64 role, address account);
  /// @notice Thrown when a contract is not owned by its end-state holder.
  error UnexpectedOwner(address target, address owner);
  /// @notice Thrown when an asset is still live on a Spoke registered for it.
  error AssetNotHalted(uint256 assetId, address spoke);

  /// @notice Grants every role to its end-state holder, then drops the deployer's roles.
  /// @param market The deployed Arc market.
  /// @param targets The addresses to hand the market over to.
  /// @param deployer The address currently holding the AccessManager admin role.
  function relinquish(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets,
    address deployer
  ) internal {
    grantHandoverRoles(market, targets);
    transferManagerOwnership(market, targets);
    dropDeployerRoles(market, targets, deployer);
  }

  /// @notice Reverts unless the deployer holds no role and every role and ownership sits with its
  /// end-state holder.
  /// @dev Enumerates every role in `Roles`, every proxy admin and every listed asset rather than
  /// sampling, since a role or ownership left behind is not recoverable once the deployer is out.
  /// @param market The deployed Arc market.
  /// @param targets The addresses the market was handed over to.
  /// @param deployer The address that ran the deployment and configuration.
  function verify(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets,
    address deployer
  ) internal view {
    verifyDeployerHoldsNoRole(market, deployer);
    verifyRoleHolders(market, targets);
    verifyOwnerships(market, targets);
    verifyAssetsHalted(market);
  }

  /// @notice Grants the Hub, Spoke and configurator domain admin roles to their end-state holders.
  /// @param market The deployed Arc market.
  /// @param targets The addresses to hand the market over to.
  function grantHandoverRoles(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets
  ) internal {
    AaveV4HubRolesProcedure.grantHubAllRoles({
      accessManager: market.accessManager,
      admin: targets.hubAdmin
    });
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles({
      accessManager: market.accessManager,
      admin: targets.spokeAdmin
    });
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: market.accessManager,
      admin: targets.hubConfiguratorAdmin
    });
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: market.accessManager,
      admin: targets.spokeConfiguratorAdmin
    });
  }

  /// @notice Starts the ownership transfer of every position manager and gateway to the Council.
  /// @dev These are the only contracts the deployer owns, because configuration needs `onlyOwner`
  /// access to `registerSpoke` on them. `PositionManagerBase` is `Ownable2Step`, so this records a
  /// pending owner and the Council completes it with one `acceptOwnership` per contract — the whole
  /// of what the Council has to do to take the market over.
  ///
  /// Until it accepts, the deployer still owns them, which means `registerSpoke`,
  /// `renouncePositionManagerRole` and — since the rescue guardian is `owner()` — `rescueToken` and
  /// `rescueNative`. That window should be closed promptly.
  /// @param market The deployed Arc market.
  /// @param targets The addresses to hand the market over to.
  function transferManagerOwnership(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets
  ) internal {
    if (market.signatureGateway != address(0)) {
      Ownable2Step(market.signatureGateway).transferOwnership(targets.gatewayOwner);
    }
    if (market.giverPositionManager != address(0)) {
      Ownable2Step(market.giverPositionManager).transferOwnership(targets.positionManagerOwner);
      Ownable2Step(market.takerPositionManager).transferOwnership(targets.positionManagerOwner);
      Ownable2Step(market.configPositionManager).transferOwnership(targets.positionManagerOwner);
    }
  }

  /// @notice Revokes the deployer's configurator domain admin roles and moves the AccessManager
  /// admin role to the Council.
  /// @dev The AccessManager admin role goes last: without it the deployer cannot revoke anything.
  /// @param market The deployed Arc market.
  /// @param targets The addresses to hand the market over to.
  /// @param deployer The address currently holding the AccessManager admin role.
  function dropDeployerRoles(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets,
    address deployer
  ) internal {
    IAccessManager accessManager = IAccessManager(market.accessManager);

    accessManager.revokeRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, deployer);
    accessManager.revokeRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, deployer);

    AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
      accessManager: market.accessManager,
      adminToAdd: targets.accessManagerAdmin,
      adminToRemove: deployer
    });
  }

  /// @notice Reverts if the deployer still holds any role defined in `Roles`.
  /// @param market The deployed Arc market.
  /// @param deployer The address that ran the deployment and configuration.
  function verifyDeployerHoldsNoRole(
    ArcConfigInputs.Market memory market,
    address deployer
  ) internal view {
    uint64[10] memory roles = [
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      Roles.HUB_DOMAIN_ADMIN_ROLE,
      Roles.HUB_CONFIGURATOR_ROLE,
      Roles.HUB_FEE_MINTER_ROLE,
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE,
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_CONFIGURATOR_ROLE,
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE
    ];

    for (uint256 i; i < roles.length; ++i) {
      (bool isMember, ) = IAccessManager(market.accessManager).hasRole(roles[i], deployer);
      require(!isMember, RoleNotRelinquished(roles[i]));
    }
  }

  /// @notice Reverts unless every role sits with its end-state holder.
  /// @param market The deployed Arc market.
  /// @param targets The addresses the market was handed over to.
  function verifyRoleHolders(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets
  ) internal view {
    _requireRole(market, Roles.ACCESS_MANAGER_ADMIN_ROLE, targets.accessManagerAdmin);

    _requireRole(market, Roles.HUB_CONFIGURATOR_ROLE, targets.hubAdmin);
    _requireRole(market, Roles.HUB_FEE_MINTER_ROLE, targets.hubAdmin);
    _requireRole(market, Roles.HUB_DEFICIT_ELIMINATOR_ROLE, targets.hubAdmin);
    _requireRole(market, Roles.SPOKE_CONFIGURATOR_ROLE, targets.spokeAdmin);
    _requireRole(market, Roles.SPOKE_USER_POSITION_UPDATER_ROLE, targets.spokeAdmin);

    _requireRole(market, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, targets.hubConfiguratorAdmin);
    _requireRole(
      market,
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      targets.spokeConfiguratorAdmin
    );

    // the configurators keep calling the Hub and Spokes on the Council's behalf
    _requireRole(market, Roles.HUB_CONFIGURATOR_ROLE, market.hubConfigurator);
    _requireRole(market, Roles.SPOKE_CONFIGURATOR_ROLE, market.spokeConfigurator);
  }

  /// @notice Reverts unless every ownership sits with its end-state holder.
  /// @dev Nothing is transferred during the handover: every owner below was set at deploy time and
  /// is checked here to prove the deployer was never one of them.
  /// @param market The deployed Arc market.
  /// @param targets The addresses the market was handed over to.
  function verifyOwnerships(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets
  ) internal view {
    _requireOwner(ArcConfigInputs.proxyAdmin(market.hub), targets.proxyAdminOwner);
    for (uint256 i; i < market.spokes.length; ++i) {
      _requireOwner(ArcConfigInputs.proxyAdmin(market.spokes[i]), targets.proxyAdminOwner);
    }
    _requireOwner(ArcConfigInputs.proxyAdmin(market.treasurySpoke), targets.proxyAdminOwner);
    _requireOwner(market.treasurySpoke, targets.treasurySpokeOwner);

    // catches the tokenization spokes, which are deployed during configuration rather than at
    // deploy time and so are not in the deployment report
    _verifyRegisteredSpokeProxyAdmins(market, targets);

    // the managers are Ownable2Step and the deployer owns them until the Council accepts, so either
    // state is valid here; `ArcVerification` is what insists the transfer has completed
    if (market.signatureGateway != address(0)) {
      _requireOwnerOrPending(market.signatureGateway, targets.gatewayOwner);
    }
    if (market.giverPositionManager != address(0)) {
      _requireOwnerOrPending(market.giverPositionManager, targets.positionManagerOwner);
      _requireOwnerOrPending(market.takerPositionManager, targets.positionManagerOwner);
      _requireOwnerOrPending(market.configPositionManager, targets.positionManagerOwner);
    }
  }

  /// @notice Reverts unless every asset on the Hub is halted on every Spoke registered for it.
  /// @param market The deployed Arc market.
  function verifyAssetsHalted(ArcConfigInputs.Market memory market) internal view {
    IHub hub = IHub(market.hub);
    uint256 assetCount = hub.getAssetCount();

    for (uint256 assetId; assetId < assetCount; ++assetId) {
      uint256 spokeCount = hub.getSpokeCount(assetId);
      for (uint256 i; i < spokeCount; ++i) {
        address spoke = hub.getSpokeAddress(assetId, i);
        require(hub.getSpokeConfig(assetId, spoke).halted, AssetNotHalted(assetId, spoke));
      }
    }
  }

  /// @dev Every spoke the Hub knows about is behind a transparent proxy, so its ProxyAdmin owner is
  /// readable from the ERC-1967 admin slot.
  function _verifyRegisteredSpokeProxyAdmins(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.Handover memory targets
  ) private view {
    IHub hub = IHub(market.hub);
    uint256 assetCount = hub.getAssetCount();

    for (uint256 assetId; assetId < assetCount; ++assetId) {
      uint256 spokeCount = hub.getSpokeCount(assetId);
      for (uint256 i; i < spokeCount; ++i) {
        address spoke = hub.getSpokeAddress(assetId, i);
        _requireOwner(ArcConfigInputs.proxyAdmin(spoke), targets.proxyAdminOwner);
      }
    }
  }

  function _requireRole(
    ArcConfigInputs.Market memory market,
    uint64 role,
    address account
  ) private view {
    (bool isMember, ) = IAccessManager(market.accessManager).hasRole(role, account);
    require(isMember, RoleNotGranted(role, account));
  }

  /// @dev Passes if the target is already owned by `expectedOwner`, or if it is the pending owner of
  /// an `Ownable2Step` transfer that has been started but not accepted.
  function _requireOwnerOrPending(address target, address expectedOwner) private view {
    address owner = Ownable(target).owner();
    if (owner == expectedOwner) return;

    address pendingOwner = Ownable2Step(target).pendingOwner();
    require(pendingOwner == expectedOwner, UnexpectedOwner(target, owner));
  }

  function _requireOwner(address target, address expectedOwner) private view {
    address owner = Ownable(target).owner();
    require(owner == expectedOwner, UnexpectedOwner(target, owner));
  }
}
