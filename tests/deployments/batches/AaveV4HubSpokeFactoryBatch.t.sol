// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {IHubSpokeFactory} from 'src/deployments/factory/interfaces/IHubSpokeFactory.sol';
import {TreasurySpokeInstance} from 'src/spoke/instances/TreasurySpokeInstance.sol';

contract AaveV4HubSpokeFactoryBatchTest is BatchBaseTest {
  BatchReports.HubSpokeFactoryBatchReport public report;
  address internal hubImplementation;
  address internal spokeImplementation;
  address internal tokenizationSpokeImplementation;

  function setUp() public override {
    super.setUp();
    hubImplementation = new AaveV4HubImplementationBatch(hubBytecode, salt)
      .getReport()
      .hubImplementation;
    spokeImplementation = new AaveV4SpokeImplementationBatch(spokeBytecode, salt)
      .getReport()
      .spokeImplementation;
    tokenizationSpokeImplementation = new AaveV4TokenizationSpokeImplementationBatch(salt)
      .getReport()
      .tokenizationSpokeImplementation;
    report = new AaveV4HubSpokeFactoryBatch(
      hubImplementation,
      spokeImplementation,
      tokenizationSpokeImplementation,
      salt
    ).getReport();
  }

  function test_getReport() public view {
    assertEq(
      report.treasurySpokeImplementation,
      Create2Utils.computeCreate2Address(salt, type(TreasurySpokeInstance).creationCode)
    );
    assertNotEq(report.hubSpokeFactory.code.length, 0);
  }

  function test_factory() public view {
    IHubSpokeFactory factory = IHubSpokeFactory(report.hubSpokeFactory);
    assertEq(factory.HUB_IMPLEMENTATION(), hubImplementation);
    assertEq(factory.SPOKE_IMPLEMENTATION(), spokeImplementation);
    assertEq(factory.TREASURY_SPOKE_IMPLEMENTATION(), report.treasurySpokeImplementation);
    assertEq(factory.TOKENIZATION_SPOKE_IMPLEMENTATION(), tokenizationSpokeImplementation);
  }

  function test_treasurySpokeImplementation() public view {
    assertEq(TreasurySpokeInstance(report.treasurySpokeImplementation).SPOKE_REVISION(), 1);
    assertEq(
      ProxyHelper.getProxyInitializedVersion(report.treasurySpokeImplementation),
      type(uint64).max
    );
  }

  function test_revert_sameSalt() public {
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    new AaveV4HubSpokeFactoryBatch(
      hubImplementation,
      spokeImplementation,
      tokenizationSpokeImplementation,
      salt
    );
  }
}
