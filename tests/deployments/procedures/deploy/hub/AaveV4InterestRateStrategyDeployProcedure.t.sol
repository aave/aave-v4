// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4InterestRateStrategyDeployProcedureTest is ProceduresBase {
  AaveV4InterestRateStrategyDeployProcedureWrapper
    public aaveV4InterestRateStrategyDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4InterestRateStrategyDeployProcedureWrapper = new AaveV4InterestRateStrategyDeployProcedureWrapper();
  }

  function test_deployInterestRateStrategy() public {
    address interestRateStrategy = aaveV4InterestRateStrategyDeployProcedureWrapper
      .deployInterestRateStrategy(hub, salt);
    assertNotEq(interestRateStrategy, address(0));
    assertEq(IAssetInterestRateStrategy(interestRateStrategy).HUB(), hub);
  }

  function test_deployInterestRateStrategy_reverts() public {
    vm.expectRevert('invalid hub');
    aaveV4InterestRateStrategyDeployProcedureWrapper.deployInterestRateStrategy({
      hub: address(0),
      salt: salt
    });
  }
}
