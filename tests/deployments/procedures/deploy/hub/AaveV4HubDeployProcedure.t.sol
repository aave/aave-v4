// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubDeployProcedureTest is ProceduresBase {
  AaveV4HubDeployProcedureWrapper public aaveV4HubDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4HubDeployProcedureWrapper = new AaveV4HubDeployProcedureWrapper();
  }

  function test_deployHub() public {
    (address hubProxy, address hubImpl) = aaveV4HubDeployProcedureWrapper.deployHub(
      admin,
      accessManager,
      hubBytecode,
      salt
    );
    assertNotEq(hubProxy, address(0));
    assertNotEq(hubImpl, address(0));
    assertNotEq(hubProxy, hubImpl);
    assertEq(IHub(hubProxy).authority(), accessManager);
  }

  function test_deployHub_reverts_invalidAuthority() public {
    vm.expectRevert('invalid authority');
    aaveV4HubDeployProcedureWrapper.deployHub({
      hubProxyAdminOwner: admin,
      authority: address(0),
      hubBytecode: hubBytecode,
      salt: salt
    });
  }

  function test_deployHub_reverts_invalidProxyAdminOwner() public {
    vm.expectRevert('invalid hub proxy admin owner');
    aaveV4HubDeployProcedureWrapper.deployHub({
      hubProxyAdminOwner: address(0),
      authority: accessManager,
      hubBytecode: hubBytecode,
      salt: salt
    });
  }
}
