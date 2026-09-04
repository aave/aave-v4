// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

contract AaveV4SpokeConfiguratorRolesProcedureTest is ProceduresBase {
  AaveV4SpokeConfiguratorRolesProcedureWrapper public wrapper;
  address public spokeConfigurator = makeAddr('spokeConfigurator');

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4SpokeConfiguratorRolesProcedureWrapper();
  }

  function test_grantSpokeConfiguratorRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.grantSpokeConfiguratorRole({
      accessManager: address(0),
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE,
      admin: admin
    });

    vm.expectRevert('invalid admin');
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE,
      admin: address(0)
    });
  }

  function test_setupSpokeConfiguratorRoles_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator
    });

    vm.expectRevert('invalid spoke configurator');
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: address(0)
    });
  }

  function test_setupSpokeConfiguratorRole_reverts() public {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDomainBaseRoleSelectors();

    vm.expectRevert('invalid access manager');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE,
      selectors: selectors
    });

    vm.expectRevert('invalid spoke configurator');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: address(0),
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE,
      selectors: selectors
    });
  }

  function test_grantSpokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    _assertHasRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE);
    _assertHasRole(Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE);
  }

  function test_setupSpokeConfiguratorRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    _assertSelectorsMapTo(
      wrapper.getSpokeConfiguratorDomainBaseRoleSelectors(),
      Roles.SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE
    );
    _assertSelectorsMapTo(
      wrapper.getSpokeConfiguratorRiskManagementRoleSelectors(),
      Roles.SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE
    );
    _assertSelectorsMapTo(
      wrapper.getSpokeConfiguratorEmergencyRoleSelectors(),
      Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE
    );
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _wrapper, 0);
  }

  function _assertHasRole(uint64 role) internal view {
    (bool hasRole, ) = IAccessManager(accessManager).hasRole(role, admin);
    assertTrue(hasRole);
  }

  function _assertSelectorsMapTo(bytes4[] memory selectors, uint64 role) internal view {
    for (uint256 i; i < selectors.length; i++) {
      assertEq(
        IAccessManager(accessManager).getTargetFunctionRole(spokeConfigurator, selectors[i]),
        role
      );
    }
  }

  function test_getSpokeConfiguratorDomainBaseRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDomainBaseRoleSelectors();
    assertEq(selectors.length, 7);
    assertEq(selectors[0], ISpokeConfigurator.updateReservePriceSource.selector);
    assertEq(selectors[1], ISpokeConfigurator.addReserve.selector);
    assertEq(selectors[2], ISpokeConfigurator.updatePaused.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateFrozen.selector);
    assertEq(selectors[4], ISpokeConfigurator.updateBorrowable.selector);
    assertEq(selectors[5], ISpokeConfigurator.updateReceiveSharesEnabled.selector);
    assertEq(selectors[6], ISpokeConfigurator.updatePositionManager.selector);
  }

  function test_getSpokeConfiguratorRiskManagementRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorRiskManagementRoleSelectors();
    assertEq(selectors.length, 13);
    assertEq(selectors[0], ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateHealthFactorForMaxBonus.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateLiquidationBonusFactor.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateLiquidationConfig.selector);
    assertEq(selectors[4], ISpokeConfigurator.updateCollateralRisk.selector);
    assertEq(selectors[5], ISpokeConfigurator.addCollateralFactor.selector);
    assertEq(selectors[6], ISpokeConfigurator.updateCollateralFactor.selector);
    assertEq(selectors[7], ISpokeConfigurator.addMaxLiquidationBonus.selector);
    assertEq(selectors[8], ISpokeConfigurator.updateMaxLiquidationBonus.selector);
    assertEq(selectors[9], ISpokeConfigurator.addLiquidationFee.selector);
    assertEq(selectors[10], ISpokeConfigurator.updateLiquidationFee.selector);
    assertEq(selectors[11], ISpokeConfigurator.addDynamicReserveConfig.selector);
    assertEq(selectors[12], ISpokeConfigurator.updateDynamicReserveConfig.selector);
  }

  function test_getSpokeConfiguratorEmergencyRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorEmergencyRoleSelectors();
    assertEq(selectors.length, 4);
    assertEq(selectors[0], ISpokeConfigurator.pauseReserve.selector);
    assertEq(selectors[1], ISpokeConfigurator.pauseAllReserves.selector);
    assertEq(selectors[2], ISpokeConfigurator.freezeReserve.selector);
    assertEq(selectors[3], ISpokeConfigurator.freezeAllReserves.selector);
  }

  function test_canCall_spokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    _assertCanCall(spokeConfigurator, wrapper.getSpokeConfiguratorDomainBaseRoleSelectors());
    _assertCanCall(spokeConfigurator, wrapper.getSpokeConfiguratorRiskManagementRoleSelectors());
    _assertCanCall(spokeConfigurator, wrapper.getSpokeConfiguratorEmergencyRoleSelectors());
  }
}
