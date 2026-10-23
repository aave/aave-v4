// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4AaveOracleBatchTest is BatchBaseTest {
  AaveV4AaveOracleBatch public oracleBatch;
  BatchReports.AaveOracleBatchReport public report;

  function setUp() public override {
    super.setUp();
    oracleBatch = _deployOracleBatch({
      proxyAdminOwner: admin,
      authority: accessManager,
      oracleDecimals: 8,
      maxUserReservesLimit: 128,
      salt_: salt
    });
    report = oracleBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.aaveOracle, address(0));
    assertNotEq(report.spokeImplementation, address(0));
    assertNotEq(report.spokeProxy, address(0));
  }

  function test_oracle() public view {
    assertEq(IAaveOracle(report.aaveOracle).decimals(), 8);
    assertEq(
      report.aaveOracle,
      vm.computeCreate2Address(
        salt,
        keccak256(abi.encodePacked(type(AaveOracle).creationCode, abi.encode(uint8(8)))),
        address(oracleBatch)
      )
    );
  }

  function test_oracleBoundToPredictedSpokeProxy() public view {
    assertEq(IAaveOracle(report.aaveOracle).spoke(), report.spokeProxy);
    assertEq(report.spokeProxy.code.length, 0);
  }

  function test_predictionMatchesDeployment() public {
    address spokeImplementation = AaveV4SpokeImplementationDeployProcedure
      .deploySpokeImplementation({
        oracle: report.aaveOracle,
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: 128,
        salt: salt
      });
    assertEq(spokeImplementation, report.spokeImplementation);

    AaveV4SpokeInstanceBatch spokeBatch = new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      spokeImplementation_: spokeImplementation,
      salt_: salt
    });
    assertEq(spokeBatch.getReport().spokeProxy, report.spokeProxy);
    assertEq(ISpoke(report.spokeProxy).ORACLE(), report.aaveOracle);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    _deployOracleBatch(admin, address(0), 8, 128, keccak256('zeroAuthoritySalt'));
  }

  function test_revert_zeroProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    _deployOracleBatch(address(0), accessManager, 8, 128, keccak256('zeroOwnerSalt'));
  }

  function test_revert_zeroOracleDecimals() public {
    vm.expectRevert('invalid oracle decimals');
    _deployOracleBatch(admin, accessManager, 0, 128, keccak256('zeroDecimalsSalt'));
  }

  function test_revert_zeroMaxUserReservesLimit() public {
    vm.expectRevert('invalid max user reserves limit');
    _deployOracleBatch(admin, accessManager, 8, 0, keccak256('zeroLimitSalt'));
  }

  /// @dev AaveV4DeployBase repeats the batch's input checks because the CREATE2 factory drops revert
  ///      reasons; these mirror the test_revert_* cases above so the two copies cannot drift apart.
  function test_deployAaveOracleBatch_revert_zeroAuthority() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid authority');
    deployBase.deployAaveOracleBatch(admin, address(0), spokeBytecode, 8, 128, salt);
  }

  function test_deployAaveOracleBatch_revert_zeroProxyAdminOwner() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid proxy admin owner');
    deployBase.deployAaveOracleBatch(address(0), accessManager, spokeBytecode, 8, 128, salt);
  }

  function test_deployAaveOracleBatch_revert_zeroOracleDecimals() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid oracle decimals');
    deployBase.deployAaveOracleBatch(admin, accessManager, spokeBytecode, 0, 128, salt);
  }

  function test_deployAaveOracleBatch_revert_zeroMaxUserReservesLimit() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid max user reserves limit');
    deployBase.deployAaveOracleBatch(admin, accessManager, spokeBytecode, 8, 0, salt);
  }

  function test_differentSaltProducesDifferentAddresses() public {
    BatchReports.AaveOracleBatchReport memory other = _deployOracleBatch(
      admin,
      accessManager,
      8,
      128,
      keccak256('differentSalt')
    ).getReport();
    assertNotEq(report.aaveOracle, other.aaveOracle);
    assertNotEq(report.spokeProxy, other.spokeProxy);
  }

  function _deployOracleBatch(
    address proxyAdminOwner,
    address authority,
    uint8 oracleDecimals,
    uint16 maxUserReservesLimit,
    bytes32 salt_
  ) internal returns (AaveV4AaveOracleBatch) {
    return
      new AaveV4AaveOracleBatch({
        proxyAdminOwner_: proxyAdminOwner,
        authority_: authority,
        spokeBytecode_: spokeBytecode,
        oracleDecimals_: oracleDecimals,
        maxUserReservesLimit_: maxUserReservesLimit,
        salt_: salt_
      });
  }
}
