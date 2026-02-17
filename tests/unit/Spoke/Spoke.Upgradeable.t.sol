// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeUpgradeableTest is SpokeBase {
  address internal proxyAdminOwner = makeAddr('proxyAdminOwner');
  address internal oracle = makeAddr('AaveOracle');

  function setUp() public override {
    super.setUp();
    vm.mockCall(oracle, abi.encodeCall(IPriceOracle.DECIMALS, ()), abi.encode(8));
  }

  function test_implementation_constructor_fuzz(uint64 revision) public {
    address spokeImplAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectEmit(spokeImplAddress);
    emit Initializable.Initialized(type(uint64).max);

    ISpokeInstance spokeImpl = _deployMockSpokeInstance(revision);

    assertEq(address(spokeImpl), spokeImplAddress);
    assertEq(spokeImpl.SPOKE_REVISION(), revision);
    assertEq(_getProxyInitializedVersion(spokeImplAddress), type(uint64).max);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    spokeImpl.initialize(address(accessManager));
  }

  function test_proxy_constructor_fuzz(uint64 revision) public {
    revision = uint64(bound(revision, 1, type(uint64).max));

    ISpokeInstance spokeImpl = _deployMockSpokeInstance(revision);
    address spokeProxyAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    address proxyAdminAddress = vm.computeCreateAddress(spokeProxyAddress, 1);

    ISpoke.LiquidationConfig memory expectedLiquidationConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      healthFactorForMaxBonus: 0,
      liquidationBonusFactor: 0
    });

    vm.expectEmit(spokeProxyAddress);
    emit IERC1967.Upgraded(address(spokeImpl));
    vm.expectEmit(spokeProxyAddress);
    emit ISpoke.SetSpokeImmutables(oracle, Constants.MAX_ALLOWED_USER_RESERVES_LIMIT);
    vm.expectEmit(spokeProxyAddress);
    emit IAccessManaged.AuthorityUpdated(address(accessManager));
    vm.expectEmit(spokeProxyAddress);
    emit ISpoke.UpdateLiquidationConfig(expectedLiquidationConfig);
    vm.expectEmit(spokeProxyAddress);
    emit Initializable.Initialized(revision);
    vm.expectEmit(proxyAdminAddress);
    emit Ownable.OwnershipTransferred(address(0), proxyAdminOwner);
    vm.expectEmit(spokeProxyAddress);
    emit IERC1967.AdminChanged(address(0), proxyAdminAddress);
    ISpoke spokeProxy = ISpoke(
      address(
        new TransparentUpgradeableProxy(
          address(spokeImpl),
          proxyAdminOwner,
          abi.encodeCall(ISpokeInstance.initialize, address(accessManager))
        )
      )
    );

    assertEq(address(spokeProxy), spokeProxyAddress);
    assertEq(_getProxyAdminAddress(address(spokeProxy)), proxyAdminAddress);
    assertEq(_getImplementationAddress(address(spokeProxy)), address(spokeImpl));

    assertEq(_getProxyInitializedVersion(address(spokeProxy)), revision);
    assertEq(spokeProxy.getLiquidationConfig(), expectedLiquidationConfig);
    assertEq(spokeProxy.MAX_USER_RESERVES_LIMIT(), Constants.MAX_ALLOWED_USER_RESERVES_LIMIT);
  }

  function test_proxy_reinitialization_fuzz(uint64 initialRevision) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max - 1));
    ISpokeInstance spokeImpl = _deployMockSpokeInstance(initialRevision);
    ITransparentUpgradeableProxy spokeProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(spokeImpl),
          proxyAdminOwner,
          abi.encodeCall(ISpokeInstance.initialize, address(accessManager))
        )
      )
    );

    setUpRoles(hub1, ISpoke(address(spokeProxy)), accessManager);
    uint128 targetHealthFactor = 1.05e18;
    _updateTargetHealthFactor(ISpoke(address(spokeProxy)), targetHealthFactor);

    uint64 secondRevision = uint64(vm.randomUint(initialRevision + 1, type(uint64).max));
    ISpokeInstance spokeImpl2 = _deployMockSpokeInstance(secondRevision);

    vm.expectEmit(address(spokeProxy));
    emit IAccessManaged.AuthorityUpdated(address(accessManager));
    vm.recordLogs();
    vm.prank(_getProxyAdminAddress(address(spokeProxy)));
    spokeProxy.upgradeToAndCall(
      address(spokeImpl2),
      _getInitializeCalldata(address(accessManager))
    );

    _assertEventNotEmitted(ISpoke.UpdateLiquidationConfig.selector);

    assertEq(_getTargetHealthFactor(ISpoke(address(spokeProxy))), targetHealthFactor);
  }

  function test_proxy_constructor_revertsWith_InvalidInitialization_ZeroRevision() public {
    ISpokeInstance spokeImpl = _deployMockSpokeInstance(0);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    new TransparentUpgradeableProxy(
      address(spokeImpl),
      proxyAdminOwner,
      abi.encodeCall(ISpokeInstance.initialize, address(accessManager))
    );
  }

  function test_proxy_constructor_fuzz_revertsWith_InvalidInitialization(
    uint64 initialRevision
  ) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max));

    ISpokeInstance spokeImpl = _deployMockSpokeInstance(initialRevision);
    ITransparentUpgradeableProxy spokeProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(spokeImpl),
          proxyAdminOwner,
          _getInitializeCalldata(address(accessManager))
        )
      )
    );

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(spokeProxy)));
    spokeProxy.upgradeToAndCall(address(spokeImpl), _getInitializeCalldata(address(accessManager)));

    uint64 secondRevision = uint64(vm.randomUint(0, initialRevision - 1));
    ISpokeInstance spokeImpl2 = _deployMockSpokeInstance(secondRevision);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(spokeProxy)));
    spokeProxy.upgradeToAndCall(
      address(spokeImpl2),
      _getInitializeCalldata(address(accessManager))
    );
  }

  function test_proxy_constructor_revertsWith_InvalidAddress() public {
    ISpokeInstance spokeImpl = DeployUtils.deploySpokeImplementation(
      oracle,
      Constants.MAX_ALLOWED_USER_RESERVES_LIMIT
    );
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    new TransparentUpgradeableProxy(
      address(spokeImpl),
      proxyAdminOwner,
      _getInitializeCalldata(address(0))
    );
  }

  function test_proxy_reinitialization_revertsWith_InvalidAddress() public {
    ISpokeInstance spokeImpl = DeployUtils.deploySpokeImplementation(
      oracle,
      Constants.MAX_ALLOWED_USER_RESERVES_LIMIT
    );
    ITransparentUpgradeableProxy spokeProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(spokeImpl),
          proxyAdminOwner,
          _getInitializeCalldata(address(accessManager))
        )
      )
    );

    ISpokeInstance spokeImpl2 = _deployMockSpokeInstance(2);
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    vm.prank(_getProxyAdminAddress(address(spokeProxy)));
    spokeProxy.upgradeToAndCall(address(spokeImpl2), _getInitializeCalldata(address(0)));
  }

  function test_proxy_reinitialization_revertsWith_CallerNotProxyAdmin() public {
    ISpokeInstance spokeImpl = DeployUtils.deploySpokeImplementation(
      oracle,
      Constants.MAX_ALLOWED_USER_RESERVES_LIMIT
    );
    ITransparentUpgradeableProxy spokeProxy = ITransparentUpgradeableProxy(
      address(
        new TransparentUpgradeableProxy(
          address(spokeImpl),
          proxyAdminOwner,
          _getInitializeCalldata(address(accessManager))
        )
      )
    );

    ISpokeInstance spokeImpl2 = _deployMockSpokeInstance(2);
    vm.expectRevert();
    vm.prank(makeUser());
    spokeProxy.upgradeToAndCall(
      address(spokeImpl2),
      _getInitializeCalldata(address(accessManager))
    );
  }

  function _getInitializeCalldata(address manager) internal pure returns (bytes memory) {
    return abi.encodeCall(ISpokeInstance.initialize, manager);
  }

  function _deployMockSpokeInstance(uint64 revision) internal returns (ISpokeInstance) {
    return
      ISpokeInstance(
        address(new MockSpokeInstance(revision, oracle, Constants.MAX_ALLOWED_USER_RESERVES_LIMIT))
      );
  }
}
