// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4HubConfiguratorBatchTest is BatchBaseTest {
  AaveV4HubConfiguratorBatch public batch;
  BatchReports.HubConfiguratorBatchReport public report;

  function setUp() public override {
    super.setUp();
    batch = new AaveV4HubConfiguratorBatch({authority_: accessManager, salt_: salt});
    report = batch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.hubConfigurator, address(0));
  }

  function test_authority() public view {
    assertEq(IAccessManaged(report.hubConfigurator).authority(), accessManager);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4HubConfiguratorBatch({authority_: address(0), salt_: keccak256('zeroAuthoritySalt')});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4HubConfiguratorBatch newBatch = new AaveV4HubConfiguratorBatch({
      authority_: accessManager,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.hubConfigurator, newBatch.getReport().hubConfigurator);
  }
}
