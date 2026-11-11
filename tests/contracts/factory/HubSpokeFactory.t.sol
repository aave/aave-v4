// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {HubSpokeFactory} from 'src/factory/HubSpokeFactory.sol';
import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';
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

  address internal factoryImpl;
  HubSpokeFactory internal factory;

  function setUp() public override {
    super.setUp();
    hubImpl = address(AaveV4TestOrchestration.deployHubImplementation());
    spokeImpl = address(AaveV4TestOrchestration.deploySpokeImplementation());
    treasurySpokeImpl = address(new TreasurySpokeInstance());
    tokenizationSpokeImpl = address(new TokenizationSpokeInstance());
    factoryImpl = address(new HubSpokeFactory());
    factory = HubSpokeFactory(_deployFactoryProxy(_initData()));
  }

  function test_constructor_disablesInitializers() public {
    assertEq(ProxyHelper.getProxyInitializedVersion(factoryImpl), type(uint64).max);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    HubSpokeFactory(factoryImpl).initialize(
      address(accessManager),
      hubImpl,
      spokeImpl,
      treasurySpokeImpl,
      tokenizationSpokeImpl
    );
  }

  function test_initialize() public {
    vm.expectEmit();
    emit IHubSpokeFactory.ImplementationUpdated(IHubSpokeFactory.InstanceType.Hub, hubImpl);
    vm.expectEmit();
    emit IHubSpokeFactory.ImplementationUpdated(IHubSpokeFactory.InstanceType.Spoke, spokeImpl);
    vm.expectEmit();
    emit IHubSpokeFactory.ImplementationUpdated(
      IHubSpokeFactory.InstanceType.TreasurySpoke,
      treasurySpokeImpl
    );
    vm.expectEmit();
    emit IHubSpokeFactory.ImplementationUpdated(
      IHubSpokeFactory.InstanceType.TokenizationSpoke,
      tokenizationSpokeImpl
    );
    HubSpokeFactory newFactory = HubSpokeFactory(_deployFactoryProxy(_initData()));

    assertEq(ProxyHelper.getImplementation(address(newFactory)), factoryImpl);
    assertEq(ProxyHelper.getProxyInitializedVersion(address(newFactory)), 1);
    assertEq(newFactory.authority(), address(accessManager));
    assertEq(newFactory.getImplementation(IHubSpokeFactory.InstanceType.Hub), hubImpl);
    assertEq(newFactory.getImplementation(IHubSpokeFactory.InstanceType.Spoke), spokeImpl);
    assertEq(
      newFactory.getImplementation(IHubSpokeFactory.InstanceType.TreasurySpoke),
      treasurySpokeImpl
    );
    assertEq(
      newFactory.getImplementation(IHubSpokeFactory.InstanceType.TokenizationSpoke),
      tokenizationSpokeImpl
    );
    assertEq(newFactory.getImplementation(IHubSpokeFactory.InstanceType.None), address(0));
    assertEq(newFactory.ORACLE_DECIMALS(), 8);
  }

  function test_initialize_revertsWith_InvalidInitialization() public {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    factory.initialize(
      address(accessManager),
      hubImpl,
      spokeImpl,
      treasurySpokeImpl,
      tokenizationSpokeImpl
    );
  }

  function test_initialize_revertsWith_InvalidImplementation() public {
    vm.expectRevert(IHubSpokeFactory.InvalidImplementation.selector);
    new TransparentUpgradeableProxy(
      factoryImpl,
      proxyAdminOwner,
      abi.encodeCall(
        HubSpokeFactory.initialize,
        (
          address(accessManager),
          hubImpl,
          tokenizationSpokeImpl,
          treasurySpokeImpl,
          tokenizationSpokeImpl
        )
      )
    );
  }

  function test_runtimeSize() public view {
    assertLe(factoryImpl.code.length, 24_576);
  }

  function test_setImplementation() public {
    address newSpokeImpl = address(new MockSpokeInstance(2));
    IHubSpokeFactory.SpokeDeployment memory predictedBefore = factory.predictSpoke(
      deployer,
      'salt',
      authority,
      MAX_ALLOWED_USER_RESERVES_LIMIT,
      proxyAdminOwner
    );
    vm.prank(deployer);
    address oldSpoke = factory
      .deploySpoke('old', authority, MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner)
      .proxy;

    vm.expectEmit(address(factory));
    emit IHubSpokeFactory.ImplementationUpdated(IHubSpokeFactory.InstanceType.Spoke, newSpokeImpl);
    vm.prank(ADMIN);
    factory.setImplementation(IHubSpokeFactory.InstanceType.Spoke, newSpokeImpl);

    assertEq(factory.getImplementation(IHubSpokeFactory.InstanceType.Spoke), newSpokeImpl);
    assertEq(ProxyHelper.getImplementation(oldSpoke), spokeImpl);
    IHubSpokeFactory.SpokeDeployment memory predictedAfter = factory.predictSpoke(
      deployer,
      'salt',
      authority,
      MAX_ALLOWED_USER_RESERVES_LIMIT,
      proxyAdminOwner
    );
    assertNotEq(predictedAfter.proxy, predictedBefore.proxy);
    assertEq(predictedAfter.oracle, predictedBefore.oracle);

    vm.prank(deployer);
    address newSpoke = factory
      .deploySpoke('salt', authority, MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner)
      .proxy;
    assertEq(newSpoke, predictedAfter.proxy);
    assertEq(ProxyHelper.getImplementation(newSpoke), newSpokeImpl);
  }

  function test_setImplementation_revertsWith_AccessManagedUnauthorized(address caller) public {
    vm.assume(caller != ADMIN && caller != ProxyHelper.getProxyAdmin(address(factory)));
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    factory.setImplementation(IHubSpokeFactory.InstanceType.Spoke, spokeImpl);
  }

  function test_setImplementation_revertsWith_InvalidImplementation_wrongRevision() public {
    _expectInvalidImplementation(
      IHubSpokeFactory.InstanceType.Hub,
      address(new MockHubInstance(0))
    );
    _expectInvalidImplementation(
      IHubSpokeFactory.InstanceType.Hub,
      address(new MockHubInstance(2))
    );
    _expectInvalidImplementation(
      IHubSpokeFactory.InstanceType.Spoke,
      address(new MockSpokeInstance(1))
    );
    _expectInvalidImplementation(
      IHubSpokeFactory.InstanceType.Spoke,
      address(new MockSpokeInstance(3))
    );
    _expectInvalidImplementation(
      IHubSpokeFactory.InstanceType.TreasurySpoke,
      address(new MockTreasurySpokeInstance(0))
    );
    _expectInvalidImplementation(
      IHubSpokeFactory.InstanceType.TreasurySpoke,
      address(new MockTreasurySpokeInstance(2))
    );
    _expectInvalidImplementation(
      IHubSpokeFactory.InstanceType.TokenizationSpoke,
      address(new MockTokenizationSpokeInstance(1))
    );
    _expectInvalidImplementation(
      IHubSpokeFactory.InstanceType.TokenizationSpoke,
      address(new MockTokenizationSpokeInstance(3))
    );
  }

  /// @dev The Spoke and the TokenizationSpoke share `SPOKE_REVISION`, so only their EIP-712 domain tells them apart.
  function test_setImplementation_revertsWith_InvalidImplementation_wrongDomain() public {
    _expectInvalidImplementation(IHubSpokeFactory.InstanceType.Spoke, tokenizationSpokeImpl);
    _expectInvalidImplementation(IHubSpokeFactory.InstanceType.TokenizationSpoke, spokeImpl);
  }

  function test_setImplementation_revertsWith_InvalidImplementation_noneType() public {
    _expectInvalidImplementation(IHubSpokeFactory.InstanceType.None, hubImpl);
  }

  /// @dev Each type is set with every other canonical implementation, and with an address without code.
  function test_setImplementation_reverts_wrongImplementations() public {
    address[5] memory candidates = [
      hubImpl,
      spokeImpl,
      treasurySpokeImpl,
      tokenizationSpokeImpl,
      makeAddr('noCode')
    ];
    for (uint256 t = 1; t <= 4; ++t) {
      for (uint256 i; i < candidates.length; ++i) {
        if (i == t - 1) continue;
        vm.expectRevert();
        vm.prank(ADMIN);
        factory.setImplementation(IHubSpokeFactory.InstanceType(t), candidates[i]);
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
    _assertRegistered(deployment.proxy, IHubSpokeFactory.InstanceType.Hub);
  }

  function test_deploySpoke() public {
    bytes32 salt = 'spoke';
    IHubSpokeFactory.SpokeDeployment memory predicted = factory.predictSpoke(
      deployer,
      salt,
      authority,
      MAX_ALLOWED_USER_RESERVES_LIMIT,
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
      MAX_ALLOWED_USER_RESERVES_LIMIT,
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
    _assertRegistered(deployment.proxy, IHubSpokeFactory.InstanceType.Spoke);

    vm.expectRevert(IAaveOracle.SpokeAlreadySet.selector);
    vm.prank(address(factory));
    IAaveOracle(deployment.oracle).setSpoke(deployment.proxy);
  }

  function test_deploySpoke_fuzz_maxUserReservesLimit(uint16 maxUserReservesLimit) public {
    maxUserReservesLimit = uint16(bound(maxUserReservesLimit, 1, MAX_ALLOWED_USER_RESERVES_LIMIT));
    IHubSpokeFactory.SpokeDeployment memory predicted = factory.predictSpoke(
      deployer,
      'salt',
      authority,
      maxUserReservesLimit,
      proxyAdminOwner
    );

    vm.prank(deployer);
    IHubSpokeFactory.SpokeDeployment memory deployment = factory.deploySpoke(
      'salt',
      authority,
      maxUserReservesLimit,
      proxyAdminOwner
    );

    assertEq(deployment.proxy, predicted.proxy);
    assertEq(ISpoke(deployment.proxy).MAX_USER_RESERVES_LIMIT(), maxUserReservesLimit);
  }

  function test_deploySpoke_revertsWith_InvalidMaxUserReservesLimit() public {
    vm.expectRevert(ISpoke.InvalidMaxUserReservesLimit.selector);
    factory.deploySpoke('salt', authority, 0, proxyAdminOwner);
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
    _assertRegistered(proxy, IHubSpokeFactory.InstanceType.TreasurySpoke);
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
    _assertRegistered(proxy, IHubSpokeFactory.InstanceType.TokenizationSpoke);
    assertEq(factory.getTokenizationSpoke(deployer, address(hub1), underlying), proxy);
  }

  function test_deployTokenizationSpoke_revertsWith_TokenizationSpokeAlreadyDeployed() public {
    address underlying = address(tokenList.dai);
    vm.startPrank(deployer);
    factory.deployTokenizationSpoke(
      'first',
      address(hub1),
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      proxyAdminOwner
    );

    vm.expectRevert(IHubSpokeFactory.TokenizationSpokeAlreadyDeployed.selector);
    factory.deployTokenizationSpoke(
      'second',
      address(hub1),
      underlying,
      'Other Name',
      'OTHER',
      proxyAdminOwner
    );
    vm.stopPrank();
  }

  function test_deployTokenizationSpoke_sameHubAndUnderlyingDifferentCallers() public {
    address underlying = address(tokenList.dai);
    address otherDeployer = makeAddr('otherDeployer');

    vm.prank(deployer);
    address first = factory.deployTokenizationSpoke(
      'salt',
      address(hub1),
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      proxyAdminOwner
    );
    vm.prank(otherDeployer);
    address second = factory.deployTokenizationSpoke(
      'salt',
      address(hub1),
      underlying,
      SHARE_NAME,
      SHARE_SYMBOL,
      proxyAdminOwner
    );

    assertNotEq(first, second);
    assertEq(factory.getTokenizationSpoke(deployer, address(hub1), underlying), first);
    assertEq(factory.getTokenizationSpoke(otherDeployer, address(hub1), underlying), second);
  }

  function test_getInstances_keyedByDeployerAndType() public {
    address otherDeployer = makeAddr('otherDeployer');

    vm.startPrank(deployer);
    address hubA = factory.deployHub('a', authority, proxyAdminOwner).proxy;
    address hubB = factory.deployHub('b', authority, proxyAdminOwner).proxy;
    address spokeA = factory
      .deploySpoke('a', authority, MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner)
      .proxy;
    vm.stopPrank();
    vm.prank(otherDeployer);
    address otherHub = factory.deployHub('a', authority, proxyAdminOwner).proxy;

    address[] memory hubs = factory.getInstances(deployer, IHubSpokeFactory.InstanceType.Hub);
    assertEq(hubs.length, 2);
    assertEq(hubs[0], hubA);
    assertEq(hubs[1], hubB);
    address[] memory spokes = factory.getInstances(deployer, IHubSpokeFactory.InstanceType.Spoke);
    assertEq(spokes.length, 1);
    assertEq(spokes[0], spokeA);
    assertEq(factory.getInstances(deployer, IHubSpokeFactory.InstanceType.TreasurySpoke).length, 0);
    address[] memory otherHubs = factory.getInstances(
      otherDeployer,
      IHubSpokeFactory.InstanceType.Hub
    );
    assertEq(otherHubs.length, 1);
    assertEq(otherHubs[0], otherHub);
  }

  function test_getInstanceInfo_unknownInstance() public {
    IHubSpokeFactory.InstanceInfo memory info = factory.getInstanceInfo(makeAddr('unknown'));
    assertEq(info.deployer, address(0));
    assertEq(uint8(info.instanceType), uint8(IHubSpokeFactory.InstanceType.None));
  }

  function test_predict_fuzz(address caller, bytes32 salt, address owner) public {
    vm.assume(caller != address(0) && owner != address(0));
    vm.assume(caller != ProxyHelper.getProxyAdmin(address(factory)));

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
      MAX_ALLOWED_USER_RESERVES_LIMIT,
      owner
    );
    IHubSpokeFactory.SpokeDeployment memory spokeDeployed = factory.deploySpoke(
      salt,
      authority,
      MAX_ALLOWED_USER_RESERVES_LIMIT,
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
    vm.startPrank(deployer);
    factory.deployHub(salt, authority, proxyAdminOwner);
    factory.deploySpoke(salt, authority, MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner);
    factory.deployTreasurySpoke(salt, treasuryOwner, proxyAdminOwner);

    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deployHub(salt, authority, proxyAdminOwner);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deploySpoke(salt, authority, MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner);
    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    factory.deployTreasurySpoke(salt, treasuryOwner, proxyAdminOwner);
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
      MAX_ALLOWED_USER_RESERVES_LIMIT,
      proxyAdminOwner
    );
    vm.etch(predicted.oracle, hex'00');

    vm.expectRevert(IHubSpokeFactory.SaltAlreadyUsed.selector);
    vm.prank(deployer);
    factory.deploySpoke('salt', authority, MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner);
  }

  function test_deploy_revertsWith_SaltAlreadyUsed_proxy() public {
    address underlying = address(tokenList.dai);
    vm.etch(factory.predictHub(deployer, 'salt', authority, proxyAdminOwner).proxy, hex'00');
    vm.etch(
      factory
        .predictSpoke(deployer, 'salt', authority, MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner)
        .proxy,
      hex'00'
    );
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
    factory.deploySpoke('salt', authority, MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner);
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
      MAX_ALLOWED_USER_RESERVES_LIMIT,
      proxyAdminOwner
    );
    vm.prank(otherDeployer);
    IHubSpokeFactory.SpokeDeployment memory second = factory.deploySpoke(
      salt,
      authority,
      MAX_ALLOWED_USER_RESERVES_LIMIT,
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
    factory.deploySpoke('salt', address(0), MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner);
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
    factory.deploySpoke('salt', authority, MAX_ALLOWED_USER_RESERVES_LIMIT, address(0));
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

  function _initData() internal view returns (bytes memory) {
    return
      abi.encodeCall(
        HubSpokeFactory.initialize,
        (address(accessManager), hubImpl, spokeImpl, treasurySpokeImpl, tokenizationSpokeImpl)
      );
  }

  function _deployFactoryProxy(bytes memory initData) internal returns (address) {
    return address(new TransparentUpgradeableProxy(factoryImpl, proxyAdminOwner, initData));
  }

  function _expectInvalidImplementation(
    IHubSpokeFactory.InstanceType instanceType,
    address implementation
  ) internal {
    vm.expectRevert(IHubSpokeFactory.InvalidImplementation.selector);
    vm.prank(ADMIN);
    factory.setImplementation(instanceType, implementation);
  }

  function _assertProxy(address proxy, address implementation, uint64 revision) internal view {
    assertEq(ProxyHelper.getImplementation(proxy), implementation);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(proxy)).owner(), proxyAdminOwner);
    assertEq(ProxyHelper.getProxyInitializedVersion(proxy), revision);
  }

  function _assertRegistered(
    address instance,
    IHubSpokeFactory.InstanceType instanceType
  ) internal view {
    address[] memory instances = factory.getInstances(deployer, instanceType);
    assertEq(instances[instances.length - 1], instance);
    IHubSpokeFactory.InstanceInfo memory info = factory.getInstanceInfo(instance);
    assertEq(info.deployer, deployer);
    assertEq(uint8(info.instanceType), uint8(instanceType));
  }
}
