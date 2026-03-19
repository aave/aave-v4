// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract TreasurySpokeUpgradeableTest is SpokeBase {
  address internal proxyAdminOwner = makeAddr('proxyAdminOwner');

  function setUp() public override {
    super.setUp();
  }

  function test_implementation_constructor_fuzz(uint64 revision) public {
    address implAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectEmit(implAddress);
    emit Initializable.Initialized(type(uint64).max);

    MockTreasurySpokeInstance impl = _deployMockTreasurySpokeInstance(revision);

    assertEq(address(impl), implAddress);
    assertEq(impl.SPOKE_REVISION(), revision);
    assertEq(_getProxyInitializedVersion(implAddress), type(uint64).max);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    impl.initialize(TREASURY_ADMIN);
  }

  function test_proxy_constructor_fuzz(uint64 revision) public {
    revision = uint64(bound(revision, 1, type(uint64).max));

    MockTreasurySpokeInstance impl = _deployMockTreasurySpokeInstance(revision);
    address proxyAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    address proxyAdminAddress = vm.computeCreateAddress(proxyAddress, 1);

    vm.expectEmit(proxyAddress);
    emit IERC1967.Upgraded(address(impl));
    vm.expectEmit(proxyAddress);
    emit Ownable.OwnershipTransferred(address(0), TREASURY_ADMIN);
    vm.expectEmit(proxyAddress);
    emit Initializable.Initialized(revision);
    vm.expectEmit(proxyAdminAddress);
    emit Ownable.OwnershipTransferred(address(0), proxyAdminOwner);
    vm.expectEmit(proxyAddress);
    emit IERC1967.AdminChanged(address(0), proxyAdminAddress);

    ITreasurySpoke proxy = ITreasurySpoke(
      DeployUtils.proxify(
        address(impl),
        proxyAdminOwner,
        abi.encodeCall(MockTreasurySpokeInstance.initialize, (TREASURY_ADMIN))
      )
    );

    assertEq(address(proxy), proxyAddress);
    assertEq(_getProxyAdminAddress(address(proxy)), proxyAdminAddress);
    assertEq(_getImplementationAddress(address(proxy)), address(impl));

    assertEq(_getProxyInitializedVersion(address(proxy)), revision);
    assertEq(Ownable2Step(address(proxy)).owner(), TREASURY_ADMIN);
  }

  function test_proxy_reinitialization_fuzz(uint64 initialRevision) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max - 1));
    MockTreasurySpokeInstance impl = _deployMockTreasurySpokeInstance(initialRevision);
    ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(
      DeployUtils.proxify(
        address(impl),
        proxyAdminOwner,
        abi.encodeCall(MockTreasurySpokeInstance.initialize, (TREASURY_ADMIN))
      )
    );

    uint64 secondRevision = uint64(vm.randomUint(initialRevision + 1, type(uint64).max));
    MockTreasurySpokeInstance impl2 = _deployMockTreasurySpokeInstance(secondRevision);

    vm.expectEmit(address(proxy));
    emit Ownable.OwnershipTransferred(TREASURY_ADMIN, TREASURY_ADMIN);
    vm.prank(_getProxyAdminAddress(address(proxy)));
    proxy.upgradeToAndCall(
      address(impl2),
      abi.encodeCall(MockTreasurySpokeInstance.initialize, (TREASURY_ADMIN))
    );

    assertEq(Ownable2Step(address(proxy)).owner(), TREASURY_ADMIN);
  }

  function test_proxy_constructor_revertsWith_InvalidInitialization_ZeroRevision() public {
    MockTreasurySpokeInstance impl = _deployMockTreasurySpokeInstance(0);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    DeployUtils.proxify(
      address(impl),
      proxyAdminOwner,
      abi.encodeCall(MockTreasurySpokeInstance.initialize, (TREASURY_ADMIN))
    );
  }

  function test_proxy_constructor_fuzz_revertsWith_InvalidInitialization(
    uint64 initialRevision
  ) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max));

    MockTreasurySpokeInstance impl = _deployMockTreasurySpokeInstance(initialRevision);
    ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(
      DeployUtils.proxify(
        address(impl),
        proxyAdminOwner,
        abi.encodeCall(MockTreasurySpokeInstance.initialize, (TREASURY_ADMIN))
      )
    );

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(proxy)));
    proxy.upgradeToAndCall(
      address(impl),
      abi.encodeCall(MockTreasurySpokeInstance.initialize, (TREASURY_ADMIN))
    );

    uint64 secondRevision = uint64(vm.randomUint(0, initialRevision - 1));
    MockTreasurySpokeInstance impl2 = _deployMockTreasurySpokeInstance(secondRevision);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(proxy)));
    proxy.upgradeToAndCall(
      address(impl2),
      abi.encodeCall(MockTreasurySpokeInstance.initialize, (TREASURY_ADMIN))
    );
  }

  function test_proxy_constructor_revertsWith_InvalidAddress() public {
    TreasurySpokeInstance impl = new TreasurySpokeInstance();
    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0))
    );
    DeployUtils.proxify(
      address(impl),
      proxyAdminOwner,
      abi.encodeCall(TreasurySpokeInstance.initialize, (address(0)))
    );
  }

  function test_proxy_reinitialization_revertsWith_CallerNotProxyAdmin() public {
    TreasurySpokeInstance impl = new TreasurySpokeInstance();
    ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(
      DeployUtils.proxify(
        address(impl),
        proxyAdminOwner,
        abi.encodeCall(TreasurySpokeInstance.initialize, (TREASURY_ADMIN))
      )
    );

    TreasurySpokeInstance impl2 = new TreasurySpokeInstance();
    vm.expectRevert();
    vm.prank(makeUser());
    proxy.upgradeToAndCall(
      address(impl2),
      abi.encodeCall(TreasurySpokeInstance.initialize, (TREASURY_ADMIN))
    );
  }

  function _deployMockTreasurySpokeInstance(
    uint64 revision
  ) internal returns (MockTreasurySpokeInstance) {
    return new MockTreasurySpokeInstance(revision);
  }
}
