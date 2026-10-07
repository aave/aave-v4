// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

contract AaveV4TokenizationSpokeImplementationBatchTest is BatchBaseTest {
  BatchReports.TokenizationSpokeImplementationBatchReport public report;

  function setUp() public override {
    super.setUp();
    report = new AaveV4TokenizationSpokeImplementationBatch(salt).getReport();
  }

  function test_getReport() public view {
    assertEq(
      report.tokenizationSpokeImplementation,
      Create2Utils.computeCreate2Address(salt, type(TokenizationSpokeInstance).creationCode)
    );
  }

  function test_implementation() public view {
    address implementation = report.tokenizationSpokeImplementation;
    assertEq(TokenizationSpokeInstance(implementation).SPOKE_REVISION(), 2);
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
    assertEq(ITokenizationSpoke(implementation).hub(), address(0));
    assertEq(ITokenizationSpoke(implementation).asset(), address(0));
  }

  function test_differentSaltProducesDifferentAddress() public {
    assertNotEq(
      report.tokenizationSpokeImplementation,
      new AaveV4TokenizationSpokeImplementationBatch(keccak256('differentSalt'))
        .getReport()
        .tokenizationSpokeImplementation
    );
  }

  function test_revert_sameSalt() public {
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    new AaveV4TokenizationSpokeImplementationBatch(salt);
  }
}
