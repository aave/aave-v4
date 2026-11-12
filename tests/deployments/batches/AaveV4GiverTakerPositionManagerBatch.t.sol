// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4GiverTakerPositionManagerBatchTest is BatchBaseTest {
  AaveV4GiverTakerPositionManagerBatch public batch;
  BatchReports.GiverTakerPositionManagerBatchReport public report;

  function setUp() public override {
    super.setUp();
    batch = new AaveV4GiverTakerPositionManagerBatch({owner_: admin, salt_: salt});
    report = batch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.giverPositionManager, address(0));
    assertNotEq(report.takerPositionManager, address(0));
  }

  function test_owner() public view {
    assertEq(Ownable(report.giverPositionManager).owner(), admin);
    assertEq(Ownable(report.takerPositionManager).owner(), admin);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4GiverTakerPositionManagerBatch({
      owner_: address(0),
      salt_: keccak256('zeroOwnerSalt')
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4GiverTakerPositionManagerBatch newBatch = new AaveV4GiverTakerPositionManagerBatch({
      owner_: admin,
      salt_: keccak256('differentSalt')
    });
    BatchReports.GiverTakerPositionManagerBatchReport memory newReport = newBatch.getReport();
    assertNotEq(report.giverPositionManager, newReport.giverPositionManager);
    assertNotEq(report.takerPositionManager, newReport.takerPositionManager);
  }
}
