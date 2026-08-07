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
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      admin: admin
    });

    vm.expectRevert('invalid admin');
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
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
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDomainAdminRoleSelectors();

    vm.expectRevert('invalid access manager');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });

    vm.expectRevert('invalid spoke configurator');
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

    uint64[] memory roles = _allRoles();
    for (uint256 i; i < roles.length; i++) {
      (bool hasRole, ) = IAccessManager(accessManager).hasRole(roles[i], admin);
      assertTrue(hasRole, vm.toString(roles[i]));
    }
  }

  function test_setupSpokeConfiguratorRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    uint64[] memory roles = _allRoles();
    for (uint256 i; i < roles.length; i++) {
      bytes4[] memory selectors = _selectorsOf(roles[i]);
      for (uint256 j; j < selectors.length; j++) {
        assertEq(
          IAccessManager(accessManager).getTargetFunctionRole(spokeConfigurator, selectors[j]),
          roles[i]
        );
      }
    }
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _wrapper, 0);
  }

  function test_getSpokeConfiguratorDomainAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDomainAdminRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], ISpokeConfigurator.updateReservePriceSource.selector);
    assertEq(selectors[1], ISpokeConfigurator.updatePositionManager.selector);
  }

  function test_getSpokeConfiguratorPauseRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorPauseRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], ISpokeConfigurator.updatePaused.selector);
  }

  function test_getSpokeConfiguratorFreezeRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorFreezeRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], ISpokeConfigurator.updateFrozen.selector);
  }

  function test_getSpokeConfiguratorListingRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorListingRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], ISpokeConfigurator.addReserve.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateBorrowable.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateReceiveSharesEnabled.selector);
  }

  function test_getSpokeConfiguratorEmergencyRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorEmergencyRoleSelectors();
    assertEq(selectors.length, 4);
    assertEq(selectors[0], ISpokeConfigurator.pauseReserve.selector);
    assertEq(selectors[1], ISpokeConfigurator.pauseAllReserves.selector);
    assertEq(selectors[2], ISpokeConfigurator.freezeReserve.selector);
    assertEq(selectors[3], ISpokeConfigurator.freezeAllReserves.selector);
  }

  function test_getSpokeConfiguratorRiskManagementRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorRiskManagementRoleSelectors();
    assertEq(selectors.length, 13);
    assertEq(selectors[0], ISpokeConfigurator.updateCollateralRisk.selector);
    assertEq(selectors[1], ISpokeConfigurator.addCollateralFactor.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateCollateralFactor.selector);
    assertEq(selectors[3], ISpokeConfigurator.addMaxLiquidationBonus.selector);
    assertEq(selectors[4], ISpokeConfigurator.updateMaxLiquidationBonus.selector);
    assertEq(selectors[5], ISpokeConfigurator.addLiquidationFee.selector);
    assertEq(selectors[6], ISpokeConfigurator.updateLiquidationFee.selector);
    assertEq(selectors[7], ISpokeConfigurator.addDynamicReserveConfig.selector);
    assertEq(selectors[8], ISpokeConfigurator.updateDynamicReserveConfig.selector);
    assertEq(selectors[9], ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector);
    assertEq(selectors[10], ISpokeConfigurator.updateHealthFactorForMaxBonus.selector);
    assertEq(selectors[11], ISpokeConfigurator.updateLiquidationBonusFactor.selector);
    assertEq(selectors[12], ISpokeConfigurator.updateLiquidationConfig.selector);
  }

  /// @dev The five granular roles plus the residual domain admin must partition the
  /// SpokeConfigurator selectors: no selector is left unassigned and none is shared.
  function test_rolesPartitionAllSelectors() public view {
    uint64[] memory roles = _allRoles();
    bytes4[] memory seen = new bytes4[](24);
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

    assertEq(count, 24, 'selector count diverges from the SpokeConfigurator surface');
  }

  function test_canCall_spokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    uint64[] memory roles = _allRoles();
    for (uint256 i; i < roles.length; i++) {
      _assertCanCall(spokeConfigurator, _selectorsOf(roles[i]));
    }
  }

  /// @dev A holder of a single granular role can only call that role's selectors.
  function test_canCall_spokeConfiguratorEmergencyRoleOnly() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE,
      admin: admin
    });
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    _assertCanCall(spokeConfigurator, wrapper.getSpokeConfiguratorEmergencyRoleSelectors());
    _assertCannotCall(spokeConfigurator, wrapper.getSpokeConfiguratorPauseRoleSelectors());
    _assertCannotCall(spokeConfigurator, wrapper.getSpokeConfiguratorFreezeRoleSelectors());
    _assertCannotCall(spokeConfigurator, wrapper.getSpokeConfiguratorRiskManagementRoleSelectors());
  }

  function _allRoles() internal pure returns (uint64[] memory) {
    uint64[] memory roles = new uint64[](6);
    roles[0] = Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE;
    roles[1] = Roles.SPOKE_CONFIGURATOR_PAUSE_ROLE;
    roles[2] = Roles.SPOKE_CONFIGURATOR_FREEZE_ROLE;
    roles[3] = Roles.SPOKE_CONFIGURATOR_LISTING_ROLE;
    roles[4] = Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE;
    roles[5] = Roles.SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE;
    return roles;
  }

  function _selectorsOf(uint64 role) internal view returns (bytes4[] memory) {
    if (role == Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE) {
      return wrapper.getSpokeConfiguratorDomainAdminRoleSelectors();
    }
    if (role == Roles.SPOKE_CONFIGURATOR_PAUSE_ROLE) {
      return wrapper.getSpokeConfiguratorPauseRoleSelectors();
    }
    if (role == Roles.SPOKE_CONFIGURATOR_FREEZE_ROLE) {
      return wrapper.getSpokeConfiguratorFreezeRoleSelectors();
    }
    if (role == Roles.SPOKE_CONFIGURATOR_LISTING_ROLE) {
      return wrapper.getSpokeConfiguratorListingRoleSelectors();
    }
    if (role == Roles.SPOKE_CONFIGURATOR_EMERGENCY_ROLE) {
      return wrapper.getSpokeConfiguratorEmergencyRoleSelectors();
    }
    return wrapper.getSpokeConfiguratorRiskManagementRoleSelectors();
  }
}
