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

    (bool hasRole, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      admin
    );
    assertTrue(hasRole);
  }

  function test_setupHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    bytes4[] memory selectors = wrapper.getHubConfiguratorDomainAdminRoleSelectors();
    for (uint256 i; i < selectors.length; i++) {
      assertEq(
        IAccessManager(accessManager).getTargetFunctionRole(hubConfigurator, selectors[i]),
        Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE
      );
    }
  }

  function _grantAdminToWrapper(address wrapperAddr) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, wrapperAddr, 0);
  }

  function test_getHubConfiguratorDomainAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorDomainAdminRoleSelectors();
    assertEq(selectors.length, 24);
    assertEq(selectors[0], IHubConfigurator.addAsset.selector);
    assertEq(selectors[1], IHubConfigurator.addAssetWithDecimals.selector);
    assertEq(selectors[2], IHubConfigurator.updateLiquidityFee.selector);
    assertEq(selectors[3], IHubConfigurator.updateFeeReceiver.selector);
    assertEq(selectors[4], IHubConfigurator.updateFeeConfig.selector);
    assertEq(selectors[5], IHubConfigurator.updateInterestRateStrategy.selector);
    assertEq(selectors[6], IHubConfigurator.updateReinvestmentController.selector);
    assertEq(selectors[7], IHubConfigurator.resetAssetCaps.selector);
    assertEq(selectors[8], IHubConfigurator.deactivateAsset.selector);
    assertEq(selectors[9], IHubConfigurator.haltAsset.selector);
    assertEq(selectors[10], IHubConfigurator.addSpoke.selector);
    assertEq(selectors[11], IHubConfigurator.addSpokeToAssets.selector);
    assertEq(selectors[12], IHubConfigurator.updateSpokeActive.selector);
    assertEq(selectors[13], IHubConfigurator.updateSpokeHalted.selector);
    assertEq(selectors[14], IHubConfigurator.updateSpokeAddCap.selector);
    assertEq(selectors[15], IHubConfigurator.updateSpokeDrawCap.selector);
    assertEq(selectors[16], IHubConfigurator.updateSpokeRiskPremiumThreshold.selector);
    assertEq(selectors[17], IHubConfigurator.updateSpokeCaps.selector);
    assertEq(selectors[18], IHubConfigurator.deactivateSpoke.selector);
    assertEq(selectors[19], IHubConfigurator.haltSpoke.selector);
    assertEq(selectors[20], IHubConfigurator.resetSpokeCaps.selector);
    assertEq(selectors[21], IHubConfigurator.updateInterestRateData.selector);
    assertEq(selectors[22], IHubConfigurator.unhaltSpoke.selector);
    assertEq(selectors[23], IHubConfigurator.unhaltAsset.selector);
  }

  function test_canCall_hubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    _assertCanCall(hubConfigurator, wrapper.getHubConfiguratorDomainAdminRoleSelectors());
  }
}
