// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4ConfigPositionManagerBatchTest is BatchBaseTest {
  AaveV4ConfigPositionManagerBatch public batch;
  BatchReports.ConfigPositionManagerBatchReport public report;

  function setUp() public override {
    super.setUp();
    batch = new AaveV4ConfigPositionManagerBatch({owner_: admin, salt_: salt});
    report = batch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.configPositionManager, address(0));
  }

  function test_owner() public view {
    assertEq(Ownable(report.configPositionManager).owner(), admin);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4ConfigPositionManagerBatch({owner_: address(0), salt_: keccak256('zeroOwnerSalt')});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4ConfigPositionManagerBatch newBatch = new AaveV4ConfigPositionManagerBatch({
      owner_: admin,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.configPositionManager, newBatch.getReport().configPositionManager);
  }
}
