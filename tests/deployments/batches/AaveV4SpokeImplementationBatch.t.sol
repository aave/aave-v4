// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';

contract AaveV4SpokeImplementationBatchTest is BatchBaseTest {
  BatchReports.SpokeImplementationBatchReport public report;

  function setUp() public override {
    super.setUp();
    report = new AaveV4SpokeImplementationBatch(spokeBytecode, salt).getReport();
  }

  function test_getReport() public view {
    assertEq(report.spokeImplementation, Create2Utils.computeCreate2Address(salt, spokeBytecode));
  }

  function test_implementation() public view {
    ISpokeInstance implementation = ISpokeInstance(report.spokeImplementation);
    assertEq(implementation.SPOKE_REVISION(), 2);
    assertEq(ProxyHelper.getProxyInitializedVersion(address(implementation)), type(uint64).max);
    assertEq(implementation.ORACLE(), address(0));
    assertEq(implementation.MAX_USER_RESERVES_LIMIT(), 0);
  }

  function test_revert_sameSalt() public {
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    new AaveV4SpokeImplementationBatch(spokeBytecode, salt);
  }
}
