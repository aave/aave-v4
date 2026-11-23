// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';

contract AaveV4HubSpokeFactoryRolesProcedureTest is ProceduresBase {
  AaveV4HubSpokeFactoryRolesProcedureWrapper public wrapper;
  address public hubSpokeFactory = makeAddr('hubSpokeFactory');

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4HubSpokeFactoryRolesProcedureWrapper();
  }

  function test_grantHubSpokeFactoryRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.grantHubSpokeFactoryRole({
      accessManager: address(0),
      role: Roles.HUB_SPOKE_FACTORY_DOMAIN_ADMIN_ROLE,
      admin: admin
    });

    vm.expectRevert('invalid admin');
    wrapper.grantHubSpokeFactoryRole({
      accessManager: accessManager,
      role: Roles.HUB_SPOKE_FACTORY_DOMAIN_ADMIN_ROLE,
      admin: address(0)
    });
  }

  function test_setupHubSpokeFactoryRoles_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.setupHubSpokeFactoryRoles({
      accessManager: address(0),
      hubSpokeFactory: hubSpokeFactory
    });

    vm.expectRevert('invalid hub spoke factory');
    wrapper.setupHubSpokeFactoryRoles({accessManager: accessManager, hubSpokeFactory: address(0)});
  }

  function test_setupHubSpokeFactoryRole_reverts() public {
    bytes4[] memory selectors = wrapper.getHubSpokeFactoryDomainAdminRoleSelectors();

    vm.expectRevert('invalid access manager');
    wrapper.setupHubSpokeFactoryRole({
      accessManager: address(0),
      hubSpokeFactory: hubSpokeFactory,
      role: Roles.HUB_SPOKE_FACTORY_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });

    vm.expectRevert('invalid hub spoke factory');
    wrapper.setupHubSpokeFactoryRole({
      accessManager: accessManager,
      hubSpokeFactory: address(0),
      role: Roles.HUB_SPOKE_FACTORY_DOMAIN_ADMIN_ROLE,
      selectors: selectors
    });
  }

  function test_grantHubSpokeFactoryAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubSpokeFactoryAllRoles({accessManager: accessManager, admin: admin});

    (bool hasRole, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_SPOKE_FACTORY_DOMAIN_ADMIN_ROLE,
      admin
    );
    assertTrue(hasRole);
  }

  function test_setupHubSpokeFactoryRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupHubSpokeFactoryRoles({
      accessManager: accessManager,
      hubSpokeFactory: hubSpokeFactory
    });

    bytes4[] memory selectors = wrapper.getHubSpokeFactoryDomainAdminRoleSelectors();
    for (uint256 i; i < selectors.length; i++) {
      assertEq(
        IAccessManager(accessManager).getTargetFunctionRole(hubSpokeFactory, selectors[i]),
        Roles.HUB_SPOKE_FACTORY_DOMAIN_ADMIN_ROLE
      );
    }
  }

  function test_getHubSpokeFactoryDomainAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubSpokeFactoryDomainAdminRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubSpokeFactory.setImplementation.selector);
  }

  function test_canCall_hubSpokeFactoryAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubSpokeFactoryAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupHubSpokeFactoryRoles({
      accessManager: accessManager,
      hubSpokeFactory: hubSpokeFactory
    });

    _assertCanCall(hubSpokeFactory, wrapper.getHubSpokeFactoryDomainAdminRoleSelectors());
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _wrapper, 0);
  }
}
