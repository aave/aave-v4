// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4BaseConfigInputs} from 'scripts/config/AaveV4BaseConfigInputs.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title AaveV4BaseHandover
/// @author Aave Labs
/// @notice Hands a Base market over from the deployer to the V4 Security Council and the DAO's
/// governance executor, and proves the deployer holds nothing afterwards.
/// @dev Runs after `AaveV4BaseConfiguration`. Roles reach their end-state holders before the
/// deployer drops its own, because revoking the AccessManager admin role first would strand the
/// rest.
///
/// The end state reproduces the live Avalanche V4 market exactly, member counts included:
///
/// | role                                    | holder                                 | members |
/// | --------------------------------------- | -------------------------------------- | ------- |
/// | 0   ACCESS_MANAGER_ADMIN                | Security Council + governance executor | 2       |
/// | 101 HUB_CONFIGURATOR_ROLE               | the HubConfigurator                    | 1       |
/// | 200 HUB_CONFIGURATOR_DOMAIN_ADMIN       | Council executor + governance executor | 2       |
/// | 301 SPOKE_CONFIGURATOR_ROLE             | the SpokeConfigurator                  | 1       |
/// | 400 SPOKE_CONFIGURATOR_DOMAIN_ADMIN     | Council executor                       | 1       |
/// | 100, 102, 103, 300, 302                 | nobody                                 | 0       |
///
/// Roles 100, 102, 103, 300 and 302 reach the Hub and Spokes directly rather than through a
/// configurator, and are left unheld on both live markets: nothing at launch calls `mintFeeShares`,
/// `eliminateDeficit` or the user position updaters, and role 0 can grant them when something does.
///
/// The Security Council reaches the configurators through its executor rather than holding roles 200
/// and 400 itself. Ethereum grants it both directly, Avalanche grants it neither, and this follows
/// Avalanche. That is a choice of default posture rather than of capability: the Council holds role
/// 0 on either market and can grant itself either role whenever it wants.
///
/// Role 400 carrying the Council executor alone is Avalanche's shape too, and it is the asymmetry
/// worth knowing about before writing a payload: the DAO's governance executor can reach the
/// HubConfigurator but not the SpokeConfigurator, so reserve configs, caps, price sources and
/// spoke-side halting all have to go through the Council executor.
library AaveV4BaseHandover {
  /// @notice Thrown when the deployer still holds a role after the handover.
  error RoleNotRelinquished(uint64 role);
  /// @notice Thrown when a role did not reach its end-state holder.
  error RoleNotGranted(uint64 role, address account);
  /// @notice Thrown when a role that must be left unheld has a member.
  error RoleNotEmpty(uint64 role);
  /// @notice Thrown when a role holds a different number of members than the end state calls for,
  /// which is what catches a holder nothing here knows to look for.
  error UnexpectedRoleMemberCount(uint64 role, uint256 members, uint256 expected);
  /// @notice Thrown when a contract is not owned by its end-state holder.
  error UnexpectedOwner(address target, address owner);
  /// @notice Thrown when a Spoke registered on the Hub is not a transparent proxy, so it has no
  /// ProxyAdmin whose owner can be checked.
  error NotAProxy(address target);
  /// @notice Thrown when an asset is still live on a Spoke registered for it.
  error AssetNotHalted(uint256 assetId, address spoke);

  /// @notice Grants every role to its end-state holder, starts the manager ownership transfers,
  /// then drops the deployer's roles.
  /// @param market The deployed Base market.
  /// @param targets The addresses to hand the market over to.
  /// @param deployer The address currently holding the AccessManager admin role.
  function relinquish(
    AaveV4BaseConfigInputs.Market memory market,
    AaveV4BaseConfigInputs.Handover memory targets,
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
  /// @param market The deployed Base market.
  /// @param targets The addresses the market was handed over to.
  /// @param deployer The address that ran the deployment and configuration.
  function verify(
    AaveV4BaseConfigInputs.Market memory market,
    AaveV4BaseConfigInputs.Handover memory targets,
    address deployer
  ) internal view {
    verifyDeployerHoldsNoRole(market, deployer);
    verifyRoleHolders(market, targets);
    verifyProxyAdmins(market, targets.proxyAdminOwner);
    verifyOwnerships(market, targets);
    verifyAssetsHalted(market);
  }

  /// @notice Grants the AccessManager admin role and the two configurator domain admin roles to
  /// their end-state holders.
  /// @dev The Council's own role 0 grant is not here: `dropDeployerRoles` makes it, last, as it
  /// hands the AccessManager over.
  /// @param market The deployed Base market.
  /// @param targets The addresses to hand the market over to.
  function grantHandoverRoles(
    AaveV4BaseConfigInputs.Market memory market,
    AaveV4BaseConfigInputs.Handover memory targets
  ) internal {
    AaveV4AccessManagerRolesProcedure.grantAccessManagerAdminRole({
      accessManager: market.accessManager,
      adminToAdd: targets.governanceExecutor
    });

    address[2] memory hubAdmins = hubConfiguratorAdmins(targets);
    for (uint256 i; i < hubAdmins.length; ++i) {
      AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
        accessManager: market.accessManager,
        admin: hubAdmins[i]
      });
    }

    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: market.accessManager,
      admin: targets.councilExecutor
    });
  }

  /// @notice The three addresses that hold both configurator domain admin roles.
  /// @param targets The addresses the market is handed over to.
  /// @return The Council, its executor and the governance executor.
  /// @dev Role 400 is not derived from this: Avalanche grants it to the Council executor alone.
  function hubConfiguratorAdmins(
    AaveV4BaseConfigInputs.Handover memory targets
  ) internal pure returns (address[2] memory) {
    return [targets.councilExecutor, targets.governanceExecutor];
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
  /// @param market The deployed Base market.
  /// @param targets The addresses to hand the market over to.
  function transferManagerOwnership(
    AaveV4BaseConfigInputs.Market memory market,
    AaveV4BaseConfigInputs.Handover memory targets
  ) internal {
    if (market.nativeTokenGateway != address(0)) {
      Ownable2Step(market.nativeTokenGateway).transferOwnership(targets.gatewayOwner);
    }
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
  /// admin role to the Security Council.
  /// @dev The AccessManager admin role goes last: without it the deployer cannot revoke anything.
  /// @param market The deployed Base market.
  /// @param targets The addresses to hand the market over to.
  /// @param deployer The address currently holding the AccessManager admin role.
  function dropDeployerRoles(
    AaveV4BaseConfigInputs.Market memory market,
    AaveV4BaseConfigInputs.Handover memory targets,
    address deployer
  ) internal {
    IAccessManager accessManager = IAccessManager(market.accessManager);

    accessManager.revokeRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, deployer);
    accessManager.revokeRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, deployer);

    AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
      accessManager: market.accessManager,
      adminToAdd: targets.securityCouncil,
      adminToRemove: deployer
    });
  }

  /// @notice Reverts if the deployer still holds any role defined in `Roles`.
  /// @param market The deployed Base market.
  /// @param deployer The address that ran the deployment and configuration.
  function verifyDeployerHoldsNoRole(
    AaveV4BaseConfigInputs.Market memory market,
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

  /// @notice Reverts unless every role sits with its end-state holder, and unless the roles that
  /// are meant to be unheld are empty.
  /// @param market The deployed Base market.
  /// @param targets The addresses the market was handed over to.
  function verifyRoleHolders(
    AaveV4BaseConfigInputs.Market memory market,
    AaveV4BaseConfigInputs.Handover memory targets
  ) internal view {
    _requireRole(market, Roles.ACCESS_MANAGER_ADMIN_ROLE, targets.securityCouncil);
    _requireRole(market, Roles.ACCESS_MANAGER_ADMIN_ROLE, targets.governanceExecutor);
    _requireRoleMemberCount(market, Roles.ACCESS_MANAGER_ADMIN_ROLE, 2);

    address[2] memory hubAdmins = hubConfiguratorAdmins(targets);
    for (uint256 i; i < hubAdmins.length; ++i) {
      _requireRole(market, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, hubAdmins[i]);
    }
    _requireRoleMemberCount(market, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, hubAdmins.length);

    _requireRole(market, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, targets.councilExecutor);
    _requireRoleMemberCount(market, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, 1);

    // the configurators keep calling the Hub and Spokes on the Council's behalf
    _requireRole(market, Roles.HUB_CONFIGURATOR_ROLE, market.hubConfigurator);
    _requireRoleMemberCount(market, Roles.HUB_CONFIGURATOR_ROLE, 1);
    _requireRole(market, Roles.SPOKE_CONFIGURATOR_ROLE, market.spokeConfigurator);
    _requireRoleMemberCount(market, Roles.SPOKE_CONFIGURATOR_ROLE, 1);

    _requireRoleEmpty(market, Roles.HUB_DOMAIN_ADMIN_ROLE);
    _requireRoleEmpty(market, Roles.HUB_FEE_MINTER_ROLE);
    _requireRoleEmpty(market, Roles.HUB_DEFICIT_ELIMINATOR_ROLE);
    _requireRoleEmpty(market, Roles.SPOKE_DOMAIN_ADMIN_ROLE);
    _requireRoleEmpty(market, Roles.SPOKE_USER_POSITION_UPDATER_ROLE);
  }

  /// @notice Reverts unless every ProxyAdmin in the market is owned by its end-state holder.
  /// @dev The Hub, the configured Spokes and the TreasurySpoke take their ProxyAdmin owner from the
  /// deploy inputs. Every other Spoke the Hub has registered is walked too, because a
  /// TokenizationSpoke is deployed during configuration or by a later listing payload rather than by
  /// the deploy, and takes its ProxyAdmin owner from whichever of the two deployed it — which is the
  /// one place this ownership can diverge from the rest of the market.
  /// @param market The deployed Base market.
  /// @param proxyAdminOwner The address every ProxyAdmin must be owned by.
  function verifyProxyAdmins(
    AaveV4BaseConfigInputs.Market memory market,
    address proxyAdminOwner
  ) internal view {
    _requireProxyAdminOwner(market.hub, proxyAdminOwner);
    for (uint256 i; i < market.spokes.length; ++i) {
      _requireProxyAdminOwner(market.spokes[i], proxyAdminOwner);
    }
    _requireProxyAdminOwner(market.treasurySpoke, proxyAdminOwner);

    IHub hub = IHub(market.hub);
    uint256 assetCount = hub.getAssetCount();

    for (uint256 assetId; assetId < assetCount; ++assetId) {
      uint256 spokeCount = hub.getSpokeCount(assetId);
      for (uint256 i; i < spokeCount; ++i) {
        _requireProxyAdminOwner(hub.getSpokeAddress(assetId, i), proxyAdminOwner);
      }
    }
  }

  /// @notice Reverts unless every ownership sits with, or is pending acceptance by, its end-state
  /// holder.
  /// @dev The TreasurySpoke is owned by the Council from the deploy transaction onwards and is
  /// checked here to prove the deployer never was its owner. The managers and gateways are
  /// `Ownable2Step` and the deployer owns them until the Council accepts, so either state passes.
  /// @param market The deployed Base market.
  /// @param targets The addresses the market was handed over to.
  function verifyOwnerships(
    AaveV4BaseConfigInputs.Market memory market,
    AaveV4BaseConfigInputs.Handover memory targets
  ) internal view {
    _requireOwner(market.treasurySpoke, targets.treasurySpokeOwner);

    if (market.nativeTokenGateway != address(0)) {
      _requireOwnerOrPending(market.nativeTokenGateway, targets.gatewayOwner);
    }
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
  /// @param market The deployed Base market.
  function verifyAssetsHalted(AaveV4BaseConfigInputs.Market memory market) internal view {
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

  function _requireRole(
    AaveV4BaseConfigInputs.Market memory market,
    uint64 role,
    address account
  ) private view {
    (bool isMember, ) = IAccessManager(market.accessManager).hasRole(role, account);
    require(isMember, RoleNotGranted(role, account));
  }

  /// @dev `AccessManagerEnumerable` tracks role members, so a role meant to be unheld can be
  /// asserted empty rather than only asserted not to hold the addresses this script knows about.
  function _requireRoleEmpty(
    AaveV4BaseConfigInputs.Market memory market,
    uint64 role
  ) private view {
    require(
      IAccessManagerEnumerable(market.accessManager).getRoleMemberCount(role) == 0,
      RoleNotEmpty(role)
    );
  }

  /// @dev Pins the exact size of a role, so an extra holder fails the handover even when every
  /// expected holder is in place.
  function _requireRoleMemberCount(
    AaveV4BaseConfigInputs.Market memory market,
    uint64 role,
    uint256 expected
  ) private view {
    uint256 members = IAccessManagerEnumerable(market.accessManager).getRoleMemberCount(role);
    require(members == expected, UnexpectedRoleMemberCount(role, members, expected));
  }

  function _requireProxyAdminOwner(address proxy, address expectedOwner) private view {
    address admin = AaveV4BaseConfigInputs.proxyAdmin(proxy);
    require(admin != address(0), NotAProxy(proxy));
    _requireOwner(admin, expectedOwner);
  }

  /// @dev Passes if the target is already owned by `expectedOwner`, or if it is the pending owner of
  /// an `Ownable2Step` transfer that has been started but not accepted.
  function _requireOwnerOrPending(address target, address expectedOwner) private view {
    address owner = Ownable(target).owner();
    if (owner == expectedOwner) return;

    require(Ownable2Step(target).pendingOwner() == expectedOwner, UnexpectedOwner(target, owner));
  }

  function _requireOwner(address target, address expectedOwner) private view {
    address owner = Ownable(target).owner();
    require(owner == expectedOwner, UnexpectedOwner(target, owner));
  }
}
