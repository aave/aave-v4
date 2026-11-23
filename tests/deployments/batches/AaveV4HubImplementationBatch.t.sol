// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';

contract AaveV4HubImplementationBatchTest is BatchBaseTest {
  BatchReports.HubImplementationBatchReport public report;

  function setUp() public override {
    super.setUp();
    report = new AaveV4HubImplementationBatch(hubBytecode, salt).getReport();
  }

  function test_getReport() public view {
    assertEq(report.hubImplementation, Create2Utils.computeCreate2Address(salt, hubBytecode));
  }

  function test_implementation() public view {
    assertEq(IHubInstance(report.hubImplementation).HUB_REVISION(), 1);
    assertEq(ProxyHelper.getProxyInitializedVersion(report.hubImplementation), type(uint64).max);
  }

  function test_revert_sameSalt() public {
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    new AaveV4HubImplementationBatch(hubBytecode, salt);
  }
}
