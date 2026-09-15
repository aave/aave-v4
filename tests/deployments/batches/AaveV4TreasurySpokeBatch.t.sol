// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4TreasurySpokeBatchTest is BatchBaseTest {
  AaveV4TreasurySpokeBatch public treasurySpokeBatch;
  BatchReports.TreasurySpokeBatchReport public report;

  function setUp() public override {
    super.setUp();
    treasurySpokeBatch = new AaveV4TreasurySpokeBatch({owner_: admin, salt_: salt, hub_: TreasurySpokeHub});
    report = treasurySpokeBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.treasurySpoke, address(0));
  }

  function test_treasurySpokeOwner() public view {
    assertEq(Ownable(report.treasurySpoke).owner(), admin);
  }

  function test_proxyAdminOwner() public view {
    assertEq(Ownable(ProxyHelper.getProxyAdmin(report.treasurySpoke)).owner(), admin);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4TreasurySpokeBatch({owner_: address(0), salt_: keccak256('zeroOwnerSalt'), hub_: address(0)});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4TreasurySpokeBatch newBatch = new AaveV4TreasurySpokeBatch({
      owner_: admin,
      salt_: keccak256('differentSalt'),
      hub_: TreasurySpokeHub
    });
    assertNotEq(report.treasurySpoke, newBatch.getReport().treasurySpoke);
  }
}
