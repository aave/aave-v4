// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4AaveOracleBatchTest is BatchBaseTest {
  AaveV4AaveOracleBatch public oracleBatch;
  BatchReports.AaveOracleBatchReport public report;

  function setUp() public override {
    super.setUp();
    oracleBatch = new AaveV4AaveOracleBatch({owner_: admin, oracleDecimals_: 8, salt_: salt});
    report = oracleBatch.getReport();
  }

  function test_getReport() public view {
    assertEq(report.aaveOracleBatch, address(oracleBatch));
    assertNotEq(report.aaveOracle, address(0));
  }

  function test_owner() public view {
    assertEq(oracleBatch.OWNER(), admin);
  }

  function test_oracle() public view {
    assertEq(IAaveOracle(report.aaveOracle).decimals(), 8);
    assertEq(IAaveOracle(report.aaveOracle).spoke(), address(0));
    assertEq(
      report.aaveOracle,
      vm.computeCreate2Address(
        salt,
        keccak256(abi.encodePacked(type(AaveOracle).creationCode, abi.encode(uint8(8)))),
        address(oracleBatch)
      )
    );
  }

  function test_setSpoke() public {
    address spokeProxy = _deploySpoke(report.aaveOracle);
    vm.prank(admin);
    oracleBatch.setSpoke(spokeProxy);
    assertEq(IAaveOracle(report.aaveOracle).spoke(), spokeProxy);
  }

  function test_setSpoke_revert_notOwner() public {
    address spokeProxy = _deploySpoke(report.aaveOracle);
    vm.expectRevert('only owner');
    vm.prank(makeAddr('notOwner'));
    oracleBatch.setSpoke(spokeProxy);
  }

  function test_setSpoke_revert_alreadySet() public {
    address spokeProxy = _deploySpoke(report.aaveOracle);
    vm.startPrank(admin);
    oracleBatch.setSpoke(spokeProxy);
    vm.expectRevert(IAaveOracle.SpokeAlreadySet.selector);
    oracleBatch.setSpoke(spokeProxy);
    vm.stopPrank();
  }

  function test_setSpoke_revert_oracleMismatch() public {
    address otherOracle = new AaveV4AaveOracleBatch({
      owner_: admin,
      oracleDecimals_: 8,
      salt_: keccak256('otherSalt')
    }).getReport().aaveOracle;
    address otherSpoke = _deploySpoke(otherOracle);
    vm.expectRevert(IAaveOracle.OracleMismatch.selector);
    vm.prank(admin);
    oracleBatch.setSpoke(otherSpoke);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4AaveOracleBatch({
      owner_: address(0),
      oracleDecimals_: 8,
      salt_: keccak256('zeroOwnerSalt')
    });
  }

  function test_revert_zeroOracleDecimals() public {
    vm.expectRevert('invalid oracle decimals');
    new AaveV4AaveOracleBatch({owner_: admin, oracleDecimals_: 0, salt_: keccak256('zeroSalt')});
  }

  /// @dev AaveV4DeployBase repeats the batch's input checks because the CREATE2 factory drops revert
  ///      reasons; these mirror the test_revert_* cases above so the two copies cannot drift apart.
  function test_deployAaveOracleBatch_revert_zeroOwner() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid owner');
    deployBase.deployAaveOracleBatch({owner: address(0), oracleDecimals: 8, salt: salt});
  }

  function test_deployAaveOracleBatch_revert_zeroOracleDecimals() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid oracle decimals');
    deployBase.deployAaveOracleBatch({owner: admin, oracleDecimals: 0, salt: salt});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4AaveOracleBatch newBatch = new AaveV4AaveOracleBatch({
      owner_: admin,
      oracleDecimals_: 8,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.aaveOracle, newBatch.getReport().aaveOracle);
  }

  function _deploySpoke(address oracle) internal returns (address) {
    bytes32 spokeSalt = keccak256(abi.encode(oracle));
    address implementation = AaveV4SpokeImplementationDeployProcedure.deploySpokeImplementation({
      oracle: oracle,
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: 128,
      salt: spokeSalt
    });
    return
      new AaveV4SpokeInstanceBatch({
        proxyAdminOwner_: admin,
        authority_: accessManager,
        spokeImplementation_: implementation,
        spokeInitCodeHash_: keccak256(
          AaveV4SpokeImplementationDeployProcedure.getSpokeInstanceInitCode(
            spokeBytecode,
            oracle,
            128
          )
        ),
        salt_: spokeSalt
      }).getReport().spokeProxy;
  }
}
