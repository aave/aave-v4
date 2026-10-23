// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4GiverPositionManagerBatchTest is BatchBaseTest {
  AaveV4GiverPositionManagerBatch public batch;
  BatchReports.GiverPositionManagerBatchReport public report;

  function setUp() public override {
    super.setUp();
    batch = new AaveV4GiverPositionManagerBatch({owner_: admin, salt_: salt});
    report = batch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.giverPositionManager, address(0));
  }

  function test_owner() public view {
    assertEq(Ownable(report.giverPositionManager).owner(), admin);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4GiverPositionManagerBatch({owner_: address(0), salt_: keccak256('zeroOwnerSalt')});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4GiverPositionManagerBatch newBatch = new AaveV4GiverPositionManagerBatch({
      owner_: admin,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.giverPositionManager, newBatch.getReport().giverPositionManager);
  }
}
