// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4ConfiguratorBatchTest is BatchBaseTest {
  AaveV4ConfiguratorBatch public configuratorBatch;
  BatchReports.ConfiguratorBatchReport public report;

  function setUp() public override {
    super.setUp();
    configuratorBatch = new AaveV4ConfiguratorBatch({
      proxyAdminOwner_: admin,
      hubConfiguratorAuthority_: accessManager,
      spokeConfiguratorAuthority_: accessManager,
      salt_: salt
    });
    report = configuratorBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.hubConfigurator, address(0));
    assertNotEq(report.hubConfiguratorImplementation, address(0));
    assertNotEq(report.spokeConfigurator, address(0));
    assertNotEq(report.spokeConfiguratorImplementation, address(0));
  }

  function test_hubConfiguratorProxy() public view {
    _assertProxy(report.hubConfigurator, report.hubConfiguratorImplementation);
  }

  function test_spokeConfiguratorProxy() public view {
    _assertProxy(report.spokeConfigurator, report.spokeConfiguratorImplementation);
  }

  function test_revert_zeroProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    new AaveV4ConfiguratorBatch({
      proxyAdminOwner_: address(0),
      hubConfiguratorAuthority_: accessManager,
      spokeConfiguratorAuthority_: accessManager,
      salt_: keccak256('zeroProxyAdminOwnerSalt')
    });
  }

  function test_revert_zeroHubConfiguratorAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4ConfiguratorBatch({
      proxyAdminOwner_: admin,
      hubConfiguratorAuthority_: address(0),
      spokeConfiguratorAuthority_: accessManager,
      salt_: salt
    });
  }

  function test_revert_zeroSpokeConfiguratorAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4ConfiguratorBatch({
      proxyAdminOwner_: admin,
      hubConfiguratorAuthority_: accessManager,
      spokeConfiguratorAuthority_: address(0),
      salt_: keccak256('zeroSpokeCfgSalt')
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4ConfiguratorBatch newBatch = new AaveV4ConfiguratorBatch({
      proxyAdminOwner_: admin,
      hubConfiguratorAuthority_: accessManager,
      spokeConfiguratorAuthority_: accessManager,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.hubConfigurator, newBatch.getReport().hubConfigurator);
    assertNotEq(report.spokeConfigurator, newBatch.getReport().spokeConfigurator);
  }

  function _assertProxy(address proxy, address implementation) internal view {
    assertEq(ProxyHelper.getImplementation(proxy), implementation);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(proxy)).owner(), admin);
    assertEq(IAccessManaged(proxy).authority(), accessManager);
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
    assertEq(ProxyHelper.getProxyInitializedVersion(proxy), 1);
  }
}
