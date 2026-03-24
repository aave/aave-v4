// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4AuthorityBatchTest is BatchBaseTest {
  AaveV4AuthorityBatch public aaveV4AuthorityBatch;
  function setUp() public override {
    super.setUp();
    bytes32 accessSalt = keccak256('authorityBatchSalt');
    aaveV4AuthorityBatch = new AaveV4AuthorityBatch({admin_: admin, salt_: accessSalt});
  }

  function test_getReport() public view {
    BatchReports.AuthorityBatchReport memory report = aaveV4AuthorityBatch.getReport();
    assertNotEq(report.accessManager, address(0));

    (bool hasRole, uint32 executionDelay) = IAccessManagerEnumerable(report.accessManager).hasRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      admin
    );
    assertTrue(hasRole);
    assertEq(executionDelay, 0);
  }

  function test_revert_zeroAdmin() public {
    vm.expectRevert('invalid admin');
    new AaveV4AuthorityBatch({admin_: address(0), salt_: keccak256('zeroAdminSalt')});
  }

  function test_adminRoleMemberTracking() public view {
    IAccessManagerEnumerable am = IAccessManagerEnumerable(
      aaveV4AuthorityBatch.getReport().accessManager
    );
    assertEq(am.getRoleMemberCount(Roles.ACCESS_MANAGER_ADMIN_ROLE), 1);
    assertEq(am.getRoleMember(Roles.ACCESS_MANAGER_ADMIN_ROLE, 0), admin);
  }

  function test_noOtherRolesInitialized() public view {
    IAccessManagerEnumerable am = IAccessManagerEnumerable(
      aaveV4AuthorityBatch.getReport().accessManager
    );
    assertEq(am.getRoleCount(), 0);
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4AuthorityBatch newBatch = new AaveV4AuthorityBatch({
      admin_: admin,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(aaveV4AuthorityBatch.getReport().accessManager, newBatch.getReport().accessManager);
  }
}
