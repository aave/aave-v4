// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4TreasurySpokeDeployProcedureTest is ProceduresBase {
  AaveV4TreasurySpokeDeployProcedureWrapper public aaveV4TreasurySpokeDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4TreasurySpokeDeployProcedureWrapper = new AaveV4TreasurySpokeDeployProcedureWrapper();
  }

  function test_deployTreasurySpokeImplementation() public {
    address treasurySpokeImpl = aaveV4TreasurySpokeDeployProcedureWrapper
      .deployTreasurySpokeImplementation(salt);
    assertNotEq(treasurySpokeImpl.code.length, 0);
    assertEq(ProxyHelper.getProxyInitializedVersion(treasurySpokeImpl), type(uint64).max);
    assertEq(Ownable(treasurySpokeImpl).owner(), address(0));
  }

  function test_deployTreasurySpokeImplementation_reverts_alreadyDeployed() public {
    aaveV4TreasurySpokeDeployProcedureWrapper.deployTreasurySpokeImplementation(salt);
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    aaveV4TreasurySpokeDeployProcedureWrapper.deployTreasurySpokeImplementation(salt);
  }
}
