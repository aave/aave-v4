// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';
import {HubSpokeFactory} from 'src/factory/HubSpokeFactory.sol';
import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';

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

  function test_deployUpgradeableHubSpokeFactory() public {
    (address proxy, address implementation) = _deploy(hubImpl, spokeImpl);

    assertEq(
      implementation,
      Create2Utils.computeCreate2Address(salt, type(HubSpokeFactory).creationCode)
    );
    assertEq(ProxyHelper.getImplementation(proxy), implementation);
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
    assertEq(ProxyHelper.getProxyInitializedVersion(proxy), 1);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(proxy)).owner(), admin);
    assertEq(IAccessManaged(proxy).authority(), accessManager);

    IHubSpokeFactory factory = IHubSpokeFactory(proxy);
    assertEq(factory.getImplementation(IHubSpokeFactory.InstanceType.Hub), hubImpl);
    assertEq(factory.getImplementation(IHubSpokeFactory.InstanceType.Spoke), spokeImpl);
    assertEq(
      factory.getImplementation(IHubSpokeFactory.InstanceType.TreasurySpoke),
      treasurySpokeImpl
    );
    assertEq(
      factory.getImplementation(IHubSpokeFactory.InstanceType.TokenizationSpoke),
      tokenizationSpokeImpl
    );
  }

  function test_deployUpgradeableHubSpokeFactory_reverts_wrongImplementation() public {
    vm.expectRevert(Create2Utils.FailedCreate2FactoryCall.selector);
    _deploy(spokeImpl, hubImpl);
  }

  function test_deployUpgradeableHubSpokeFactory_reverts_invalidProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    wrapper.deployUpgradeableHubSpokeFactory(
      address(0),
      accessManager,
      hubImpl,
      spokeImpl,
      treasurySpokeImpl,
      tokenizationSpokeImpl,
      salt
    );
  }

  function test_deployUpgradeableHubSpokeFactory_reverts_invalidAuthority() public {
    vm.expectRevert('invalid authority');
    wrapper.deployUpgradeableHubSpokeFactory(
      admin,
      address(0),
      hubImpl,
      spokeImpl,
      treasurySpokeImpl,
      tokenizationSpokeImpl,
      salt
    );
  }

  function _deploy(address hubImpl_, address spokeImpl_) internal returns (address, address) {
    return
      wrapper.deployUpgradeableHubSpokeFactory(
        admin,
        accessManager,
        hubImpl_,
        spokeImpl_,
        treasurySpokeImpl,
        tokenizationSpokeImpl,
        salt
      );
  }
}
