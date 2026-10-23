// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4HubInstanceBatchTest is BatchBaseTest {
  AaveV4HubInstanceBatch public hubInstanceBatch;
  BatchReports.HubInstanceBatchReport public report;
  address public hubImplementation;

  function setUp() public override {
    super.setUp();
    hubImplementation = AaveV4HubImplementationDeployProcedure.deployHubImplementation(
      hubBytecode,
      salt
    );
    hubInstanceBatch = new AaveV4HubInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      hubImplementation_: hubImplementation,
      salt_: salt
    });
    report = hubInstanceBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.hubProxy, address(0));
    assertEq(report.hubImplementation, hubImplementation);
    assertNotEq(report.irStrategy, address(0));
    assertNotEq(report.hubProxy, report.hubImplementation);
  }

  function test_hubImplementation() public view {
    assertEq(ProxyHelper.getImplementation(report.hubProxy), hubImplementation);
    assertEq(
      hubImplementation,
      Create2Utils.computeCreate2Address({salt: salt, bytecode: hubBytecode})
    );
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
      proxyAdminOwner_: admin,
      authority_: address(0),
      hubImplementation_: hubImplementation,
      salt_: salt
    });
  }

  function test_revert_zeroProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    new AaveV4HubInstanceBatch({
      proxyAdminOwner_: address(0),
      authority_: accessManager,
      hubImplementation_: hubImplementation,
      salt_: salt
    });
  }

  function test_revert_invalidHubImplementation() public {
    vm.expectRevert('invalid hub implementation');
    new AaveV4HubInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      hubImplementation_: makeAddr('noCode'),
      salt_: keccak256('differentSalt')
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4HubInstanceBatch newBatch = new AaveV4HubInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      hubImplementation_: hubImplementation,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.hubProxy, newBatch.getReport().hubProxy);
  }
}
