// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';

contract AaveV4AaveOracleDeployProcedureTest is ProceduresBase {
  AaveV4AaveOracleDeployProcedureWrapper public aaveV4AaveOracleDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4AaveOracleDeployProcedureWrapper = new AaveV4AaveOracleDeployProcedureWrapper();
  }

  function test_deployAaveOracle() public {
    bytes32 salt = keccak256('oracle');
    address oracle = aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle(oracleDecimals, salt);
    assertEq(
      oracle,
      vm.computeCreate2Address(
        salt,
        keccak256(abi.encodePacked(type(AaveOracle).creationCode, abi.encode(oracleDecimals))),
        address(aaveV4AaveOracleDeployProcedureWrapper)
      )
    );
    assertEq(IAaveOracle(oracle).decimals(), oracleDecimals);
  }

  function test_deployAaveOracle_reverts_inputValidation() public {
    vm.expectRevert('invalid oracle decimals');
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({decimals: 0, salt: bytes32(0)});
  }
}
