// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4TakerPositionManagerBatchTest is BatchBaseTest {
  AaveV4TakerPositionManagerBatch public batch;
  BatchReports.TakerPositionManagerBatchReport public report;

  function setUp() public override {
    super.setUp();
    batch = new AaveV4TakerPositionManagerBatch({owner_: admin, salt_: salt});
    report = batch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.takerPositionManager, address(0));
  }

  function test_owner() public view {
    assertEq(Ownable(report.takerPositionManager).owner(), admin);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4TakerPositionManagerBatch({owner_: address(0), salt_: keccak256('zeroOwnerSalt')});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4TakerPositionManagerBatch newBatch = new AaveV4TakerPositionManagerBatch({
      owner_: admin,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.takerPositionManager, newBatch.getReport().takerPositionManager);
  }
}
