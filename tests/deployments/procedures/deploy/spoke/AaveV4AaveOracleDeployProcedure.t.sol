// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4AaveOracleDeployProcedureTest is ProceduresBase {
  AaveV4AaveOracleDeployProcedureWrapper public aaveV4AaveOracleDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4AaveOracleDeployProcedureWrapper = new AaveV4AaveOracleDeployProcedureWrapper();
  }

  function test_deployAaveOracle() public {
    address oracle = aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle(oracleDecimals);
    assertNotEq(oracle, address(0));
    assertEq(IAaveOracle(oracle).decimals(), oracleDecimals);
    assertEq(IAaveOracle(oracle).BASE_CURRENCY(), IAaveOracle(oracle).USD_ADDRESS());
  }

  function test_deployAaveOracle_reverts_inputValidation() public {
    vm.expectRevert('invalid oracle decimals');
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({decimals: 0});
  }
}
