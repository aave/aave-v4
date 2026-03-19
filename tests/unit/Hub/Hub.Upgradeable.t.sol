// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubUpgradeableTest is HubBase {
  address public proxyAdminOwner = makeAddr('proxyAdminOwner');

  function test_implementation_constructor_fuzz(uint64 revision) public {
    address hubImplAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectEmit(hubImplAddress);
    emit Initializable.Initialized(type(uint64).max);

    MockHubInstance hubImpl = new MockHubInstance(revision);

    assertEq(address(hubImpl), hubImplAddress);
    assertEq(hubImpl.HUB_REVISION(), revision);
    assertEq(_getProxyInitializedVersion(hubImplAddress), type(uint64).max);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    hubImpl.initialize(address(accessManager));
  }

  function test_proxy_constructor_fuzz(uint64 revision) public {
    revision = uint64(bound(revision, 1, type(uint64).max));

    MockHubInstance hubImpl = new MockHubInstance(revision);
    address hubProxyAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    address proxyAdminAddress = vm.computeCreateAddress(hubProxyAddress, 1);

    vm.expectEmit(hubProxyAddress);
    emit IERC1967.Upgraded(address(hubImpl));
    vm.expectEmit(hubProxyAddress);
    emit IAccessManaged.AuthorityUpdated(address(accessManager));
    vm.expectEmit(hubProxyAddress);
    emit Initializable.Initialized(revision);
    vm.expectEmit(proxyAdminAddress);
    emit Ownable.OwnershipTransferred(address(0), proxyAdminOwner);
    vm.expectEmit(hubProxyAddress);
    emit IERC1967.AdminChanged(address(0), proxyAdminAddress);

    IHub hubProxy = _deployHubProxy(address(hubImpl));

    assertEq(address(hubProxy), hubProxyAddress);
    assertEq(_getProxyAdminAddress(address(hubProxy)), proxyAdminAddress);
    assertEq(_getImplementationAddress(address(hubProxy)), address(hubImpl));
    assertEq(_getProxyInitializedVersion(address(hubProxy)), revision);
    assertEq(IAccessManaged(address(hubProxy)).authority(), address(accessManager));
    assertEq(hubProxy.getAssetCount(), 0);
  }

  function test_proxy_reinitialization_fuzz(uint64 initialRevision) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max - 1));
    MockHubInstance hubImpl = new MockHubInstance(initialRevision);
    IHub hubProxy = _deployHubProxy(address(hubImpl));

    (uint256 assetId, address underlying) = _addAsset(hubProxy);
    uint256 assetCountBefore = hubProxy.getAssetCount();
    assertEq(assetCountBefore, 1);

    uint64 secondRevision = uint64(vm.randomUint(initialRevision + 1, type(uint64).max));
    MockHubInstance hubImpl2 = new MockHubInstance(secondRevision);

    vm.expectEmit(address(hubProxy));
    emit IAccessManaged.AuthorityUpdated(address(accessManager));
    vm.prank(_getProxyAdminAddress(address(hubProxy)));
    ITransparentUpgradeableProxy(address(hubProxy)).upgradeToAndCall(
      address(hubImpl2),
      _getInitializeCalldata(address(accessManager))
    );

    assertEq(_getProxyInitializedVersion(address(hubProxy)), secondRevision);
    assertEq(_getImplementationAddress(address(hubProxy)), address(hubImpl2));
    assertEq(hubProxy.getAssetCount(), assetCountBefore);
    assertEq(hubProxy.getAsset(assetId).underlying, underlying);
  }

  function test_proxy_storage_persists_across_upgrade() public {
    MockHubInstance hubImpl = new MockHubInstance(1);
    IHub hubProxy = _deployHubProxy(address(hubImpl));

    (uint256 assetId, address underlying) = _addAsset(hubProxy);
    uint256 assetCountBefore = hubProxy.getAssetCount();
    assertEq(assetCountBefore, 1);
    assertEq(hubProxy.getAsset(assetId).underlying, underlying);

    // Upgrade to v2
    MockHubInstance hubImpl2 = new MockHubInstance(2);
    vm.prank(_getProxyAdminAddress(address(hubProxy)));
    ITransparentUpgradeableProxy(address(hubProxy)).upgradeToAndCall(
      address(hubImpl2),
      _getInitializeCalldata(address(accessManager))
    );

    // Verify storage persists
    assertEq(hubProxy.getAssetCount(), assetCountBefore);
    assertEq(hubProxy.getAsset(assetId).underlying, underlying);
    assertEq(_getProxyInitializedVersion(address(hubProxy)), 2);
  }

  function test_proxy_constructor_revertsWith_InvalidInitialization_ZeroRevision() public {
    MockHubInstance hubImpl = new MockHubInstance(0);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    new TransparentUpgradeableProxy(
      address(hubImpl),
      proxyAdminOwner,
      _getInitializeCalldata(address(accessManager))
    );
  }

  function test_proxy_constructor_fuzz_revertsWith_InvalidInitialization(
    uint64 initialRevision
  ) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max));

    MockHubInstance hubImpl = new MockHubInstance(initialRevision);
    ITransparentUpgradeableProxy hubProxy = ITransparentUpgradeableProxy(
      address(_deployHubProxy(address(hubImpl)))
    );

    // Same revision should revert
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(hubProxy)));
    hubProxy.upgradeToAndCall(address(hubImpl), _getInitializeCalldata(address(accessManager)));

    // Lower revision should revert
    uint64 secondRevision = uint64(vm.randomUint(0, initialRevision - 1));
    MockHubInstance hubImpl2 = new MockHubInstance(secondRevision);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(hubProxy)));
    hubProxy.upgradeToAndCall(address(hubImpl2), _getInitializeCalldata(address(accessManager)));
  }

  function test_proxy_constructor_revertsWith_InvalidAddress() public {
    IHubInstance hubImpl = DeployUtils.deployHubImplementation();
    vm.expectRevert(IHub.InvalidAddress.selector);
    new TransparentUpgradeableProxy(
      address(hubImpl),
      proxyAdminOwner,
      _getInitializeCalldata(address(0))
    );
  }

  function test_proxy_reinitialization_revertsWith_InvalidAddress() public {
    MockHubInstance hubImpl = new MockHubInstance(1);
    ITransparentUpgradeableProxy hubProxy = ITransparentUpgradeableProxy(
      address(_deployHubProxy(address(hubImpl)))
    );

    MockHubInstance hubImpl2 = new MockHubInstance(2);
    vm.expectRevert(IHub.InvalidAddress.selector);
    vm.prank(_getProxyAdminAddress(address(hubProxy)));
    hubProxy.upgradeToAndCall(address(hubImpl2), _getInitializeCalldata(address(0)));
  }

  function test_proxy_reinitialization_revertsWith_CallerNotProxyAdmin() public {
    MockHubInstance hubImpl = new MockHubInstance(1);
    ITransparentUpgradeableProxy hubProxy = ITransparentUpgradeableProxy(
      address(_deployHubProxy(address(hubImpl)))
    );

    MockHubInstance hubImpl2 = new MockHubInstance(2);
    vm.expectRevert();
    vm.prank(makeUser());
    hubProxy.upgradeToAndCall(address(hubImpl2), _getInitializeCalldata(address(accessManager)));
  }

  function test_hub_revision_accessible() public {
    IHubInstance hubImpl = DeployUtils.deployHubImplementation();
    IHubInstance hubProxy = IHubInstance(address(_deployHubProxy(address(hubImpl))));

    assertEq(hubProxy.HUB_REVISION(), 1);
  }

  function _deployHubProxy(address hubImpl) internal returns (IHub) {
    return
      IHub(
        address(
          new TransparentUpgradeableProxy(
            hubImpl,
            proxyAdminOwner,
            _getInitializeCalldata(address(accessManager))
          )
        )
      );
  }

  function _getInitializeCalldata(address authority) internal pure returns (bytes memory) {
    return abi.encodeCall(IHubInstance.initialize, (authority));
  }

  function _addAsset(IHub hub) internal returns (uint256 assetId, address underlying) {
    underlying = address(new TestnetERC20('Test', 'TST', 18));
    address feeReceiver = makeAddr('feeReceiver');
    AssetInterestRateStrategy irStrat = new AssetInterestRateStrategy(address(hub));

    IAssetInterestRateStrategy.InterestRateData memory irDataLocal = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 5_00,
        rateGrowthBeforeOptimal: 5_00,
        rateGrowthAfterOptimal: 5_00
      });

    bytes4[] memory hubSelectors = new bytes4[](1);
    hubSelectors[0] = IHub.addAsset.selector;
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(this), 0);
    accessManager.setTargetFunctionRole(address(hub), hubSelectors, Roles.HUB_ADMIN_ROLE);
    vm.stopPrank();

    assetId = hub.addAsset(underlying, 18, feeReceiver, address(irStrat), abi.encode(irDataLocal));
  }
}
