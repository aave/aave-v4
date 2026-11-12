// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubImplementationDeployProcedureTest is ProceduresBase {
  AaveV4HubImplementationDeployProcedureWrapper public wrapper;

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4HubImplementationDeployProcedureWrapper();
  }

  function test_deployHubImplementation() public {
    address hubImplementation = wrapper.deployHubImplementation(hubBytecode, salt);
    assertEq(
      hubImplementation,
      Create2Utils.computeCreate2Address({salt: salt, bytecode: hubBytecode})
    );
    assertGt(hubImplementation.code.length, 0);
  }

  function test_deployHubImplementation_reverts_alreadyDeployed() public {
    wrapper.deployHubImplementation(hubBytecode, salt);
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    wrapper.deployHubImplementation(hubBytecode, salt);
  }
}
