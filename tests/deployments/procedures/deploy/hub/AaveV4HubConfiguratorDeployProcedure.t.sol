// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubConfiguratorDeployProcedureTest is ProceduresBase {
  AaveV4HubConfiguratorDeployProcedureWrapper public aaveV4HubConfiguratorDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4HubConfiguratorDeployProcedureWrapper = new AaveV4HubConfiguratorDeployProcedureWrapper();
  }

  function test_deployHubConfigurator() public {
    address hubConfigurator = aaveV4HubConfiguratorDeployProcedureWrapper.deployHubConfigurator(
      owner,
      salt
    );
    assertNotEq(hubConfigurator, address(0));
    assertEq(IAccessManaged(hubConfigurator).authority(), owner);
  }

  function test_deployHubConfigurator_reverts() public {
    vm.expectRevert('invalid authority');
    aaveV4HubConfiguratorDeployProcedureWrapper.deployHubConfigurator({
      authority: address(0),
      salt: salt
    });
  }
}
