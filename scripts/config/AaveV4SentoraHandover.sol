// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4SentoraConfigInputs} from 'scripts/config/AaveV4SentoraConfigInputs.sol';
import {AaveV4SentoraRoles} from 'scripts/config/AaveV4SentoraRoles.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title AaveV4SentoraHandover
/// @author Aave Labs
/// @notice Hands a Sentora market over from the deployer to the V4 Security Council, the Sentora
/// Executor, the Risk Steward and the Emergency Operator, and proves the deployer holds nothing
/// afterwards.
/// @dev Runs after `AaveV4SentoraConfiguration`. Roles reach their end-state holders before the
/// deployer drops its own, because revoking the AccessManager admin role first would strand the
/// rest. No holder carries an execution delay.
///
/// | role                                    | holder                               | members |
/// | --------------------------------------- | ------------------------------------ | ------- |
/// | 0    ACCESS_MANAGER_ADMIN               | admin (V4 Security Council)          | 1       |
/// | 101  HUB_CONFIGURATOR_ROLE              | the HubConfigurator                  | 1       |
/// | 200  HUB_CONFIGURATOR_DOMAIN_ADMIN      | Sentora Executor                     | 1       |
/// | 301  SPOKE_CONFIGURATOR_ROLE            | the SpokeConfigurator                | 1       |
/// | 400  SPOKE_CONFIGURATOR_DOMAIN_ADMIN    | Sentora Executor                     | 1       |
/// | 1000 SENTORA_RISK_ROLE                  | Sentora Executor, Risk Steward       | 2       |
/// | 1001 SENTORA_EMERGENCY_ROLE             | Emergency Operator, admin            | 2       |
/// | 100, 102, 103, 300, 302                 | nobody                               | 0       |
///
/// Roles 100, 102, 103, 300 and 302 reach the Hub and Spokes directly rather than through a
/// configurator, and are left unheld as on the live Ethereum and Avalanche markets: nothing at
/// launch calls `mintFeeShares`, `eliminateDeficit` or the user position updaters, and role 0 can
/// grant them when something does. Roles 200 and 400 lose the risk and emergency selectors to the
/// Sentora roles and keep every other one, see `AaveV4SentoraRoles`.
library AaveV4SentoraHandover {
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
  /// @notice Thrown when a role holder carries a different execution delay than the end state calls
  /// for.
  error UnexpectedExecutionDelay(uint64 role, address account, uint32 delay);
  /// @notice Thrown when a configurator selector is not wired to the role the end state calls for.
  error UnexpectedSelectorRole(address target, bytes4 selector, uint64 role);
  /// @notice Thrown when a role reaches a different number of selectors on a configurator than the
  /// end state calls for, which is what catches a selector wired to it from elsewhere.
  error UnexpectedSelectorCount(uint64 role, address target, uint256 count, uint256 expected);

  /// @notice Moves the risk and emergency selectors to the Sentora roles, grants every role to its
  /// end-state holder, hands over the managers and the TreasurySpoke, then drops the deployer's
  /// roles.
  /// @param market The deployed Sentora market.
  /// @param targets The addresses to hand the market over to.
  /// @param deployer The address currently holding the AccessManager admin role.
  function relinquish(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Handover memory targets,
    address deployer
  ) internal {
    assignSentoraSelectors(market);
    grantHandoverRoles(market, targets);
    transferManagerOwnership(market, targets);
    transferTreasurySpoke(market, targets);
    dropDeployerRoles(market, targets, deployer);
  }

  /// @notice Reverts unless the deployer holds no role and every role and ownership sits with its
  /// end-state holder.
  /// @dev Enumerates every role in `Roles`, every proxy admin and every listed asset rather than
  /// sampling, since a role or ownership left behind is not recoverable once the deployer is out.
  /// @param market The deployed Sentora market.
  /// @param targets The addresses the market was handed over to.
  /// @param deployer The address that ran the deployment and configuration.
  function verify(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Handover memory targets,
    address deployer
  ) internal view {
    verifyDeployerHoldsNoRole(market, deployer);
    verifyRoleHolders(market, targets);
    verifySelectorRoles(market);
    verifyProxyAdmins(market, targets.proxyAdminOwner);
    verifyOwnerships(market, targets);
    verifyAssetsHalted(market);
  }

  /// @notice Rewires the risk and emergency selectors of both configurators to the Sentora roles.
  /// @dev Runs after configuration, which calls the configurators through roles 200 and 400. Every
  /// other selector stays on those two roles.
  /// @param market The deployed Sentora market.
  function assignSentoraSelectors(AaveV4SentoraConfigInputs.Market memory market) internal {
    IAccessManager accessManager = IAccessManager(market.accessManager);

    accessManager.setTargetFunctionRole(
      market.hubConfigurator,
      AaveV4SentoraRoles.hubRiskSelectors(),
      AaveV4SentoraRoles.SENTORA_RISK_ROLE
    );
    accessManager.setTargetFunctionRole(
      market.hubConfigurator,
      AaveV4SentoraRoles.hubEmergencySelectors(),
      AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE
    );
    accessManager.setTargetFunctionRole(
      market.spokeConfigurator,
      AaveV4SentoraRoles.spokeRiskSelectors(),
      AaveV4SentoraRoles.SENTORA_RISK_ROLE
    );
    accessManager.setTargetFunctionRole(
      market.spokeConfigurator,
      AaveV4SentoraRoles.spokeEmergencySelectors(),
      AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE
    );
  }

  /// @notice Grants the configurator admin roles to the Sentora Executor, the risk role to the
  /// Sentora Executor and the Risk Steward, and the emergency role to the Emergency Operator and the
  /// admin, so the V4 Security Council can halt, pause and freeze the market directly too.
  /// @dev The admin's role 0 grant is not here: `dropDeployerRoles` makes it, last, as it hands the
  /// AccessManager over.
  /// @param market The deployed Sentora market.
  /// @param targets The addresses to hand the market over to.
  function grantHandoverRoles(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Handover memory targets
  ) internal {
    IAccessManager accessManager = IAccessManager(market.accessManager);

    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, targets.sentoraExecutor, 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, targets.sentoraExecutor, 0);
    accessManager.grantRole(AaveV4SentoraRoles.SENTORA_RISK_ROLE, targets.sentoraExecutor, 0);
    accessManager.grantRole(AaveV4SentoraRoles.SENTORA_RISK_ROLE, targets.riskSteward, 0);
    accessManager.grantRole(
      AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE,
      targets.emergencyOperator,
      0
    );
    accessManager.grantRole(AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE, targets.admin, 0);
  }

  /// @notice Starts the ownership transfer of every position manager and gateway to their end-state
  /// owners.
  /// @dev These are the only contracts the deployer owns, because configuration needs `onlyOwner`
  /// access to `registerSpoke` on them. `PositionManagerBase` is `Ownable2Step`, so this records a
  /// pending owner and the new owner completes it with one `acceptOwnership` per contract — the
  /// whole of what the admin has to do to take the market over.
  ///
  /// Until it accepts, the deployer still owns them, which means `registerSpoke`,
  /// `renouncePositionManagerRole` and — since the rescue guardian is `owner()` — `rescueToken` and
  /// `rescueNative`. That window should be closed promptly.
  /// @param market The deployed Sentora market.
  /// @param targets The addresses to hand the market over to.
  function transferManagerOwnership(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Handover memory targets
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

  /// @notice Moves the TreasurySpoke's ProxyAdmin to its end-state owner and starts the ownership
  /// transfer of the TreasurySpoke itself.
  /// @dev The deploy gives the TreasurySpoke's ProxyAdmin the TreasurySpoke's own owner, which is the
  /// deployer until here. `ProxyAdmin` is single-step `Ownable`, so its transfer completes at once;
  /// the TreasurySpoke is `Ownable2Step`, so its new owner accepts it like the managers.
  /// @param market The deployed Sentora market.
  /// @param targets The addresses to hand the market over to.
  function transferTreasurySpoke(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Handover memory targets
  ) internal {
    Ownable(AaveV4SentoraConfigInputs.proxyAdmin(market.treasurySpoke)).transferOwnership(
      targets.proxyAdminOwner
    );
    Ownable2Step(market.treasurySpoke).transferOwnership(targets.treasurySpokeOwner);
  }

  /// @notice Revokes the deployer's configurator domain admin roles and moves the AccessManager
  /// admin role to the admin.
  /// @dev The AccessManager admin role goes last: without it the deployer cannot revoke anything.
  /// @param market The deployed Sentora market.
  /// @param targets The addresses to hand the market over to.
  /// @param deployer The address currently holding the AccessManager admin role.
  function dropDeployerRoles(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Handover memory targets,
    address deployer
  ) internal {
    IAccessManager accessManager = IAccessManager(market.accessManager);

    accessManager.revokeRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, deployer);
    accessManager.revokeRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, deployer);

    AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
      accessManager: market.accessManager,
      adminToAdd: targets.admin,
      adminToRemove: deployer
    });
  }

  /// @notice Reverts if the deployer still holds any role defined in `Roles` or
  /// `AaveV4SentoraRoles`.
  /// @param market The deployed Sentora market.
  /// @param deployer The address that ran the deployment and configuration.
  function verifyDeployerHoldsNoRole(
    AaveV4SentoraConfigInputs.Market memory market,
    address deployer
  ) internal view {
    uint64[12] memory roles = [
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      Roles.HUB_DOMAIN_ADMIN_ROLE,
      Roles.HUB_CONFIGURATOR_ROLE,
      Roles.HUB_FEE_MINTER_ROLE,
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE,
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_CONFIGURATOR_ROLE,
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      AaveV4SentoraRoles.SENTORA_RISK_ROLE,
      AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE
    ];

    for (uint256 i; i < roles.length; ++i) {
      (bool isMember, ) = IAccessManager(market.accessManager).hasRole(roles[i], deployer);
      require(!isMember, RoleNotRelinquished(roles[i]));
    }
  }

  /// @notice Reverts unless every role sits with its end-state holder, and unless the roles that
  /// are meant to be unheld are empty.
  /// @param market The deployed Sentora market.
  /// @param targets The addresses the market was handed over to.
  function verifyRoleHolders(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Handover memory targets
  ) internal view {
    _requireRole(market, Roles.ACCESS_MANAGER_ADMIN_ROLE, targets.admin);
    _requireRoleMemberCount(market, Roles.ACCESS_MANAGER_ADMIN_ROLE, 1);

    _requireRoleWithDelay(
      market,
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      targets.sentoraExecutor,
      0
    );
    _requireRoleMemberCount(market, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, 1);
    _requireRoleWithDelay(
      market,
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      targets.sentoraExecutor,
      0
    );
    _requireRoleMemberCount(market, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, 1);

    _requireRoleWithDelay(market, AaveV4SentoraRoles.SENTORA_RISK_ROLE, targets.sentoraExecutor, 0);
    _requireRoleWithDelay(market, AaveV4SentoraRoles.SENTORA_RISK_ROLE, targets.riskSteward, 0);
    _requireRoleMemberCount(market, AaveV4SentoraRoles.SENTORA_RISK_ROLE, 2);

    _requireRoleWithDelay(
      market,
      AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE,
      targets.emergencyOperator,
      0
    );
    _requireRoleWithDelay(market, AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE, targets.admin, 0);
    _requireRoleMemberCount(market, AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE, 2);

    // the configurators keep calling the Hub and Spokes on the admins' behalf
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

  /// @notice Reverts unless every configurator selector is wired to the role the end state calls
  /// for, and unless each role reaches exactly that many selectors on each configurator.
  /// @param market The deployed Sentora market.
  function verifySelectorRoles(AaveV4SentoraConfigInputs.Market memory market) internal view {
    _requireSelectors(
      market,
      market.hubConfigurator,
      AaveV4SentoraRoles.hubRiskSelectors(),
      AaveV4SentoraRoles.SENTORA_RISK_ROLE
    );
    _requireSelectors(
      market,
      market.hubConfigurator,
      AaveV4SentoraRoles.hubEmergencySelectors(),
      AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE
    );
    _requireSelectors(
      market,
      market.hubConfigurator,
      AaveV4SentoraRoles.hubAdminSelectors(),
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE
    );
    _requireSelectors(
      market,
      market.spokeConfigurator,
      AaveV4SentoraRoles.spokeRiskSelectors(),
      AaveV4SentoraRoles.SENTORA_RISK_ROLE
    );
    _requireSelectors(
      market,
      market.spokeConfigurator,
      AaveV4SentoraRoles.spokeEmergencySelectors(),
      AaveV4SentoraRoles.SENTORA_EMERGENCY_ROLE
    );
    _requireSelectors(
      market,
      market.spokeConfigurator,
      AaveV4SentoraRoles.spokeAdminSelectors(),
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE
    );
  }

  /// @notice Reverts unless every ProxyAdmin in the market is owned by its end-state holder.
  /// @dev The Hub, the configured Spokes and the TreasurySpoke take their ProxyAdmin owner from the
  /// deploy inputs. Every other Spoke the Hub has registered is walked too, because a
  /// TokenizationSpoke is deployed during configuration or by a later listing payload rather than by
  /// the deploy, and takes its ProxyAdmin owner from whichever of the two deployed it — which is the
  /// one place this ownership can diverge from the rest of the market.
  /// @param market The deployed Sentora market.
  /// @param proxyAdminOwner The address every ProxyAdmin must be owned by.
  function verifyProxyAdmins(
    AaveV4SentoraConfigInputs.Market memory market,
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
  /// @dev The TreasurySpoke, managers and gateways are `Ownable2Step` and the deployer owns them
  /// until the new owner accepts, so either state passes.
  /// @param market The deployed Sentora market.
  /// @param targets The addresses the market was handed over to.
  function verifyOwnerships(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Handover memory targets
  ) internal view {
    _requireOwnerOrPending(market.treasurySpoke, targets.treasurySpokeOwner);

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
  /// @param market The deployed Sentora market.
  function verifyAssetsHalted(AaveV4SentoraConfigInputs.Market memory market) internal view {
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
    AaveV4SentoraConfigInputs.Market memory market,
    uint64 role,
    address account
  ) private view {
    (bool isMember, ) = IAccessManager(market.accessManager).hasRole(role, account);
    require(isMember, RoleNotGranted(role, account));
  }

  function _requireRoleWithDelay(
    AaveV4SentoraConfigInputs.Market memory market,
    uint64 role,
    address account,
    uint32 expectedDelay
  ) private view {
    (bool isMember, uint32 delay) = IAccessManager(market.accessManager).hasRole(role, account);
    require(isMember, RoleNotGranted(role, account));
    require(delay == expectedDelay, UnexpectedExecutionDelay(role, account, delay));
  }

  /// @dev Checks each selector's role, then pins the role's selector count on the target, so a
  /// selector rewired to the role from elsewhere fails too.
  function _requireSelectors(
    AaveV4SentoraConfigInputs.Market memory market,
    address target,
    bytes4[] memory selectors,
    uint64 expectedRole
  ) private view {
    for (uint256 i; i < selectors.length; ++i) {
      uint64 role = IAccessManager(market.accessManager).getTargetFunctionRole(
        target,
        selectors[i]
      );
      require(role == expectedRole, UnexpectedSelectorRole(target, selectors[i], role));
    }

    uint256 count = IAccessManagerEnumerable(market.accessManager).getRoleTargetSelectorCount(
      expectedRole,
      target
    );
    require(
      count == selectors.length,
      UnexpectedSelectorCount(expectedRole, target, count, selectors.length)
    );
  }

  /// @dev `AccessManagerEnumerable` tracks role members, so a role meant to be unheld can be
  /// asserted empty rather than only asserted not to hold the addresses this script knows about.
  function _requireRoleEmpty(
    AaveV4SentoraConfigInputs.Market memory market,
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
    AaveV4SentoraConfigInputs.Market memory market,
    uint64 role,
    uint256 expected
  ) private view {
    uint256 members = IAccessManagerEnumerable(market.accessManager).getRoleMemberCount(role);
    require(members == expected, UnexpectedRoleMemberCount(role, members, expected));
  }

  function _requireProxyAdminOwner(address proxy, address expectedOwner) private view {
    address admin = AaveV4SentoraConfigInputs.proxyAdmin(proxy);
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
