// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
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
    vm.expectRevert('zero address');
    wrapper.grantSpokeConfiguratorRole({
      accessManager: address(0),
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      admin: admin
    });

    vm.expectRevert('zero address');
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      admin: address(0)
    });
  }

  function test_setupSpokeConfiguratorRoles_reverts() public {
    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator
    });

    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: address(0)
    });
  }

  function test_setupSpokeConfiguratorRole_reverts() public {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDomainAdminRoleSelectors();

    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });

    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: address(0),
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });
  }

  function test_grantSpokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    (bool hasRole, ) = IAccessManager(accessManager).hasRole(
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      admin
    );
    assertTrue(hasRole);
  }

  function test_setupSpokeConfiguratorRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDomainAdminRoleSelectors();
    for (uint256 i; i < selectors.length; i++) {
      assertEq(
        IAccessManager(accessManager).getTargetFunctionRole(spokeConfigurator, selectors[i]),
        Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE
      );
    }
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _wrapper, 0);
  }

  function test_getSpokeConfiguratorDomainAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDomainAdminRoleSelectors();
    assertEq(selectors.length, 24);
    assertEq(selectors[0], ISpokeConfigurator.updateReservePriceSource.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateHealthFactorForMaxBonus.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateLiquidationBonusFactor.selector);
    assertEq(selectors[4], ISpokeConfigurator.updateLiquidationConfig.selector);
    assertEq(selectors[5], ISpokeConfigurator.addReserve.selector);
    assertEq(selectors[6], ISpokeConfigurator.updatePaused.selector);
    assertEq(selectors[7], ISpokeConfigurator.updateFrozen.selector);
    assertEq(selectors[8], ISpokeConfigurator.updateBorrowable.selector);
    assertEq(selectors[9], ISpokeConfigurator.updateReceiveSharesEnabled.selector);
    assertEq(selectors[10], ISpokeConfigurator.updateCollateralRisk.selector);
    assertEq(selectors[11], ISpokeConfigurator.addCollateralFactor.selector);
    assertEq(selectors[12], ISpokeConfigurator.updateCollateralFactor.selector);
    assertEq(selectors[13], ISpokeConfigurator.addMaxLiquidationBonus.selector);
    assertEq(selectors[14], ISpokeConfigurator.updateMaxLiquidationBonus.selector);
    assertEq(selectors[15], ISpokeConfigurator.addLiquidationFee.selector);
    assertEq(selectors[16], ISpokeConfigurator.updateLiquidationFee.selector);
    assertEq(selectors[17], ISpokeConfigurator.addDynamicReserveConfig.selector);
    assertEq(selectors[18], ISpokeConfigurator.updateDynamicReserveConfig.selector);
    assertEq(selectors[19], ISpokeConfigurator.pauseAllReserves.selector);
    assertEq(selectors[20], ISpokeConfigurator.freezeAllReserves.selector);
    assertEq(selectors[21], ISpokeConfigurator.pauseReserve.selector);
    assertEq(selectors[22], ISpokeConfigurator.freezeReserve.selector);
    assertEq(selectors[23], ISpokeConfigurator.updatePositionManager.selector);
  }

  function test_canCall_spokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    _assertCanCall(spokeConfigurator, wrapper.getSpokeConfiguratorDomainAdminRoleSelectors());
  }
}
