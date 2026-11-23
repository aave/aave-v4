// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';

/// forge-config: default.isolate = true
contract HubSpokeFactoryOperations_Gas_Tests is Base {
  string internal constant NAMESPACE = 'HubSpokeFactory.Operations';

  IHubSpokeFactory internal factory;

  function setUp() public virtual override {
    super.setUp();
    factory = AaveV4TestOrchestration.deployHubSpokeFactory(address(accessManager), ADMIN);
  }

  function test_deployHub() public {
    factory.deployHub('salt', address(accessManager), ADMIN);
    vm.snapshotGasLastCall(NAMESPACE, 'deployHub');
  }

  function test_deploySpoke() public {
    factory.deploySpoke('salt', address(accessManager), MAX_ALLOWED_USER_RESERVES_LIMIT, ADMIN);
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
