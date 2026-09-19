// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';
import {Vm} from 'forge-std/Vm.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';

contract AaveV4BabylonSpokeInstanceBatchTest is BatchBaseTest {
  AaveV4BabylonSpokeInstanceBatch public babylonSpokeBatch;
  BatchReports.SpokeInstanceBatchReport public report;
  address public liquidationManager = makeAddr('liquidationManager');

  function setUp() public override {
    super.setUp();
    babylonSpokeBatch = new AaveV4BabylonSpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      liquidationManager_: liquidationManager,
      managedCollateralReserveId_: 0,
      babylonSpokeBytecode_: babylonSpokeBytecode,
      oracleDecimals_: 8,
      salt_: salt
    });
    report = babylonSpokeBatch.getReport();
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

  /// @dev The BabylonSpoke fixes one collateral and one debt reserve per user.
  function test_spokeMaxUserReservesLimit() public view {
    assertEq(ISpoke(report.spokeProxy).MAX_USER_RESERVES_LIMIT(), 1);
  }

  function test_spokeImmutables() public view {
    IBabylonSpoke babylonSpoke = IBabylonSpoke(report.spokeProxy);
    assertEq(babylonSpoke.LIQUIDATION_MANAGER(), liquidationManager);
    assertEq(babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID(), 0);
  }

  /// @dev The instance reports its immutables on initialization.
  function test_initializeEmitsBabylonImmutables() public {
    vm.recordLogs();
    AaveV4BabylonSpokeInstanceBatch newBatch = new AaveV4BabylonSpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      liquidationManager_: liquidationManager,
      managedCollateralReserveId_: 7,
      babylonSpokeBytecode_: babylonSpokeBytecode,
      oracleDecimals_: 8,
      salt_: keccak256('immutablesSalt')
    });
    address spokeProxy = newBatch.getReport().spokeProxy;

    Vm.Log[] memory logs = vm.getRecordedLogs();
    bool found;
    for (uint256 i; i < logs.length; ++i) {
      if (
        logs[i].emitter == spokeProxy &&
        logs[i].topics[0] == IBabylonSpoke.SetBabylonSpokeImmutables.selector
      ) {
        (address manager, uint256 reserveId) = abi.decode(logs[i].data, (address, uint256));
        assertEq(manager, liquidationManager, 'emitted liquidation manager');
        assertEq(reserveId, 7, 'emitted managed collateral reserve id');
        found = true;
      }
    }
    assertTrue(found, 'SetBabylonSpokeImmutables emitted');
  }

  function test_oracleWiring() public view {
    assertEq(IPriceOracle(report.aaveOracle).spoke(), report.spokeProxy);
    assertEq(IPriceOracle(report.aaveOracle).decimals(), 8);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4BabylonSpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: address(0),
      liquidationManager_: liquidationManager,
      managedCollateralReserveId_: 0,
      babylonSpokeBytecode_: babylonSpokeBytecode,
      oracleDecimals_: 8,
      salt_: salt
    });
  }

  function test_revert_zeroLiquidationManager() public {
    vm.expectRevert('invalid liquidation manager');
    new AaveV4BabylonSpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      liquidationManager_: address(0),
      managedCollateralReserveId_: 0,
      babylonSpokeBytecode_: babylonSpokeBytecode,
      oracleDecimals_: 8,
      salt_: salt
    });
  }

  function test_revert_zeroProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    new AaveV4BabylonSpokeInstanceBatch({
      proxyAdminOwner_: address(0),
      authority_: accessManager,
      liquidationManager_: liquidationManager,
      managedCollateralReserveId_: 0,
      babylonSpokeBytecode_: babylonSpokeBytecode,
      oracleDecimals_: 8,
      salt_: salt
    });
  }

  function test_revert_zeroOracleDecimals() public {
    vm.expectRevert('invalid oracle decimals');
    new AaveV4BabylonSpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      liquidationManager_: liquidationManager,
      managedCollateralReserveId_: 0,
      babylonSpokeBytecode_: babylonSpokeBytecode,
      oracleDecimals_: 0,
      salt_: keccak256('zeroDecimalsSalt')
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4BabylonSpokeInstanceBatch newBatch = new AaveV4BabylonSpokeInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      liquidationManager_: liquidationManager,
      managedCollateralReserveId_: 0,
      babylonSpokeBytecode_: babylonSpokeBytecode,
      oracleDecimals_: 8,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.spokeProxy, newBatch.getReport().spokeProxy);
  }
}
