// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeRolesProcedureTest is ProceduresBase {
  AaveV4SpokeRolesProcedureWrapper public aaveV4SpokeRolesProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4SpokeRolesProcedureWrapper = new AaveV4SpokeRolesProcedureWrapper();
  }

  function test_grantSpokeAllRoles_reverts() public {
    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.grantSpokeAllRoles({accessManager: address(0), admin: admin});

    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.grantSpokeAllRoles({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_grantSpokeRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.grantSpokeRole({
      accessManager: address(0),
      role: Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      admin: admin
    });

    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      admin: address(0)
    });
  }

  function test_setupSpokeRoles_reverts() public {
    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.setupSpokeRoles({accessManager: address(0), spoke: spoke});

    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.setupSpokeRoles({
      accessManager: accessManager,
      spoke: address(0)
    });
  }

  function test_setupSpokePositionUpdaterRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.setupSpokePositionUpdaterRole({
      accessManager: address(0),
      spoke: spoke
    });

    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.setupSpokePositionUpdaterRole({
      accessManager: accessManager,
      spoke: address(0)
    });
  }

  function test_setupSpokeConfiguratorRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.setupSpokeConfiguratorRole({
      accessManager: address(0),
      spoke: spoke
    });

    vm.expectRevert('zero address');
    aaveV4SpokeRolesProcedureWrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spoke: address(0)
    });
  }

  function test_grantSpokeAllRoles() public {
    _grantAdminToWrapper(address(aaveV4SpokeRolesProcedureWrapper));
    aaveV4SpokeRolesProcedureWrapper.grantSpokeAllRoles({
      accessManager: accessManager,
      admin: admin
    });

    (bool hasPositionUpdater, ) = IAccessManager(accessManager).hasRole(
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      admin
    );
    assertTrue(hasPositionUpdater);

    (bool hasConfigurator, ) = IAccessManager(accessManager).hasRole(
      Roles.SPOKE_CONFIGURATOR_ROLE,
      admin
    );
    assertTrue(hasConfigurator);
  }

  function test_setupSpokeRoles() public {
    _grantAdminToWrapper(address(aaveV4SpokeRolesProcedureWrapper));
    aaveV4SpokeRolesProcedureWrapper.setupSpokeRoles({accessManager: accessManager, spoke: spoke});

    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spoke,
        ISpoke.updateUserDynamicConfig.selector
      ),
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(spoke, ISpoke.addReserve.selector),
      Roles.SPOKE_CONFIGURATOR_ROLE
    );
  }

  function _grantAdminToWrapper(address wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, wrapper, 0);
  }

  function test_getSpokePositionUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = aaveV4SpokeRolesProcedureWrapper
      .getSpokePositionUpdaterRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], ISpoke.updateUserDynamicConfig.selector);
    assertEq(selectors[1], ISpoke.updateUserRiskPremium.selector);
  }

  function test_getSpokeConfiguratorRoleSelectors() public view {
    bytes4[] memory selectors = aaveV4SpokeRolesProcedureWrapper
      .getSpokeConfiguratorRoleSelectors();
    assertEq(selectors.length, 7);
    assertEq(selectors[0], ISpoke.updateLiquidationConfig.selector);
    assertEq(selectors[1], ISpoke.addReserve.selector);
    assertEq(selectors[2], ISpoke.updateReserveConfig.selector);
    assertEq(selectors[3], ISpoke.updateDynamicReserveConfig.selector);
    assertEq(selectors[4], ISpoke.addDynamicReserveConfig.selector);
    assertEq(selectors[5], ISpoke.updatePositionManager.selector);
    assertEq(selectors[6], ISpoke.updateReservePriceSource.selector);
  }

  function test_canCall_spokePositionUpdaterRole() public {
    _grantAdminToWrapper(address(aaveV4SpokeRolesProcedureWrapper));
    aaveV4SpokeRolesProcedureWrapper.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      admin: admin
    });
    aaveV4SpokeRolesProcedureWrapper.setupSpokePositionUpdaterRole({
      accessManager: accessManager,
      spoke: spoke
    });

    bytes4[] memory selectors = aaveV4SpokeRolesProcedureWrapper
      .getSpokePositionUpdaterRoleSelectors();
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spoke,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(unauthorized, spoke, selectors[i]);
      assertFalse(allowed);
    }
  }

  function test_canCall_spokeConfiguratorRole() public {
    _grantAdminToWrapper(address(aaveV4SpokeRolesProcedureWrapper));
    aaveV4SpokeRolesProcedureWrapper.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: admin
    });
    aaveV4SpokeRolesProcedureWrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spoke: spoke
    });

    bytes4[] memory selectors = aaveV4SpokeRolesProcedureWrapper
      .getSpokeConfiguratorRoleSelectors();
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spoke,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(unauthorized, spoke, selectors[i]);
      assertFalse(allowed);
    }
  }

  function test_canCall_spokeAllRoles() public {
    _grantAdminToWrapper(address(aaveV4SpokeRolesProcedureWrapper));
    aaveV4SpokeRolesProcedureWrapper.grantSpokeAllRoles({
      accessManager: accessManager,
      admin: admin
    });
    aaveV4SpokeRolesProcedureWrapper.setupSpokeRoles({accessManager: accessManager, spoke: spoke});

    bytes4[] memory positionUpdaterSelectors = aaveV4SpokeRolesProcedureWrapper
      .getSpokePositionUpdaterRoleSelectors();
    for (uint256 i = 0; i < positionUpdaterSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spoke,
        positionUpdaterSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory configuratorSelectors = aaveV4SpokeRolesProcedureWrapper
      .getSpokeConfiguratorRoleSelectors();
    for (uint256 i = 0; i < configuratorSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spoke,
        configuratorSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }
  }
}
