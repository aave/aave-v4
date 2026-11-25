// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4EmergencyStewardDeployProcedureTest is ProceduresBase {
  AaveV4EmergencyStewardDeployProcedureWrapper public aaveV4EmergencyStewardDeployProcedureWrapper;
  address public spokeConfigurator = makeAddr('spokeConfigurator');

  function setUp() public override {
    super.setUp();
    aaveV4EmergencyStewardDeployProcedureWrapper = new AaveV4EmergencyStewardDeployProcedureWrapper();
  }

  function test_deployEmergencySteward() public {
    address emergencySteward = aaveV4EmergencyStewardDeployProcedureWrapper.deployEmergencySteward({
      authority: accessManager,
      spokeConfigurator: spokeConfigurator,
      salt: salt
    });
    assertEq(IAccessManaged(emergencySteward).authority(), accessManager);
    assertEq(IEmergencySteward(emergencySteward).SPOKE_CONFIGURATOR(), spokeConfigurator);
  }

  function test_deployEmergencySteward_reverts() public {
    vm.expectRevert('invalid authority');
    aaveV4EmergencyStewardDeployProcedureWrapper.deployEmergencySteward({
      authority: address(0),
      spokeConfigurator: spokeConfigurator,
      salt: salt
    });

    vm.expectRevert('invalid spoke configurator');
    aaveV4EmergencyStewardDeployProcedureWrapper.deployEmergencySteward({
      authority: accessManager,
      spokeConfigurator: address(0),
      salt: salt
    });
  }
}
