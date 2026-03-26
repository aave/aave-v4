// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';
import {AaveV4PositionManagerBatch} from 'src/deployments/batches/AaveV4PositionManagerBatch.sol';
import {GiverPositionManager} from 'src/position-manager/GiverPositionManager.sol';
import {TakerPositionManager} from 'src/position-manager/TakerPositionManager.sol';
import {ConfigPositionManager} from 'src/position-manager/ConfigPositionManager.sol';

contract AaveV4PositionManagerBatchTest is BatchBaseTest {
  AaveV4PositionManagerBatch public batch;
  BatchReports.PositionManagerBatchReport public report;

  function setUp() public override {
    super.setUp();
    batch = new AaveV4PositionManagerBatch({owner_: admin, salt_: salt});
    report = batch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.giverPositionManager, address(0));
    assertNotEq(report.takerPositionManager, address(0));
    assertNotEq(report.configPositionManager, address(0));
  }

  function test_giverPositionManagerOwner() public view {
    assertEq(Ownable(report.giverPositionManager).owner(), admin);
  }

  function test_takerPositionManagerOwner() public view {
    assertEq(Ownable(report.takerPositionManager).owner(), admin);
  }

  function test_configPositionManagerOwner() public view {
    assertEq(Ownable(report.configPositionManager).owner(), admin);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4PositionManagerBatch({owner_: address(0), salt_: salt});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4PositionManagerBatch newBatch = new AaveV4PositionManagerBatch({
      owner_: admin,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.giverPositionManager, newBatch.getReport().giverPositionManager);
    assertNotEq(report.takerPositionManager, newBatch.getReport().takerPositionManager);
    assertNotEq(report.configPositionManager, newBatch.getReport().configPositionManager);
  }
}
