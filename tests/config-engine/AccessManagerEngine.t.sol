// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';

contract AccessManagerEngineTest is BaseConfigEngineTest {
  // Default Roles :
  uint64 constant DEFAULT_ADMIN_ROLE = 0;
  uint64 constant PUBLIC_ROLE = type(uint64).max;

  uint64 constant TEST_ROLE_ID = 5;
  uint64 constant TEST_ROLE_ID_2 = 6;
  uint64 constant TEST_ADMIN_ROLE_ID = 1;
  uint64 constant TEST_GUARDIAN_ROLE_ID = 2;
  uint32 constant TEST_GRANT_DELAY = 3600;
  uint32 constant TEST_EXEC_DELAY_SHORT = 100;
  uint32 constant TEST_EXEC_DELAY_LONG = 200;
  uint32 constant TEST_ADMIN_DELAY = 7200;

  bytes4 constant TEST_SELECTOR_1 = bytes4(0xaabbccdd);
  bytes4 constant TEST_SELECTOR_2 = bytes4(0x11223344);

  function _assertRoleConfig(
    uint64 roleId,
    uint64 expectedAdmin,
    uint64 expectedGuardian
  ) internal view {
    assertEq(accessManager.getRoleAdmin(roleId), expectedAdmin);
    assertEq(accessManager.getRoleGuardian(roleId), expectedGuardian);
  }

  function test_executeRoleMemberships_grant() public {
    vm.expectCall(
      address(accessManager),
      abi.encodeCall(IAccessManager.grantRole, (TEST_ROLE_ID, ACCOUNT, TEST_EXEC_DELAY_SHORT))
    );

    vm.expectEmit(true, true, false, false, address(accessManager));
    emit IAccessManager.RoleGranted(TEST_ROLE_ID, ACCOUNT, TEST_EXEC_DELAY_SHORT, 0, true);

    engine.executeRoleMemberships(
      _toRoleMembershipArray(
        IAaveV4ConfigEngine.RoleMembership({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          account: ACCOUNT,
          granted: true,
          executionDelay: TEST_EXEC_DELAY_SHORT
        })
      )
    );

    (bool isMember, uint32 delay) = accessManager.hasRole(TEST_ROLE_ID, ACCOUNT);
    assertTrue(isMember);
    assertEq(delay, TEST_EXEC_DELAY_SHORT);
  }

  function test_fuzz_executeRoleMemberships_grant(
    uint64 roleId,
    address account,
    uint32 executionDelay
  ) public {
    vm.assume(roleId != DEFAULT_ADMIN_ROLE); // DEFAULT_ADMIN_ROLE is locked
    vm.assume(roleId != PUBLIC_ROLE); // PUBLIC_ROLE is locked

    engine.executeRoleMemberships(
      _toRoleMembershipArray(
        IAaveV4ConfigEngine.RoleMembership({
          authority: address(accessManager),
          roleId: roleId,
          account: account,
          granted: true,
          executionDelay: executionDelay
        })
      )
    );

    (bool isMember, uint32 delay) = accessManager.hasRole(roleId, account);
    assertTrue(isMember);
    assertEq(delay, executionDelay);
  }

  function test_executeRoleMemberships_revoke() public {
    engine.executeRoleMemberships(
      _toRoleMembershipArray(
        IAaveV4ConfigEngine.RoleMembership({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          account: ACCOUNT,
          granted: true,
          executionDelay: 0
        })
      )
    );

    vm.expectCall(
      address(accessManager),
      abi.encodeCall(IAccessManager.revokeRole, (TEST_ROLE_ID, ACCOUNT))
    );

    vm.expectEmit(address(accessManager));
    emit IAccessManager.RoleRevoked(TEST_ROLE_ID, ACCOUNT);

    engine.executeRoleMemberships(
      _toRoleMembershipArray(
        IAaveV4ConfigEngine.RoleMembership({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          account: ACCOUNT,
          granted: false,
          executionDelay: 0
        })
      )
    );

    (bool isMember, ) = accessManager.hasRole(TEST_ROLE_ID, ACCOUNT);
    assertFalse(isMember);
  }

  function test_fuzz_executeRoleMemberships_revoke(uint64 roleId, address account) public {
    vm.assume(roleId != DEFAULT_ADMIN_ROLE); // DEFAULT_ADMIN_ROLE is locked
    vm.assume(roleId != PUBLIC_ROLE); // PUBLIC_ROLE is locked

    engine.executeRoleMemberships(
      _toRoleMembershipArray(
        IAaveV4ConfigEngine.RoleMembership({
          authority: address(accessManager),
          roleId: roleId,
          account: account,
          granted: true,
          executionDelay: 0
        })
      )
    );

    engine.executeRoleMemberships(
      _toRoleMembershipArray(
        IAaveV4ConfigEngine.RoleMembership({
          authority: address(accessManager),
          roleId: roleId,
          account: account,
          granted: false,
          executionDelay: 0
        })
      )
    );

    (bool isMember, ) = accessManager.hasRole(roleId, account);
    assertFalse(isMember);
  }

  function test_executeRoleMemberships_grant_revert() public {
    vm.prank(ADMIN);
    accessManager.revokeRole(DEFAULT_ADMIN_ROLE, address(engine));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(engine),
        DEFAULT_ADMIN_ROLE
      )
    );
    engine.executeRoleMemberships(
      _toRoleMembershipArray(
        IAaveV4ConfigEngine.RoleMembership({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          account: ACCOUNT,
          granted: true,
          executionDelay: TEST_EXEC_DELAY_SHORT
        })
      )
    );
  }

  function test_executeRoleMemberships_revoke_revert() public {
    vm.prank(ADMIN);
    accessManager.revokeRole(DEFAULT_ADMIN_ROLE, address(engine));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(engine),
        DEFAULT_ADMIN_ROLE
      )
    );
    engine.executeRoleMemberships(
      _toRoleMembershipArray(
        IAaveV4ConfigEngine.RoleMembership({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          account: ACCOUNT,
          granted: false,
          executionDelay: 0
        })
      )
    );
  }

  function test_executeRoleUpdates_allFields() public {
    vm.expectEmit(address(accessManager));
    emit IAccessManager.RoleAdminChanged(TEST_ROLE_ID, TEST_ADMIN_ROLE_ID);

    vm.expectEmit(address(accessManager));
    emit IAccessManager.RoleGuardianChanged(TEST_ROLE_ID, TEST_GUARDIAN_ROLE_ID);

    vm.expectEmit(true, false, false, false, address(accessManager));
    emit IAccessManager.RoleGrantDelayChanged(TEST_ROLE_ID, TEST_GRANT_DELAY, 0);

    vm.expectEmit(true, false, false, false, address(accessManager));
    emit IAccessManager.RoleLabel(TEST_ROLE_ID, 'FEE_UPDATER');

    engine.executeRoleUpdates(
      _toRoleUpdateArray(
        IAaveV4ConfigEngine.RoleUpdate({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          admin: TEST_ADMIN_ROLE_ID,
          guardian: TEST_GUARDIAN_ROLE_ID,
          grantDelay: TEST_GRANT_DELAY,
          label: 'FEE_UPDATER',
          labelUpdate: false
        })
      )
    );

    assertEq(accessManager.getRoleAdmin(TEST_ROLE_ID), TEST_ADMIN_ROLE_ID);
    assertEq(accessManager.getRoleGuardian(TEST_ROLE_ID), TEST_GUARDIAN_ROLE_ID);
    vm.warp(block.timestamp + 5 days);
    assertEq(accessManager.getRoleGrantDelay(TEST_ROLE_ID), TEST_GRANT_DELAY);
  }

  function test_executeRoleUpdates_adminOnly() public {
    uint64 guardianBefore = accessManager.getRoleGuardian(TEST_ROLE_ID);

    vm.expectCall(
      address(accessManager),
      abi.encodeCall(IAccessManager.setRoleAdmin, (TEST_ROLE_ID, TEST_ADMIN_ROLE_ID))
    );
    engine.executeRoleUpdates(
      _toRoleUpdateArray(
        IAaveV4ConfigEngine.RoleUpdate({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          admin: TEST_ADMIN_ROLE_ID,
          guardian: EngineFlags.KEEP_CURRENT_UINT64,
          grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
          label: '',
          labelUpdate: false
        })
      )
    );

    assertEq(accessManager.getRoleAdmin(TEST_ROLE_ID), TEST_ADMIN_ROLE_ID);
    assertEq(accessManager.getRoleGuardian(TEST_ROLE_ID), guardianBefore);
  }

  function test_executeRoleUpdates_guardianOnly() public {
    uint64 adminBefore = accessManager.getRoleAdmin(TEST_ROLE_ID);

    vm.expectCall(
      address(accessManager),
      abi.encodeCall(IAccessManager.setRoleGuardian, (TEST_ROLE_ID, TEST_GUARDIAN_ROLE_ID))
    );
    engine.executeRoleUpdates(
      _toRoleUpdateArray(
        IAaveV4ConfigEngine.RoleUpdate({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          admin: EngineFlags.KEEP_CURRENT_UINT64,
          guardian: TEST_GUARDIAN_ROLE_ID,
          grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
          label: '',
          labelUpdate: false
        })
      )
    );

    assertEq(accessManager.getRoleGuardian(TEST_ROLE_ID), TEST_GUARDIAN_ROLE_ID);
    assertEq(accessManager.getRoleAdmin(TEST_ROLE_ID), adminBefore);
  }

  function test_executeRoleUpdates_grantDelayOnly() public {
    uint64 adminBefore = accessManager.getRoleAdmin(TEST_ROLE_ID);
    uint64 guardianBefore = accessManager.getRoleGuardian(TEST_ROLE_ID);

    vm.expectCall(
      address(accessManager),
      abi.encodeCall(IAccessManager.setGrantDelay, (TEST_ROLE_ID, TEST_GRANT_DELAY))
    );
    engine.executeRoleUpdates(
      _toRoleUpdateArray(
        IAaveV4ConfigEngine.RoleUpdate({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          admin: EngineFlags.KEEP_CURRENT_UINT64,
          guardian: EngineFlags.KEEP_CURRENT_UINT64,
          grantDelay: TEST_GRANT_DELAY,
          label: '',
          labelUpdate: false
        })
      )
    );

    vm.warp(block.timestamp + 5 days);
    assertEq(accessManager.getRoleGrantDelay(TEST_ROLE_ID), TEST_GRANT_DELAY);
    _assertRoleConfig(TEST_ROLE_ID, adminBefore, guardianBefore);
  }

  function test_executeRoleUpdates_labelOnly() public {
    vm.expectEmit(address(accessManager));
    emit IAccessManager.RoleLabel(TEST_ROLE_ID, 'FEE_UPDATER');

    engine.executeRoleUpdates(
      _toRoleUpdateArray(
        IAaveV4ConfigEngine.RoleUpdate({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          admin: EngineFlags.KEEP_CURRENT_UINT64,
          guardian: EngineFlags.KEEP_CURRENT_UINT64,
          grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
          label: 'FEE_UPDATER',
          labelUpdate: false
        })
      )
    );
  }

  function test_executeRoleUpdates_relabel() public {
    engine.executeRoleUpdates(_toRoleUpdateArray(_labelOnlyUpdate('FEE_UPDATER', false)));

    engine.executeRoleUpdates(_toRoleUpdateArray(_labelOnlyUpdate('RISK_UPDATER', true)));

    IAccessManagerEnumerable enumerable = IAccessManagerEnumerable(address(accessManager));
    assertEq(enumerable.getLabelOfRole(TEST_ROLE_ID), 'RISK_UPDATER');
    assertTrue(enumerable.isLabelAssigned('RISK_UPDATER'));
    assertFalse(enumerable.isLabelAssigned('FEE_UPDATER'));
  }

  function test_executeRoleUpdates_relabel_sameLabel() public {
    engine.executeRoleUpdates(_toRoleUpdateArray(_labelOnlyUpdate('FEE_UPDATER', false)));

    engine.executeRoleUpdates(_toRoleUpdateArray(_labelOnlyUpdate('FEE_UPDATER', true)));

    IAccessManagerEnumerable enumerable = IAccessManagerEnumerable(address(accessManager));
    assertEq(enumerable.getLabelOfRole(TEST_ROLE_ID), 'FEE_UPDATER');
    assertTrue(enumerable.isLabelAssigned('FEE_UPDATER'));
  }

  function test_executeRoleUpdates_relabel_withoutFlag_reverts() public {
    engine.executeRoleUpdates(_toRoleUpdateArray(_labelOnlyUpdate('FEE_UPDATER', false)));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerRoleAlreadyLabeled.selector,
        TEST_ROLE_ID
      )
    );
    engine.executeRoleUpdates(_toRoleUpdateArray(_labelOnlyUpdate('RISK_UPDATER', false)));
  }

  function test_executeRoleUpdates_labelUpdate_onUnlabeledRole_reverts() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManagerEnumerable.AccessManagerUnlabeledRole.selector,
        TEST_ROLE_ID
      )
    );
    engine.executeRoleUpdates(_toRoleUpdateArray(_labelOnlyUpdate('FEE_UPDATER', true)));
  }

  function _labelOnlyUpdate(
    string memory label,
    bool labelUpdate
  ) internal view returns (IAaveV4ConfigEngine.RoleUpdate memory) {
    return
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(accessManager),
        roleId: TEST_ROLE_ID,
        admin: EngineFlags.KEEP_CURRENT_UINT64,
        guardian: EngineFlags.KEEP_CURRENT_UINT64,
        grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
        label: label,
        labelUpdate: labelUpdate
      });
  }

  function test_executeRoleUpdates_noneChanged() public {
    vm.recordLogs();
    engine.executeRoleUpdates(
      _toRoleUpdateArray(
        IAaveV4ConfigEngine.RoleUpdate({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          admin: EngineFlags.KEEP_CURRENT_UINT64,
          guardian: EngineFlags.KEEP_CURRENT_UINT64,
          grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
          label: '',
          labelUpdate: false
        })
      )
    );
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_fuzz_executeRoleUpdates_allFields(
    uint64 roleId,
    uint64 admin,
    uint64 guardian,
    uint32 grantDelay
  ) public {
    vm.assume(roleId != 0); // DEFAULT_ADMIN_ROLE is locked
    vm.assume(roleId != type(uint64).max); // PUBLIC_ROLE is locked
    vm.assume(admin != EngineFlags.KEEP_CURRENT_UINT64);
    vm.assume(guardian != EngineFlags.KEEP_CURRENT_UINT64);
    vm.assume(grantDelay != EngineFlags.KEEP_CURRENT_UINT32);

    engine.executeRoleUpdates(
      _toRoleUpdateArray(
        IAaveV4ConfigEngine.RoleUpdate({
          authority: address(accessManager),
          roleId: roleId,
          admin: admin,
          guardian: guardian,
          grantDelay: grantDelay,
          label: 'FUZZ_LABEL',
          labelUpdate: IAccessManagerEnumerable(address(accessManager)).isRoleLabeled(roleId)
        })
      )
    );

    assertEq(accessManager.getRoleAdmin(roleId), admin);
    assertEq(accessManager.getRoleGuardian(roleId), guardian);
    vm.warp(block.timestamp + 5 days);
    assertEq(accessManager.getRoleGrantDelay(roleId), grantDelay);
  }

  function test_executeRoleUpdates_revert_admin() public {
    vm.prank(ADMIN);
    accessManager.revokeRole(DEFAULT_ADMIN_ROLE, address(engine));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(engine),
        DEFAULT_ADMIN_ROLE
      )
    );
    engine.executeRoleUpdates(
      _toRoleUpdateArray(
        IAaveV4ConfigEngine.RoleUpdate({
          authority: address(accessManager),
          roleId: TEST_ROLE_ID,
          admin: TEST_ADMIN_ROLE_ID,
          guardian: EngineFlags.KEEP_CURRENT_UINT64,
          grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
          label: '',
          labelUpdate: false
        })
      )
    );
  }

  function test_executeTargetFunctionRoleUpdates() public {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = TEST_SELECTOR_1;
    selectors[1] = TEST_SELECTOR_2;

    vm.expectCall(
      address(accessManager),
      abi.encodeCall(IAccessManager.setTargetFunctionRole, (TARGET, selectors, TEST_ROLE_ID))
    );

    vm.expectEmit(address(accessManager));
    emit IAccessManager.TargetFunctionRoleUpdated(TARGET, TEST_SELECTOR_1, TEST_ROLE_ID);

    vm.expectEmit(address(accessManager));
    emit IAccessManager.TargetFunctionRoleUpdated(TARGET, TEST_SELECTOR_2, TEST_ROLE_ID);

    engine.executeTargetFunctionRoleUpdates(
      _toTargetFunctionRoleUpdateArray(
        IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
          authority: address(accessManager),
          target: TARGET,
          selectors: selectors,
          roleId: TEST_ROLE_ID
        })
      )
    );

    assertEq(accessManager.getTargetFunctionRole(TARGET, selectors[0]), TEST_ROLE_ID);
    assertEq(accessManager.getTargetFunctionRole(TARGET, selectors[1]), TEST_ROLE_ID);
  }

  function test_fuzz_executeTargetFunctionRoleUpdates(
    address target,
    bytes4 selector1,
    uint64 roleId
  ) public {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = selector1;

    engine.executeTargetFunctionRoleUpdates(
      _toTargetFunctionRoleUpdateArray(
        IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
          authority: address(accessManager),
          target: target,
          selectors: selectors,
          roleId: roleId
        })
      )
    );

    assertEq(accessManager.getTargetFunctionRole(target, selector1), roleId);
  }

  function test_executeTargetFunctionRoleUpdates_revert() public {
    vm.prank(ADMIN);
    accessManager.revokeRole(DEFAULT_ADMIN_ROLE, address(engine));

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = TEST_SELECTOR_1;

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(engine),
        DEFAULT_ADMIN_ROLE
      )
    );
    engine.executeTargetFunctionRoleUpdates(
      _toTargetFunctionRoleUpdateArray(
        IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
          authority: address(accessManager),
          target: TARGET,
          selectors: selectors,
          roleId: TEST_ROLE_ID
        })
      )
    );
  }

  function test_executeTargetAdminDelayUpdates() public {
    vm.expectCall(
      address(accessManager),
      abi.encodeCall(IAccessManager.setTargetAdminDelay, (TARGET, TEST_ADMIN_DELAY))
    );

    vm.expectEmit(true, false, false, false, address(accessManager));
    emit IAccessManager.TargetAdminDelayUpdated(TARGET, TEST_ADMIN_DELAY, 0);

    engine.executeTargetAdminDelayUpdates(
      _toTargetAdminDelayUpdateArray(
        IAaveV4ConfigEngine.TargetAdminDelayUpdate({
          authority: address(accessManager),
          target: TARGET,
          newDelay: TEST_ADMIN_DELAY
        })
      )
    );

    vm.warp(block.timestamp + 5 days);
    assertEq(accessManager.getTargetAdminDelay(TARGET), TEST_ADMIN_DELAY);
  }

  function test_fuzz_executeTargetAdminDelayUpdates(address target, uint32 newDelay) public {
    engine.executeTargetAdminDelayUpdates(
      _toTargetAdminDelayUpdateArray(
        IAaveV4ConfigEngine.TargetAdminDelayUpdate({
          authority: address(accessManager),
          target: target,
          newDelay: newDelay
        })
      )
    );

    vm.warp(block.timestamp + 5 days);
    assertEq(accessManager.getTargetAdminDelay(target), newDelay);
  }

  function test_executeTargetAdminDelayUpdates_revert() public {
    vm.prank(ADMIN);
    accessManager.revokeRole(DEFAULT_ADMIN_ROLE, address(engine));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(engine),
        DEFAULT_ADMIN_ROLE
      )
    );
    engine.executeTargetAdminDelayUpdates(
      _toTargetAdminDelayUpdateArray(
        IAaveV4ConfigEngine.TargetAdminDelayUpdate({
          authority: address(accessManager),
          target: TARGET,
          newDelay: TEST_ADMIN_DELAY
        })
      )
    );
  }

  function test_executeRoleMemberships_multipleMemberships() public {
    IAaveV4ConfigEngine.RoleMembership[]
      memory memberships = new IAaveV4ConfigEngine.RoleMembership[](2);
    memberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: TEST_ROLE_ID,
      account: ACCOUNT,
      granted: true,
      executionDelay: TEST_EXEC_DELAY_SHORT
    });
    memberships[1] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: TEST_ROLE_ID_2,
      account: USER,
      granted: true,
      executionDelay: TEST_EXEC_DELAY_LONG
    });

    engine.executeRoleMemberships(memberships);

    (bool isMember1, uint32 delay1) = accessManager.hasRole(TEST_ROLE_ID, ACCOUNT);
    assertTrue(isMember1);
    assertEq(delay1, TEST_EXEC_DELAY_SHORT);

    (bool isMember2, uint32 delay2) = accessManager.hasRole(TEST_ROLE_ID_2, USER);
    assertTrue(isMember2);
    assertEq(delay2, TEST_EXEC_DELAY_LONG);
  }
}
