// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';
import {AaveV4FeeSharesMinterBatch} from 'src/deployments/batches/AaveV4FeeSharesMinterBatch.sol';

contract AaveV4FeeSharesMinterBatchTest is BatchBaseTest {
  AaveV4FeeSharesMinterBatch public feeSharesMinterBatch;
  BatchReports.FeeSharesMinterBatchReport public report;

  function setUp() public override {
    super.setUp();
    feeSharesMinterBatch = new AaveV4FeeSharesMinterBatch({owner_: admin, salt_: salt});
    report = feeSharesMinterBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.feeSharesMinter, address(0));
  }

  function test_feeSharesMinterOwner() public view {
    assertEq(Ownable(report.feeSharesMinter).owner(), admin);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4FeeSharesMinterBatch({owner_: address(0), salt_: keccak256('zeroOwnerSalt')});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4FeeSharesMinterBatch newBatch = new AaveV4FeeSharesMinterBatch({
      owner_: admin,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.feeSharesMinter, newBatch.getReport().feeSharesMinter);
  }
}
