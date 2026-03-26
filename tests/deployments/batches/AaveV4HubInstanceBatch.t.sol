// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4HubInstanceBatchTest is BatchBaseTest {
  AaveV4HubInstanceBatch public hubInstanceBatch;
  BatchReports.HubInstanceBatchReport public report;

  function setUp() public override {
    super.setUp();
    hubInstanceBatch = new AaveV4HubInstanceBatch({
      hubProxyAdminOwner_: admin,
      authority_: accessManager,
      hubBytecode_: hubBytecode,
      salt_: salt
    });
    report = hubInstanceBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.hubProxy, address(0));
    assertNotEq(report.hubImplementation, address(0));
    assertNotEq(report.irStrategy, address(0));
    assertNotEq(report.hubProxy, report.hubImplementation);
  }

  function test_hubAuthority() public view {
    assertEq(IAccessManaged(report.hubProxy).authority(), accessManager);
  }

  function test_irStrategyHub() public view {
    assertEq(IAssetInterestRateStrategy(report.irStrategy).HUB(), report.hubProxy);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4HubInstanceBatch({
      hubProxyAdminOwner_: admin,
      authority_: address(0),
      hubBytecode_: hubBytecode,
      salt_: salt
    });
  }

  function test_revert_zeroHubProxyAdminOwner() public {
    vm.expectRevert('invalid hub proxy admin owner');
    new AaveV4HubInstanceBatch({
      hubProxyAdminOwner_: address(0),
      authority_: accessManager,
      hubBytecode_: hubBytecode,
      salt_: salt
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4HubInstanceBatch newBatch = new AaveV4HubInstanceBatch({
      hubProxyAdminOwner_: admin,
      authority_: accessManager,
      hubBytecode_: hubBytecode,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.hubProxy, newBatch.getReport().hubProxy);
  }
}
