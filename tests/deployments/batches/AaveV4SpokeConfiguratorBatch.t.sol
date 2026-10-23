// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4SpokeConfiguratorBatchTest is BatchBaseTest {
  AaveV4SpokeConfiguratorBatch public batch;
  BatchReports.SpokeConfiguratorBatchReport public report;

  function setUp() public override {
    super.setUp();
    batch = new AaveV4SpokeConfiguratorBatch({authority_: accessManager, salt_: salt});
    report = batch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.spokeConfigurator, address(0));
  }

  function test_authority() public view {
    assertEq(IAccessManaged(report.spokeConfigurator).authority(), accessManager);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4SpokeConfiguratorBatch({
      authority_: address(0),
      salt_: keccak256('zeroAuthoritySalt')
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4SpokeConfiguratorBatch newBatch = new AaveV4SpokeConfiguratorBatch({
      authority_: accessManager,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.spokeConfigurator, newBatch.getReport().spokeConfigurator);
  }
}
