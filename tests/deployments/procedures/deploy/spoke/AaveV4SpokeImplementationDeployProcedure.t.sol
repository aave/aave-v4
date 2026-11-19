// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeImplementationDeployProcedureTest is ProceduresBase {
  AaveV4SpokeImplementationDeployProcedureWrapper public wrapper;

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4SpokeImplementationDeployProcedureWrapper();
  }

  function test_deploySpokeImplementation() public {
    address spokeImplementation = wrapper.deploySpokeImplementation(
      aaveOracle,
      spokeBytecode,
      maxUserReservesLimit,
      salt
    );
    assertEq(
      spokeImplementation,
      Create2Utils.computeCreate2Address({
        salt: salt,
        bytecode: AaveV4SpokeImplementationDeployProcedure.getSpokeInstanceInitCode(
          spokeBytecode,
          aaveOracle,
          maxUserReservesLimit
        )
      })
    );
    assertEq(ISpoke(spokeImplementation).ORACLE(), aaveOracle);
    assertEq(ISpoke(spokeImplementation).MAX_USER_RESERVES_LIMIT(), maxUserReservesLimit);
  }

  function test_deploySpokeImplementation_reverts_invalidOracle() public {
    vm.expectRevert('invalid oracle');
    wrapper.deploySpokeImplementation({
      oracle: address(0),
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });
  }

  function test_deploySpokeImplementation_reverts_invalidMaxUserReservesLimit() public {
    vm.expectRevert('invalid max user reserves limit');
    wrapper.deploySpokeImplementation({
      oracle: aaveOracle,
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: 0,
      salt: salt
    });
  }

  function test_getSpokeInstanceInitCodeHash() public view {
    assertEq(
      AaveV4SpokeImplementationDeployProcedure.getSpokeInstanceInitCodeHash(
        spokeBytecode,
        aaveOracle,
        maxUserReservesLimit
      ),
      keccak256(abi.encodePacked(spokeBytecode, abi.encode(aaveOracle, maxUserReservesLimit)))
    );
  }

  function test_deploySpokeImplementation_reverts_alreadyDeployed() public {
    wrapper.deploySpokeImplementation(aaveOracle, spokeBytecode, maxUserReservesLimit, salt);
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    wrapper.deploySpokeImplementation(aaveOracle, spokeBytecode, maxUserReservesLimit, salt);
  }
}
