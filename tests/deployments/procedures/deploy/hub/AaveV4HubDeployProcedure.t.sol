// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubDeployProcedureTest is ProceduresBase {
  AaveV4HubDeployProcedureWrapper public aaveV4HubDeployProcedureWrapper;
  address public hubImplementation;

  function setUp() public override {
    super.setUp();
    aaveV4HubDeployProcedureWrapper = new AaveV4HubDeployProcedureWrapper();
    hubImplementation = Create2Utils.create2Deploy(salt, hubBytecode);
  }

  function test_deployHubProxy() public {
    address hubProxy = aaveV4HubDeployProcedureWrapper.deployHubProxy(
      admin,
      accessManager,
      hubImplementation,
      keccak256(hubBytecode),
      salt
    );
    assertNotEq(hubProxy, address(0));
    assertNotEq(hubProxy, hubImplementation);
    assertEq(ProxyHelper.getImplementation(hubProxy), hubImplementation);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(hubProxy)).owner(), admin);
    assertEq(IHub(hubProxy).authority(), accessManager);
  }

  function test_deployHubProxy_reverts_invalidAuthority() public {
    vm.expectRevert('invalid authority');
    aaveV4HubDeployProcedureWrapper.deployHubProxy({
      proxyAdminOwner: admin,
      authority: address(0),
      hubImplementation: hubImplementation,
      hubInitCodeHash: keccak256(hubBytecode),
      salt: salt
    });
  }

  function test_deployHubProxy_reverts_invalidProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    aaveV4HubDeployProcedureWrapper.deployHubProxy({
      proxyAdminOwner: address(0),
      authority: accessManager,
      hubImplementation: hubImplementation,
      hubInitCodeHash: keccak256(hubBytecode),
      salt: salt
    });
  }

  function test_deployHubProxy_reverts_invalidHubImplementation() public {
    vm.expectRevert('invalid hub implementation');
    aaveV4HubDeployProcedureWrapper.deployHubProxy({
      proxyAdminOwner: admin,
      authority: accessManager,
      hubImplementation: makeAddr('noCode'),
      hubInitCodeHash: keccak256(hubBytecode),
      salt: salt
    });
  }

  function test_deployHubProxy_reverts_hubImplementationCodeMismatch() public {
    vm.expectRevert('invalid hub implementation');
    aaveV4HubDeployProcedureWrapper.deployHubProxy({
      proxyAdminOwner: admin,
      authority: accessManager,
      hubImplementation: hubImplementation,
      hubInitCodeHash: keccak256('otherBytecode'),
      salt: salt
    });
  }
}
