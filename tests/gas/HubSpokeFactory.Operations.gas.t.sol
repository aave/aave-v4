// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {HubSpokeFactory} from 'src/deployments/factory/HubSpokeFactory.sol';

/// forge-config: default.isolate = true
contract HubSpokeFactoryOperations_Gas_Tests is Base {
  string internal constant NAMESPACE = 'HubSpokeFactory.Operations';

  HubSpokeFactory internal factory;

  function setUp() public virtual override {
    super.setUp();
    factory = new HubSpokeFactory({
      hubImplementation_: address(AaveV4TestOrchestration.deployHubImplementation()),
      spokeImplementation_: address(AaveV4TestOrchestration.deploySpokeImplementation()),
      treasurySpokeImplementation_: address(new TreasurySpokeInstance()),
      tokenizationSpokeImplementation_: address(new TokenizationSpokeInstance())
    });
  }

  function test_deployHub() public {
    factory.deployHub('salt', address(accessManager), ADMIN);
    vm.snapshotGasLastCall(NAMESPACE, 'deployHub');
  }

  function test_deploySpoke() public {
    factory.deploySpoke('salt', address(accessManager), ADMIN);
    vm.snapshotGasLastCall(NAMESPACE, 'deploySpoke');
  }

  function test_deployTreasurySpoke() public {
    factory.deployTreasurySpoke('salt', ADMIN, ADMIN);
    vm.snapshotGasLastCall(NAMESPACE, 'deployTreasurySpoke');
  }

  function test_deployTokenizationSpoke() public {
    factory.deployTokenizationSpoke(
      'salt',
      address(hub1),
      address(tokenList.dai),
      'Core Hub DAI',
      'chDAI',
      ADMIN
    );
    vm.snapshotGasLastCall(NAMESPACE, 'deployTokenizationSpoke');
  }
}
