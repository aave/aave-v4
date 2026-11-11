// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubDeployProcedureTest is ProceduresBase {
  AaveV4HubDeployProcedureWrapper public aaveV4HubDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4HubDeployProcedureWrapper = new AaveV4HubDeployProcedureWrapper();
  }

  function test_deployHubImplementation() public {
    address hubImpl = aaveV4HubDeployProcedureWrapper.deployHubImplementation(hubBytecode, salt);
    assertEq(hubImpl, Create2Utils.computeCreate2Address(salt, hubBytecode));
    assertEq(ProxyHelper.getProxyInitializedVersion(hubImpl), type(uint64).max);
  }

  function test_deployHubImplementation_reverts_alreadyDeployed() public {
    aaveV4HubDeployProcedureWrapper.deployHubImplementation(hubBytecode, salt);
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    aaveV4HubDeployProcedureWrapper.deployHubImplementation(hubBytecode, salt);
  }
}
