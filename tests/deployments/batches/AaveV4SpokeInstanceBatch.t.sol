// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';
import {AaveV4DeployBaseWrapper} from 'tests/helpers/mocks/deployments/AaveV4DeployBaseWrapper.sol';

contract AaveV4SpokeInstanceBatchTest is BatchBaseTest {
  AaveV4SpokeInstanceBatch public spokeBatch;
  BatchReports.SpokeInstanceBatchReport public report;

  function setUp() public override {
    super.setUp();
    spokeBatch = new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      spokeBytecode_: spokeBytecode,
      oracleDecimals_: 8,
      maxUserReservesLimit_: 128,
      salt_: salt
    });
    report = spokeBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.spokeProxy, address(0));
    assertNotEq(report.spokeImplementation, address(0));
    assertNotEq(report.aaveOracle, address(0));
  }

  function test_spokeAuthority() public view {
    assertEq(IAccessManaged(report.spokeProxy).authority(), accessManager);
  }

  function test_spokeOracle() public view {
    assertEq(ISpoke(report.spokeProxy).ORACLE(), report.aaveOracle);
  }

  function test_spokeMaxUserReservesLimit() public view {
    assertEq(ISpoke(report.spokeProxy).MAX_USER_RESERVES_LIMIT(), 128);
  }

  function test_oracleWiring() public view {
    assertEq(IPriceOracle(report.aaveOracle).spoke(), report.spokeProxy);
    assertEq(IPriceOracle(report.aaveOracle).decimals(), 8);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: address(0),
      spokeBytecode_: spokeBytecode,
      oracleDecimals_: 8,
      maxUserReservesLimit_: 128,
      salt_: salt
    });
  }

  function test_revert_zeroProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: address(0),
      authority_: accessManager,
      spokeBytecode_: spokeBytecode,
      oracleDecimals_: 8,
      maxUserReservesLimit_: 128,
      salt_: salt
    });
  }

  function test_revert_zeroOracleDecimals() public {
    vm.expectRevert('invalid oracle decimals');
    new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      spokeBytecode_: spokeBytecode,
      oracleDecimals_: 0,
      maxUserReservesLimit_: 128,
      salt_: keccak256('zeroDecimalsSalt')
    });
  }

  function test_revert_zeroMaxUserReservesLimit() public {
    vm.expectRevert('invalid max user reserves limit');
    new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      spokeBytecode_: spokeBytecode,
      oracleDecimals_: 8,
      maxUserReservesLimit_: 0,
      salt_: keccak256('zeroMaxReservesSalt')
    });
  }

  /// @dev AaveV4DeployBase repeats the batch's input checks because the CREATE2 factory drops revert
  ///      reasons; these mirror the test_revert_* cases above so the two copies cannot drift apart.
  function test_deploySpokeInstanceBatch_revert_zeroAuthority() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid authority');
    deployBase.deploySpokeInstanceBatch({
      proxyAdminOwner: admin,
      authority: address(0),
      spokeBytecode: spokeBytecode,
      oracleDecimals: 8,
      maxUserReservesLimit: 128,
      salt: salt
    });
  }

  function test_deploySpokeInstanceBatch_revert_zeroProxyAdminOwner() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid proxy admin owner');
    deployBase.deploySpokeInstanceBatch({
      proxyAdminOwner: address(0),
      authority: accessManager,
      spokeBytecode: spokeBytecode,
      oracleDecimals: 8,
      maxUserReservesLimit: 128,
      salt: salt
    });
  }

  function test_deploySpokeInstanceBatch_revert_zeroOracleDecimals() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid oracle decimals');
    deployBase.deploySpokeInstanceBatch({
      proxyAdminOwner: admin,
      authority: accessManager,
      spokeBytecode: spokeBytecode,
      oracleDecimals: 0,
      maxUserReservesLimit: 128,
      salt: salt
    });
  }

  function test_deploySpokeInstanceBatch_revert_zeroMaxUserReservesLimit() public {
    AaveV4DeployBaseWrapper deployBase = new AaveV4DeployBaseWrapper();
    vm.expectRevert('invalid max user reserves limit');
    deployBase.deploySpokeInstanceBatch({
      proxyAdminOwner: admin,
      authority: accessManager,
      spokeBytecode: spokeBytecode,
      oracleDecimals: 8,
      maxUserReservesLimit: 0,
      salt: salt
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4SpokeInstanceBatch newBatch = new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      spokeBytecode_: spokeBytecode,
      oracleDecimals_: 8,
      maxUserReservesLimit_: 128,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.spokeProxy, newBatch.getReport().spokeProxy);
  }
}
