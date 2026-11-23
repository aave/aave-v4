// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

contract AaveV4TokenizationSpokeDeployProcedureTest is ProceduresBase {
  AaveV4TokenizationSpokeDeployProcedureWrapper public wrapper;
  address public implementation;

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4TokenizationSpokeDeployProcedureWrapper();
    implementation = wrapper.deployTokenizationSpokeImplementation(salt);
  }

  function test_deployTokenizationSpokeImplementation() public view {
    assertEq(
      implementation,
      Create2Utils.computeCreate2Address(salt, type(TokenizationSpokeInstance).creationCode)
    );
    assertEq(TokenizationSpokeInstance(implementation).SPOKE_REVISION(), 2);
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
    assertEq(ITokenizationSpoke(implementation).hub(), address(0));
  }

  function test_deployTokenizationSpokeImplementation_revertsWith_ContractAlreadyDeployed() public {
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    wrapper.deployTokenizationSpokeImplementation(salt);
  }
}
