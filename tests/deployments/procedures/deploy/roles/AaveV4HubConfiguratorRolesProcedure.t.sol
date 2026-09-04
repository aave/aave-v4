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
      role: Roles.HUB_CONFIGURATOR_DOMAIN_BASE_ROLE,
      admin: admin
    });

    vm.expectRevert('invalid admin');
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_DOMAIN_BASE_ROLE,
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
    bytes4[] memory selectors = wrapper.getHubConfiguratorDomainBaseRoleSelectors();

    vm.expectRevert('invalid access manager');
    wrapper.setupHubConfiguratorRole({
      accessManager: address(0),
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_DOMAIN_BASE_ROLE,
      selectors: selectors
    });

    vm.expectRevert('invalid hub configurator');
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: address(0),
      role: Roles.HUB_CONFIGURATOR_DOMAIN_BASE_ROLE,
      selectors: selectors
    });
  }

  function test_grantHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    _assertHasRole(Roles.HUB_CONFIGURATOR_DOMAIN_BASE_ROLE);
    _assertHasRole(Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE);
    _assertHasRole(Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE);
  }

  function test_setupHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    _assertSelectorsMapTo(
      wrapper.getHubConfiguratorDomainBaseRoleSelectors(),
      Roles.HUB_CONFIGURATOR_DOMAIN_BASE_ROLE
    );
    _assertSelectorsMapTo(
      wrapper.getHubConfiguratorRiskManagementRoleSelectors(),
      Roles.HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE
    );
    _assertSelectorsMapTo(
      wrapper.getHubConfiguratorEmergencyRoleSelectors(),
      Roles.HUB_CONFIGURATOR_EMERGENCY_ROLE
    );
  }

  function _grantAdminToWrapper(address wrapperAddr) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, wrapperAddr, 0);
  }

  function _assertHasRole(uint64 role) internal view {
    (bool hasRole, ) = IAccessManager(accessManager).hasRole(role, admin);
    assertTrue(hasRole);
  }

  function _assertSelectorsMapTo(bytes4[] memory selectors, uint64 role) internal view {
    for (uint256 i; i < selectors.length; i++) {
      assertEq(
        IAccessManager(accessManager).getTargetFunctionRole(hubConfigurator, selectors[i]),
        role
      );
    }
  }

  function test_getHubConfiguratorDomainBaseRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorDomainBaseRoleSelectors();
    assertEq(selectors.length, 13);
    assertEq(selectors[0], IHubConfigurator.addAsset.selector);
    assertEq(selectors[1], IHubConfigurator.addAssetWithDecimals.selector);
    assertEq(selectors[2], IHubConfigurator.updateLiquidityFee.selector);
    assertEq(selectors[3], IHubConfigurator.updateFeeReceiver.selector);
    assertEq(selectors[4], IHubConfigurator.updateFeeConfig.selector);
    assertEq(selectors[5], IHubConfigurator.updateInterestRateStrategy.selector);
    assertEq(selectors[6], IHubConfigurator.updateReinvestmentController.selector);
    assertEq(selectors[7], IHubConfigurator.resetAssetCaps.selector);
    assertEq(selectors[8], IHubConfigurator.addSpoke.selector);
    assertEq(selectors[9], IHubConfigurator.addSpokeToAssets.selector);
    assertEq(selectors[10], IHubConfigurator.updateSpokeActive.selector);
    assertEq(selectors[11], IHubConfigurator.updateSpokeHalted.selector);
    assertEq(selectors[12], IHubConfigurator.resetSpokeCaps.selector);
  }

  function test_getHubConfiguratorRiskManagementRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorRiskManagementRoleSelectors();
    assertEq(selectors.length, 5);
    assertEq(selectors[0], IHubConfigurator.updateSpokeAddCap.selector);
    assertEq(selectors[1], IHubConfigurator.updateSpokeDrawCap.selector);
    assertEq(selectors[2], IHubConfigurator.updateSpokeRiskPremiumThreshold.selector);
    assertEq(selectors[3], IHubConfigurator.updateSpokeCaps.selector);
    assertEq(selectors[4], IHubConfigurator.updateInterestRateData.selector);
  }

  function test_getHubConfiguratorEmergencyRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorEmergencyRoleSelectors();
    assertEq(selectors.length, 4);
    assertEq(selectors[0], IHubConfigurator.deactivateAsset.selector);
    assertEq(selectors[1], IHubConfigurator.haltAsset.selector);
    assertEq(selectors[2], IHubConfigurator.deactivateSpoke.selector);
    assertEq(selectors[3], IHubConfigurator.haltSpoke.selector);
  }

  function test_canCall_hubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    _assertCanCall(hubConfigurator, wrapper.getHubConfiguratorDomainBaseRoleSelectors());
    _assertCanCall(hubConfigurator, wrapper.getHubConfiguratorRiskManagementRoleSelectors());
    _assertCanCall(hubConfigurator, wrapper.getHubConfiguratorEmergencyRoleSelectors());
  }
}
