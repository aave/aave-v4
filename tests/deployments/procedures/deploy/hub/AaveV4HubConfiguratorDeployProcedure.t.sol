// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubConfiguratorDeployProcedureTest is ProceduresBase {
  AaveV4HubConfiguratorDeployProcedureWrapper public aaveV4HubConfiguratorDeployProcedureWrapper;

  function setUp() public override {
    super.setUp();
    aaveV4HubConfiguratorDeployProcedureWrapper = new AaveV4HubConfiguratorDeployProcedureWrapper();
  }

  function test_deployHubConfigurator() public {
    (address proxy, address implementation) = aaveV4HubConfiguratorDeployProcedureWrapper
      .deployUpgradeableHubConfigurator(admin, accessManager, salt);
    assertNotEq(proxy, address(0));
    assertNotEq(implementation, address(0));
    assertNotEq(proxy, implementation);
    assertEq(ProxyHelper.getImplementation(proxy), implementation);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(proxy)).owner(), admin);
    assertEq(IAccessManaged(proxy).authority(), accessManager);
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
    assertEq(ProxyHelper.getProxyInitializedVersion(proxy), 1);
  }

  function test_deployHubConfigurator_reverts_invalidAuthority() public {
    vm.expectRevert('invalid authority');
    aaveV4HubConfiguratorDeployProcedureWrapper.deployUpgradeableHubConfigurator({
      proxyAdminOwner: admin,
      authority: address(0),
      salt: salt
    });
  }

  function test_deployHubConfigurator_reverts_invalidProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    aaveV4HubConfiguratorDeployProcedureWrapper.deployUpgradeableHubConfigurator({
      proxyAdminOwner: address(0),
      authority: accessManager,
      salt: salt
    });
  }
}
