// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

import {AaveV4EmergencyStewardBatch} from 'src/deployments/batches/AaveV4EmergencyStewardBatch.sol';
import {IEmergencySteward} from 'src/emergency/interfaces/IEmergencySteward.sol';

contract AaveV4EmergencyStewardBatchTest is BatchBaseTest {
  AaveV4EmergencyStewardBatch public emergencyStewardBatch;
  BatchReports.EmergencyStewardBatchReport public report;
  address public spokeConfigurator = makeAddr('spokeConfigurator');

  function setUp() public override {
    super.setUp();
    emergencyStewardBatch = new AaveV4EmergencyStewardBatch({
      authority_: accessManager,
      spokeConfigurator_: spokeConfigurator,
      salt_: salt
    });
    report = emergencyStewardBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.emergencySteward, address(0));
  }

  function test_emergencyStewardAuthority() public view {
    assertEq(IAccessManaged(report.emergencySteward).authority(), accessManager);
  }

  function test_emergencyStewardSpokeConfigurator() public view {
    assertEq(IEmergencySteward(report.emergencySteward).SPOKE_CONFIGURATOR(), spokeConfigurator);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4EmergencyStewardBatch({
      authority_: address(0),
      spokeConfigurator_: spokeConfigurator,
      salt_: keccak256('zeroAuthoritySalt')
    });
  }

  function test_revert_zeroSpokeConfigurator() public {
    vm.expectRevert('invalid spoke configurator');
    new AaveV4EmergencyStewardBatch({
      authority_: accessManager,
      spokeConfigurator_: address(0),
      salt_: keccak256('zeroSpokeConfiguratorSalt')
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4EmergencyStewardBatch newBatch = new AaveV4EmergencyStewardBatch({
      authority_: accessManager,
      spokeConfigurator_: spokeConfigurator,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.emergencySteward, newBatch.getReport().emergencySteward);
  }
}
