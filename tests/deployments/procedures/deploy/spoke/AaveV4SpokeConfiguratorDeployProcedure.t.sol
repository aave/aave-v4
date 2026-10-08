// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeConfiguratorDeployProcedureTest is ProceduresBase {
  AaveV4SpokeConfiguratorDeployProcedureWrapper
    public aaveV4SpokeConfiguratorDeployProcedureWrapper;

  function setUp() public override {
    super.setUp();
    aaveV4SpokeConfiguratorDeployProcedureWrapper = new AaveV4SpokeConfiguratorDeployProcedureWrapper();
  }

  function test_deploySpokeConfigurator() public {
    (address proxy, address implementation) = aaveV4SpokeConfiguratorDeployProcedureWrapper
      .deployUpgradeableSpokeConfigurator(admin, accessManager, salt);
    assertNotEq(proxy, address(0));
    assertNotEq(implementation, address(0));
    assertNotEq(proxy, implementation);
    assertEq(ProxyHelper.getImplementation(proxy), implementation);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(proxy)).owner(), admin);
    assertEq(IAccessManaged(proxy).authority(), accessManager);
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
    assertEq(ProxyHelper.getProxyInitializedVersion(proxy), 1);
  }

  function test_deploySpokeConfigurator_reverts_invalidAuthority() public {
    vm.expectRevert('invalid authority');
    aaveV4SpokeConfiguratorDeployProcedureWrapper.deployUpgradeableSpokeConfigurator({
      proxyAdminOwner: admin,
      authority: address(0),
      salt: salt
    });
  }

  function test_deploySpokeConfigurator_reverts_invalidProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    aaveV4SpokeConfiguratorDeployProcedureWrapper.deployUpgradeableSpokeConfigurator({
      proxyAdminOwner: address(0),
      authority: accessManager,
      salt: salt
    });
  }
}
