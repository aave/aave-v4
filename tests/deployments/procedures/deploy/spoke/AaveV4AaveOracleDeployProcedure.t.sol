// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {AaveV4AaveOracleDeployer} from 'src/deployments/utils/AaveV4AaveOracleDeployer.sol';

contract AaveV4AaveOracleDeployProcedureTest is ProceduresBase {
  AaveV4AaveOracleDeployProcedureWrapper public aaveV4AaveOracleDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4AaveOracleDeployProcedureWrapper = new AaveV4AaveOracleDeployProcedureWrapper();
  }

  function test_deployAaveOracle() public {
    bytes32 salt = keccak256('oracle');
    (address aaveOracleDeployer, address oracle) = aaveV4AaveOracleDeployProcedureWrapper
      .deployAaveOracle(owner, oracleDecimals, salt);
    assertEq(
      aaveOracleDeployer,
      Create2Utils.computeCreate2Address(
        salt,
        abi.encodePacked(
          type(AaveV4AaveOracleDeployer).creationCode,
          abi.encode(owner, oracleDecimals, salt)
        )
      )
    );
    assertEq(
      oracle,
      vm.computeCreate2Address(
        salt,
        keccak256(abi.encodePacked(type(AaveOracle).creationCode, abi.encode(oracleDecimals))),
        aaveOracleDeployer
      )
    );
    assertEq(AaveV4AaveOracleDeployer(aaveOracleDeployer).OWNER(), owner);
    assertEq(IAaveOracle(oracle).decimals(), oracleDecimals);
  }

  function test_setAaveOracleSpoke_reverts_notOwner() public {
    (address aaveOracleDeployer, ) = aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle(
      owner,
      oracleDecimals,
      keccak256('oracle')
    );
    vm.expectRevert('only owner');
    aaveV4AaveOracleDeployProcedureWrapper.setAaveOracleSpoke(aaveOracleDeployer, spoke);
  }

  function test_deployAaveOracle_reverts_inputValidation() public {
    vm.expectRevert('invalid owner');
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({
      owner: address(0),
      decimals: oracleDecimals,
      salt: bytes32(0)
    });
    vm.expectRevert('invalid oracle decimals');
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({
      owner: owner,
      decimals: 0,
      salt: bytes32(0)
    });
  }
}
