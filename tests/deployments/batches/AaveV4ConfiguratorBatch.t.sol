// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4ConfiguratorBatchTest is BatchBaseTest {
  AaveV4ConfiguratorBatch public configuratorBatch;
  BatchReports.ConfiguratorBatchReport public report;

  function setUp() public override {
    super.setUp();
    configuratorBatch = new AaveV4ConfiguratorBatch({
      hubConfiguratorAuthority_: accessManager,
      spokeConfiguratorAuthority_: accessManager,
      salt_: salt
    });
    report = configuratorBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.hubConfigurator, address(0));
    assertNotEq(report.spokeConfigurator, address(0));
  }

  function test_hubConfiguratorAuthority() public view {
    assertEq(IAccessManaged(report.hubConfigurator).authority(), accessManager);
  }

  function test_spokeConfiguratorAuthority() public view {
    assertEq(IAccessManaged(report.spokeConfigurator).authority(), accessManager);
  }

  function test_revert_zeroHubConfiguratorAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4ConfiguratorBatch({
      hubConfiguratorAuthority_: address(0),
      spokeConfiguratorAuthority_: accessManager,
      salt_: salt
    });
  }

  function test_revert_zeroSpokeConfiguratorAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4ConfiguratorBatch({
      hubConfiguratorAuthority_: accessManager,
      spokeConfiguratorAuthority_: address(0),
      salt_: keccak256('zeroSpokeCfgSalt')
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4ConfiguratorBatch newBatch = new AaveV4ConfiguratorBatch({
      hubConfiguratorAuthority_: accessManager,
      spokeConfiguratorAuthority_: accessManager,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.hubConfigurator, newBatch.getReport().hubConfigurator);
  }
}
