// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4SpokeInstanceBatchTest is BatchBaseTest {
  AaveV4SpokeInstanceBatch public spokeBatch;
  BatchReports.SpokeInstanceBatchReport public report;
  address public aaveOracle;
  address public spokeImplementation;

  function setUp() public override {
    super.setUp();
    aaveOracle = _deployBoundOracle(admin, accessManager, salt);
    spokeImplementation = _deploySpokeImplementation(aaveOracle, salt);
    spokeBatch = new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      spokeImplementation_: spokeImplementation,
      salt_: salt
    });
    report = spokeBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.spokeProxy, address(0));
    assertEq(report.spokeImplementation, spokeImplementation);
    assertEq(report.aaveOracle, aaveOracle);
  }

  function test_spokeImplementation() public view {
    assertEq(ProxyHelper.getImplementation(report.spokeProxy), spokeImplementation);
  }

  function test_spokeAuthority() public view {
    assertEq(IAccessManaged(report.spokeProxy).authority(), accessManager);
  }

  function test_spokeOracle() public view {
    assertEq(ISpoke(report.spokeProxy).ORACLE(), aaveOracle);
  }

  function test_spokeMaxUserReservesLimit() public view {
    assertEq(ISpoke(report.spokeProxy).MAX_USER_RESERVES_LIMIT(), 128);
  }

  function test_oracleWiring() public view {
    assertEq(IPriceOracle(aaveOracle).spoke(), report.spokeProxy);
  }

  function test_revert_oracleSpokeMismatch() public {
    bytes32 otherSalt = keccak256('mismatchSalt');
    // the oracle is bound to the proxy predicted for `admin`; deploying the proxy for another owner lands elsewhere
    address oracle = _deployBoundOracle(admin, accessManager, otherSalt);
    address implementation = _deploySpokeImplementation(oracle, otherSalt);
    vm.expectRevert('oracle spoke mismatch');
    new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: makeAddr('otherOwner'),
      authority_: accessManager,
      spokeImplementation_: implementation,
      salt_: otherSalt
    });
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: address(0),
      spokeImplementation_: spokeImplementation,
      salt_: keccak256('zeroAuthoritySalt')
    });
  }

  function test_revert_zeroProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: address(0),
      authority_: accessManager,
      spokeImplementation_: spokeImplementation,
      salt_: keccak256('zeroProxyAdminOwnerSalt')
    });
  }

  function test_revert_invalidSpokeImplementation() public {
    vm.expectRevert('invalid spoke implementation');
    new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      spokeImplementation_: makeAddr('noCode'),
      salt_: keccak256('noCodeSalt')
    });
  }

  function _deployBoundOracle(
    address proxyAdminOwner,
    address authority,
    bytes32 salt_
  ) internal returns (address) {
    return
      new AaveV4AaveOracleBatch({
        proxyAdminOwner_: proxyAdminOwner,
        authority_: authority,
        spokeBytecode_: spokeBytecode,
        oracleDecimals_: 8,
        maxUserReservesLimit_: 128,
        salt_: salt_
      }).getReport().aaveOracle;
  }

  function _deploySpokeImplementation(address oracle, bytes32 salt_) internal returns (address) {
    return
      AaveV4SpokeImplementationDeployProcedure.deploySpokeImplementation({
        oracle: oracle,
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: 128,
        salt: salt_
      });
  }
}
