// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';
import {IHubSpokeFactory} from 'src/deployments/factory/interfaces/IHubSpokeFactory.sol';

contract AaveV4HubSpokeFactoryDeployProcedureTest is ProceduresBase {
  AaveV4HubSpokeFactoryDeployProcedureWrapper public wrapper;
  address internal hubImpl;
  address internal spokeImpl;
  address internal treasurySpokeImpl;
  address internal tokenizationSpokeImpl;

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4HubSpokeFactoryDeployProcedureWrapper();
    hubImpl = new AaveV4HubDeployProcedureWrapper().deployHubImplementation(hubBytecode, salt);
    spokeImpl = new AaveV4SpokeDeployProcedureWrapper().deploySpokeImplementation(
      spokeBytecode,
      salt
    );
    treasurySpokeImpl = new AaveV4TreasurySpokeDeployProcedureWrapper()
      .deployTreasurySpokeImplementation(salt);
    tokenizationSpokeImpl = new AaveV4TokenizationSpokeDeployProcedureWrapper()
      .deployTokenizationSpokeImplementation(salt);
  }

  function test_deployHubSpokeFactory() public {
    IHubSpokeFactory factory = IHubSpokeFactory(
      wrapper.deployHubSpokeFactory(
        hubImpl,
        spokeImpl,
        treasurySpokeImpl,
        tokenizationSpokeImpl,
        salt
      )
    );
    assertEq(factory.HUB_IMPLEMENTATION(), hubImpl);
    assertEq(factory.SPOKE_IMPLEMENTATION(), spokeImpl);
    assertEq(factory.TREASURY_SPOKE_IMPLEMENTATION(), treasurySpokeImpl);
    assertEq(factory.TOKENIZATION_SPOKE_IMPLEMENTATION(), tokenizationSpokeImpl);
  }

  function test_deployHubSpokeFactory_reverts_wrongImplementation() public {
    vm.expectRevert(Create2Utils.FailedCreate2FactoryCall.selector);
    wrapper.deployHubSpokeFactory(
      spokeImpl,
      hubImpl,
      treasurySpokeImpl,
      tokenizationSpokeImpl,
      salt
    );
  }
}
