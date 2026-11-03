// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeDeployProcedureTest is ProceduresBase {
  AaveV4SpokeDeployProcedureWrapper public aaveV4SpokeDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4SpokeDeployProcedureWrapper = new AaveV4SpokeDeployProcedureWrapper();
  }

  function test_deploySpokeImplementation() public {
    address spokeImpl = aaveV4SpokeDeployProcedureWrapper.deploySpokeImplementation(
      spokeBytecode,
      salt
    );
    assertEq(spokeImpl, Create2Utils.computeCreate2Address(salt, spokeBytecode));
    assertEq(ProxyHelper.getProxyInitializedVersion(spokeImpl), type(uint64).max);
    assertEq(ISpoke(spokeImpl).ORACLE(), address(0));
  }

  function test_deploySpokeImplementation_reverts_alreadyDeployed() public {
    aaveV4SpokeDeployProcedureWrapper.deploySpokeImplementation(spokeBytecode, salt);
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    aaveV4SpokeDeployProcedureWrapper.deploySpokeImplementation(spokeBytecode, salt);
  }
}
