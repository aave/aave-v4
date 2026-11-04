// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4FeeSharesMinterDeployProcedureTest is ProceduresBase {
  AaveV4FeeSharesMinterDeployProcedureWrapper public aaveV4FeeSharesMinterDeployProcedureWrapper;

  function setUp() public override {
    super.setUp();
    aaveV4FeeSharesMinterDeployProcedureWrapper = new AaveV4FeeSharesMinterDeployProcedureWrapper();
  }

  function test_deployFeeSharesMinter() public {
    address feeSharesMinter = aaveV4FeeSharesMinterDeployProcedureWrapper.deployFeeSharesMinter(
      owner,
      salt
    );
    assertEq(Ownable(feeSharesMinter).owner(), owner);
  }

  function test_deployFeeSharesMinter_reverts() public {
    vm.expectRevert('invalid owner');
    aaveV4FeeSharesMinterDeployProcedureWrapper.deployFeeSharesMinter({
      owner: address(0),
      salt: salt
    });
  }
}
