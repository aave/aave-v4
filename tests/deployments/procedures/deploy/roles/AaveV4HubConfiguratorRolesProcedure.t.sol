// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

contract AaveV4HubConfiguratorRolesProcedureTest is ProceduresBase {
  AaveV4HubConfiguratorRolesProcedureWrapper public wrapper;
  address public hubConfigurator = makeAddr('hubConfigurator');

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4HubConfiguratorRolesProcedureWrapper();
  }

  function test_grantHubConfiguratorRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.grantHubConfiguratorRole({
      accessManager: address(0),
      role: Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      admin: admin
    });

    vm.expectRevert('invalid admin');
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      admin: address(0)
    });
  }

  function test_setupHubConfiguratorAllRoles_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: address(0),
      hubConfigurator: hubConfigurator
    });

    vm.expectRevert('invalid hub configurator');
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: address(0)
    });
  }

  function test_setupHubConfiguratorRole_reverts() public {
    bytes4[] memory selectors = wrapper.getHubConfiguratorDomainAdminRoleSelectors();

    vm.expectRevert('invalid access manager');
    wrapper.setupHubConfiguratorRole({
      accessManager: address(0),
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });

    vm.expectRevert('invalid hub configurator');
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: address(0),
      role: Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });
  }

  function test_grantHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    uint64[] memory roles = _allRoles();
    for (uint256 i; i < roles.length; i++) {
      (bool hasRole, ) = IAccessManager(accessManager).hasRole(roles[i], admin);
      assertTrue(hasRole, vm.toString(roles[i]));
    }
  }

  function test_setupHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    uint64[] memory roles = _allRoles();
    for (uint256 i; i < roles.length; i++) {
      bytes4[] memory selectors = _selectorsOf(roles[i]);
      for (uint256 j; j < selectors.length; j++) {
        assertEq(
          IAccessManager(accessManager).getTargetFunctionRole(hubConfigurator, selectors[j]),
          roles[i]
        );
      }
    }
  }

  function _grantAdminToWrapper(address wrapperAddr) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, wrapperAddr, 0);
  }

  function test_getHubConfiguratorDomainAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorDomainAdminRoleSelectors();
    assertEq(selectors.length, 7);
    assertEq(selectors[0], IHubConfigurator.updateLiquidityFee.selector);
    assertEq(selectors[1], IHubConfigurator.updateFeeReceiver.selector);
    assertEq(selectors[2], IHubConfigurator.updateFeeConfig.selector);
    assertEq(selectors[3], IHubConfigurator.updateInterestRateStrategy.selector);
    assertEq(selectors[4], IHubConfigurator.updateReinvestmentController.selector);
    assertEq(selectors[5], IHubConfigurator.resetAssetCaps.selector);
    assertEq(selectors[6], IHubConfigurator.resetSpokeCaps.selector);
  }

  function test_getHubConfiguratorSpokeActiveRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorSpokeActiveRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateSpokeActive.selector);
  }

  function test_getHubConfiguratorSpokeHaltedRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorSpokeHaltedRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateSpokeHalted.selector);
  }

  function test_getHubConfiguratorListingRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorListingRoleSelectors();
    assertEq(selectors.length, 4);
    assertEq(selectors[0], IHubConfigurator.addAsset.selector);
    assertEq(selectors[1], IHubConfigurator.addAssetWithDecimals.selector);
    assertEq(selectors[2], IHubConfigurator.addSpoke.selector);
    assertEq(selectors[3], IHubConfigurator.addSpokeToAssets.selector);
  }

  function test_getHubConfiguratorEmergencyRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorEmergencyRoleSelectors();
    assertEq(selectors.length, 4);
    assertEq(selectors[0], IHubConfigurator.deactivateAsset.selector);
    assertEq(selectors[1], IHubConfigurator.haltAsset.selector);
    assertEq(selectors[2], IHubConfigurator.deactivateSpoke.selector);
    assertEq(selectors[3], IHubConfigurator.haltSpoke.selector);
  }

  function test_getHubConfiguratorRiskManagementRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorRiskManagementRoleSelectors();
    assertEq(selectors.length, 5);
    assertEq(selectors[0], IHubConfigurator.updateSpokeAddCap.selector);
    assertEq(selectors[1], IHubConfigurator.updateSpokeDrawCap.selector);
    assertEq(selectors[2], IHubConfigurator.updateSpokeCaps.selector);
    assertEq(selectors[3], IHubConfigurator.updateSpokeRiskPremiumThreshold.selector);
    assertEq(selectors[4], IHubConfigurator.updateInterestRateData.selector);
  }

  /// @dev The five granular roles plus the residual domain admin must partition the
  /// HubConfigurator selectors: no selector is left unassigned and none is shared.
  function test_rolesPartitionAllSelectors() public view {
    uint64[] memory roles = _allRoles();
    bytes4[] memory seen = new bytes4[](22);
    uint256 count;

    for (uint256 i; i < roles.length; i++) {
      bytes4[] memory selectors = _selectorsOf(roles[i]);
      for (uint256 j; j < selectors.length; j++) {
        for (uint256 k; k < count; k++) {
          assertTrue(seen[k] != selectors[j], 'selector assigned to two roles');
        }
        seen[count++] = selectors[j];
      }
    }

    assertEq(count, 22, 'selector count diverges from the HubConfigurator surface');
  }

  function test_canCall_hubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    uint64[] memory roles = _allRoles();
    for (uint256 i; i < roles.length; i++) {
      _assertCanCall(hubConfigurator, _selectorsOf(roles[i]));
    }
  }

  /// @dev A holder of a single granular role can only call that role's selectors.
  function test_canCall_hubConfiguratorRiskManagementRoleOnly() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE,
      admin: admin
    });
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    _assertCanCall(hubConfigurator, wrapper.getHubConfiguratorRiskManagementRoleSelectors());
    _assertCannotCall(hubConfigurator, wrapper.getHubConfiguratorListingRoleSelectors());
    _assertCannotCall(hubConfigurator, wrapper.getHubConfiguratorEmergencyRoleSelectors());
    _assertCannotCall(hubConfigurator, wrapper.getHubConfiguratorDomainAdminRoleSelectors());
  }

  function _allRoles() internal pure returns (uint64[] memory) {
    uint64[] memory roles = new uint64[](6);
    roles[0] = Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE;
    roles[1] = Roles.HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE;
    roles[2] = Roles.HUB_CONFIGURATOR_SPOKE_HALTED_ROLE;
    roles[3] = Roles.HUB_CONFIGURATOR_LISTING_ROLE;
    roles[4] = Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE;
    roles[5] = Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE;
    return roles;
  }

  function _selectorsOf(uint64 role) internal view returns (bytes4[] memory) {
    if (role == Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE) {
      return wrapper.getHubConfiguratorDomainAdminRoleSelectors();
    }
    if (role == Roles.HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE) {
      return wrapper.getHubConfiguratorSpokeActiveRoleSelectors();
    }
    if (role == Roles.HUB_CONFIGURATOR_SPOKE_HALTED_ROLE) {
      return wrapper.getHubConfiguratorSpokeHaltedRoleSelectors();
    }
    if (role == Roles.HUB_CONFIGURATOR_LISTING_ROLE) {
      return wrapper.getHubConfiguratorListingRoleSelectors();
    }
    if (role == Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE) {
      return wrapper.getHubConfiguratorEmergencyRoleSelectors();
    }
    return wrapper.getHubConfiguratorRiskManagementRoleSelectors();
  }
}
