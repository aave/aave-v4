// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {HubSpokeFactory} from 'src/deployments/factory/HubSpokeFactory.sol';
import {IHubSpokeFactory} from 'src/deployments/factory/interfaces/IHubSpokeFactory.sol';
import {MockTokenizationSpokeInstance} from 'tests/helpers/mocks/MockTokenizationSpokeInstance.sol';

contract HubSpokeFactoryTest is Base {
  string internal constant SHARE_NAME = 'Core Hub DAI';
  string internal constant SHARE_SYMBOL = 'chDAI';

  address internal deployer = makeAddr('deployer');
  address internal authority = makeAddr('authority');
  address internal proxyAdminOwner = makeAddr('proxyAdminOwner');
  address internal treasuryOwner = makeAddr('treasuryOwner');

  address internal hubImpl;
  address internal spokeImpl;
  address internal treasurySpokeImpl;
  address internal tokenizationSpokeImpl;

  HubSpokeFactory internal factory;

  function setUp() public override {
    super.setUp();
    hubImpl = address(AaveV4TestOrchestration.deployHubImplementation());
    spokeImpl = address(AaveV4TestOrchestration.deploySpokeImplementation());
    treasurySpokeImpl = address(new TreasurySpokeInstance());
    tokenizationSpokeImpl = address(new TokenizationSpokeInstance());
    factory = new HubSpokeFactory({
      hubImplementation_: hubImpl,
      spokeImplementation_: spokeImpl,
      treasurySpokeImplementation_: treasurySpokeImpl,
      tokenizationSpokeImplementation_: tokenizationSpokeImpl
    });
  }

  function test_constructor() public view {
    assertEq(factory.HUB_IMPLEMENTATION(), hubImpl);
    assertEq(factory.SPOKE_IMPLEMENTATION(), spokeImpl);
    assertEq(factory.TREASURY_SPOKE_IMPLEMENTATION(), treasurySpokeImpl);
    assertEq(factory.TOKENIZATION_SPOKE_IMPLEMENTATION(), tokenizationSpokeImpl);
    assertEq(factory.ORACLE_DECIMALS(), 8);
    assertEq(factory.MAX_USER_RESERVES_LIMIT(), MAX_ALLOWED_USER_RESERVES_LIMIT);
  }

  function test_runtimeSize() public view {
    assertLe(address(factory).code.length, 24_576);
  }

  function test_constructor_revertsWith_InvalidImplementation_hubRevision0() public {
    address hubImplRevision0 = address(new MockHubInstance(0));
    vm.expectRevert(IHubSpokeFactory.InvalidImplementation.selector);
    new HubSpokeFactory(hubImplRevision0, spokeImpl, treasurySpokeImpl, tokenizationSpokeImpl);
  }

  function test_constructor_revertsWith_InvalidImplementation_spokeRevision1() public {
    address legacySpokeImpl = address(new MockSpokeInstance(1));
    vm.expectRevert(IHubSpokeFactory.InvalidImplementation.selector);
    new HubSpokeFactory(hubImpl, legacySpokeImpl, treasurySpokeImpl, tokenizationSpokeImpl);
  }

  function test_constructor_revertsWith_InvalidImplementation_tokenizationSpokeRevision1() public {
    address legacyTokenizationSpokeImpl = address(new MockTokenizationSpokeInstance(1));
    vm.expectRevert(IHubSpokeFactory.InvalidImplementation.selector);
    new HubSpokeFactory(hubImpl, spokeImpl, treasurySpokeImpl, legacyTokenizationSpokeImpl);
  }

  function test_constructor_revertsWith_InvalidImplementation_treasurySpokeRevision0() public {
    address treasurySpokeImplRevision0 = address(new MockTreasurySpokeInstance(0));
    vm.expectRevert(IHubSpokeFactory.InvalidImplementation.selector);
    new HubSpokeFactory(hubImpl, spokeImpl, treasurySpokeImplRevision0, tokenizationSpokeImpl);
  }

  /// @dev Each slot is filled with every other canonical implementation, and with addresses without code.
  function test_constructor_reverts_wrongImplementations() public {
    address[5] memory candidates = [
      hubImpl,
      spokeImpl,
      treasurySpokeImpl,
      tokenizationSpokeImpl,
      makeAddr('noCode')
    ];
    for (uint256 slot; slot < 4; ++slot) {
      for (uint256 i; i < candidates.length; ++i) {
        if (i == slot) continue;
        address[4] memory impls = [hubImpl, spokeImpl, treasurySpokeImpl, tokenizationSpokeImpl];
        impls[slot] = candidates[i];
        vm.expectRevert();
        new HubSpokeFactory(impls[0], impls[1], impls[2], impls[3]);
      }
    }
  }

  function test_deployHub() public {
    bytes32 salt = 'hub';
    IHubSpokeFactory.HubDeployment memory predicted = factory.predictHub(
      deployer,
      salt,
      authority,
      proxyAdminOwner
    );

    vm.expectEmit(address(factory));
    emit IHubSpokeFactory.HubDeployed(
      deployer,
      predicted.proxy,
      predicted.irStrategy,
      authority,
      proxyAdminOwner
    );
    vm.prank(deployer);
    IHubSpokeFactory.HubDeployment memory deployment = factory.deployHub(
      salt,
      authority,
      proxyAdminOwner
    );

    assertEq(deployment.proxy, predicted.proxy);
    assertEq(deployment.irStrategy, predicted.irStrategy);
    _assertProxy(deployment.proxy, hubImpl, 1);
    assertEq(IAccessManaged(deployment.proxy).authority(), authority);
    assertEq(AssetInterestRateStrategy(deployment.irStrategy).HUB(), deployment.proxy);
  }

  function test_deploySpoke() public {
    bytes32 salt = 'spoke';
    IHubSpokeFactory.SpokeDeployment memory predicted = factory.predictSpoke(
      deployer,
      salt,
      authority,
      proxyAdminOwner
    );

    vm.expectEmit(address(factory));
    emit IHubSpokeFactory.SpokeDeployed(
      deployer,
      predicted.proxy,
      predicted.oracle,
      authority,
      proxyAdminOwner
    );
    vm.prank(deployer);
    IHubSpokeFactory.SpokeDeployment memory deployment = factory.deploySpoke(
      salt,
      authority,
      proxyAdminOwner
    );

    assertEq(deployment.proxy, predicted.proxy);
    assertEq(deployment.oracle, predicted.oracle);
    _assertProxy(deployment.proxy, spokeImpl, 2);
    ISpoke spoke = ISpoke(deployment.proxy);
    assertEq(IAccessManaged(deployment.proxy).authority(), authority);
    assertEq(spoke.ORACLE(), deployment.oracle);
    assertEq(spoke.MAX_USER_RESERVES_LIMIT(), MAX_ALLOWED_USER_RESERVES_LIMIT);
    assertEq(spoke.getLiquidationConfig().targetHealthFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    assertEq(IAaveOracle(deployment.oracle).spoke(), deployment.proxy);
    assertEq(IAaveOracle(deployment.oracle).decimals(), 8);

    vm.expectRevert(IAaveOracle.SpokeAlreadySet.selector);
    vm.prank(address(factory));
    IAaveOracle(deployment.oracle).setSpoke(deployment.proxy);
  }

  function test_deployTreasurySpoke() public {
    bytes32 salt = 'treasury';
    address predicted = factory.predictTreasurySpoke(
      deployer,
      salt,
      treasuryOwner,
      proxyAdminOwner
    );

    vm.expectEmit(address(factory));
    emit IHubSpokeFactory.TreasurySpokeDeployed(
      deployer,
      predicted,
      treasuryOwner,
      proxyAdminOwner
    );
    vm.prank(deployer);
    address proxy = factory.deployTreasurySpoke(salt, treasuryOwner, proxyAdminOwner);

    assertEq(proxy, predicted);
    _assertProxy(proxy, treasurySpokeImpl, 1);
    assertEq(Ownable(proxy).owner(), treasuryOwner);
  }

  function test_deployTokenizationSpoke() public {
    bytes32 salt = 'tokenization';
    address underlying = address(tokenList.dai);
    address predicted = factory.predictTokenizationSpoke(
      deployer,
      salt,
      address(hub1),
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      proxyAdminOwner
    );

    vm.expectEmit(address(factory));
    emit IHubSpokeFactory.TokenizationSpokeDeployed(
      deployer,
      predicted,
      address(hub1),
      underlying,
      proxyAdminOwner
    );
    vm.prank(deployer);
    address proxy = factory.deployTokenizationSpoke(
      salt,
      address(hub1),
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      proxyAdminOwner
    );

    assertEq(proxy, predicted);
    _assertProxy(proxy, tokenizationSpokeImpl, 2);
    ITokenizationSpoke tokenizationSpoke = ITokenizationSpoke(proxy);
    assertEq(tokenizationSpoke.hub(), address(hub1));
    assertEq(tokenizationSpoke.asset(), underlying);
    assertEq(tokenizationSpoke.assetId(), daiAssetId);
    assertEq(tokenizationSpoke.name(), SHARE_NAME);
    assertEq(tokenizationSpoke.symbol(), SHARE_SYMBOL);
  }

  function test_predict_fuzz(address caller, bytes32 salt, address owner) public {
    vm.assume(caller != address(0) && owner != address(0));

    vm.startPrank(caller);
    IHubSpokeFactory.HubDeployment memory hubPredicted = factory.predictHub(
      caller,
      salt,
      authority,
      owner
    );
    IHubSpokeFactory.HubDeployment memory hubDeployed = factory.deployHub(salt, authority, owner);
    assertEq(hubDeployed.proxy, hubPredicted.proxy);
    assertEq(hubDeployed.irStrategy, hubPredicted.irStrategy);

    IHubSpokeFactory.SpokeDeployment memory spokePredicted = factory.predictSpoke(
      caller,
      salt,
      authority,
      owner
    );
    IHubSpokeFactory.SpokeDeployment memory spokeDeployed = factory.deploySpoke(
      salt,
      authority,
      owner
    );
    assertEq(spokeDeployed.proxy, spokePredicted.proxy);
    assertEq(spokeDeployed.oracle, spokePredicted.oracle);

    assertEq(
      factory.deployTreasurySpoke(salt, owner, owner),
      factory.predictTreasurySpoke(caller, salt, owner, owner)
    );

    address underlying = address(tokenList.dai);
    assertEq(
      factory.deployTokenizationSpoke(
        salt,
        address(hub1),
        underlying,
        SHARE_NAME,
        SHARE_SYMBOL,
        owner
      ),
      factory.predictTokenizationSpoke(
        caller,
        salt,
        address(hub1),
        underlying,
        SHARE_NAME,
        SHARE_SYMBOL,
        owner
      )
    );
    vm.stopPrank();
  }

  function test_deploy_reverts_reusedSalt() public {
    bytes32 salt = 'salt';
    address underlying = address(tokenList.dai);
    vm.startPrank(deployer);
    factory.deployHub(salt, authority, proxyAdminOwner);
    factory.deploySpoke(salt, authority, proxyAdminOwner);
    factory.deployTreasurySpoke(salt, treasuryOwner, proxyAdminOwner);
    factory.deployTokenizationSpoke(
      salt,
      address(hub1),
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      proxyAdminOwner
    );

    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deployHub(salt, authority, proxyAdminOwner);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deploySpoke(salt, authority, proxyAdminOwner);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deployTreasurySpoke(salt, treasuryOwner, proxyAdminOwner);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deployTokenizationSpoke(
      salt,
      address(hub1),
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      proxyAdminOwner
    );
    vm.stopPrank();
  }

  function test_deployHub_revertsWith_SaltAlreadyUsed_irStrategy() public {
    IHubSpokeFactory.HubDeployment memory predicted = factory.predictHub(
      deployer,
      'salt',
      authority,
      proxyAdminOwner
    );
    vm.etch(predicted.irStrategy, hex'00');

    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    vm.prank(deployer);
    factory.deployHub('salt', authority, proxyAdminOwner);
  }

  function test_deploySpoke_revertsWith_SaltAlreadyUsed_oracle() public {
    IHubSpokeFactory.SpokeDeployment memory predicted = factory.predictSpoke(
      deployer,
      'salt',
      authority,
      proxyAdminOwner
    );
    vm.etch(predicted.oracle, hex'00');

    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    vm.prank(deployer);
    factory.deploySpoke('salt', authority, proxyAdminOwner);
  }

  function test_deploy_revertsWith_SaltAlreadyUsed_proxy() public {
    address underlying = address(tokenList.dai);
    vm.etch(factory.predictHub(deployer, 'salt', authority, proxyAdminOwner).proxy, hex'00');
    vm.etch(factory.predictSpoke(deployer, 'salt', authority, proxyAdminOwner).proxy, hex'00');
    vm.etch(
      factory.predictTreasurySpoke(deployer, 'salt', treasuryOwner, proxyAdminOwner),
      hex'00'
    );
    vm.etch(
      factory.predictTokenizationSpoke(
        deployer,
        'salt',
        address(hub1),
        underlying,
        SHARE_NAME,
        SHARE_SYMBOL,
        proxyAdminOwner
      ),
      hex'00'
    );

    vm.startPrank(deployer);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deployHub('salt', authority, proxyAdminOwner);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deploySpoke('salt', authority, proxyAdminOwner);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deployTreasurySpoke('salt', treasuryOwner, proxyAdminOwner);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deployTokenizationSpoke(
      'salt',
      address(hub1),
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      proxyAdminOwner
    );
    vm.stopPrank();
  }

  function test_deploy_sameSaltDifferentCallers() public {
    bytes32 salt = 'salt';
    address otherDeployer = makeAddr('otherDeployer');

    vm.prank(deployer);
    IHubSpokeFactory.SpokeDeployment memory first = factory.deploySpoke(
      salt,
      authority,
      proxyAdminOwner
    );
    vm.prank(otherDeployer);
    IHubSpokeFactory.SpokeDeployment memory second = factory.deploySpoke(
      salt,
      authority,
      proxyAdminOwner
    );

    assertNotEq(first.proxy, second.proxy);
    assertNotEq(first.oracle, second.oracle);
  }

  function test_deployHub_reverts_zeroAuthority() public {
    vm.expectRevert(IHub.InvalidAddress.selector);
    factory.deployHub('salt', address(0), proxyAdminOwner);
  }

  function test_deploySpoke_reverts_zeroAuthority() public {
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    factory.deploySpoke('salt', address(0), proxyAdminOwner);
  }

  function test_deployTreasurySpoke_reverts_zeroOwner() public {
    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0))
    );
    factory.deployTreasurySpoke('salt', address(0), proxyAdminOwner);
  }

  function test_deploy_reverts_zeroProxyAdminOwner() public {
    bytes memory expectedError = abi.encodeWithSelector(
      Ownable.OwnableInvalidOwner.selector,
      address(0)
    );
    vm.expectRevert(expectedError);
    factory.deployHub('salt', authority, address(0));
    vm.expectRevert(expectedError);
    factory.deploySpoke('salt', authority, address(0));
    vm.expectRevert(expectedError);
    factory.deployTreasurySpoke('salt', treasuryOwner, address(0));
    vm.expectRevert(expectedError);
    factory.deployTokenizationSpoke(
      'salt',
      address(hub1),
      address(tokenList.dai),
      SHARE_NAME,
      SHARE_SYMBOL,
      address(0)
    );
  }

  function _assertProxy(address proxy, address implementation, uint64 revision) internal view {
    assertEq(ProxyHelper.getImplementation(proxy), implementation);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(proxy)).owner(), proxyAdminOwner);
    assertEq(ProxyHelper.getProxyInitializedVersion(proxy), revision);
  }
}
