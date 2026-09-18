// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/BabylonBase.t.sol';
import {BabylonSpokeInstance} from 'src/spoke/instances/BabylonSpokeInstance.sol';
import {MockBabylonSpokeInstance} from 'tests/helpers/mocks/MockBabylonSpokeInstance.sol';

/// @dev Configuration of the BabylonSpoke: its immutables, the non-borrowable managed collateral
/// reserve on listing, update and upgrade, the fee-free reserves and the single registrable
/// collateral.
contract BabylonSpokeConfigTest is BabylonBase {
  uint256 internal collateralReserveId;
  uint256 internal debtReserveId;

  function setUp() public virtual override {
    super.setUp();
    collateralReserveId = babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID();
    debtReserveId = _daiReserveId(spoke4);
  }

  function test_immutables() public view {
    assertEq(babylonSpoke.LIQUIDATION_MANAGER(), liquidationManager, 'liquidation manager');
    assertEq(
      babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID(),
      _wbtcReserveId(spoke4),
      'managed collateral reserve id'
    );
  }

  /// @dev The managed collateral reserve is listed non-borrowable, so nobody can hold debt in it.
  function test_revert_borrow_managedCollateralReserve() public {
    _openSupplyPositionNoCollateral(spoke4, collateralReserveId, 1e8);
    _increaseCollateralSupply(spoke4, collateralReserveId, 1e8, alice);

    vm.expectRevert(ISpoke.ReserveNotBorrowable.selector);
    vm.prank(alice);
    spoke4.borrow(collateralReserveId, 1, alice);
  }

  function test_revert_constructor_zeroLiquidationManager() public {
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    new BabylonSpokeInstance(address(oracle4), address(0), collateralReserveId);
  }

  /// @dev The managed collateral reserve is checked when it gets listed, on a spoke deployed
  /// before any reserve exists.
  function test_revert_addReserve_borrowableManagedCollateral() public {
    ISpoke freshSpoke = _deployFreshBabylonSpoke();
    address priceSource = _deployMockPriceFeed(freshSpoke, 1e8);

    vm.expectRevert(IBabylonSpoke.UnsupportedBorrowableCollateral.selector);
    vm.prank(SPOKE_ADMIN);
    freshSpoke.addReserve(
      address(hub1),
      usdzAssetId,
      priceSource,
      _getDefaultReserveConfig(10_00),
      _getFreshDynamicReserveConfig()
    );
  }

  function test_addReserve_nonBorrowableManagedCollateral() public {
    ISpoke freshSpoke = _deployFreshBabylonSpoke();
    address priceSource = _deployMockPriceFeed(freshSpoke, 1e8);
    ISpoke.ReserveConfig memory config = _getDefaultReserveConfig(10_00);
    config.borrowable = false;

    vm.prank(SPOKE_ADMIN);
    uint256 reserveId = freshSpoke.addReserve(
      address(hub1),
      usdzAssetId,
      priceSource,
      config,
      _getFreshDynamicReserveConfig()
    );

    assertEq(
      reserveId,
      IBabylonSpoke(address(freshSpoke)).MANAGED_COLLATERAL_RESERVE_ID(),
      'managed reserve listed'
    );
    assertFalse(
      freshSpoke.getReserveConfig(reserveId).borrowable,
      'managed reserve not borrowable'
    );
  }

  /// @dev Listing a borrowable reserve at any other id stays allowed.
  function test_addReserve_borrowableOtherReserve() public {
    address priceSource = _deployMockPriceFeed(spoke4, 1e8);
    uint256 expectedReserveId = spoke4.getReserveCount();

    vm.prank(SPOKE_ADMIN);
    uint256 reserveId = spoke4.addReserve(
      address(hub1),
      usdzAssetId,
      priceSource,
      _getDefaultReserveConfig(10_00),
      _getFreshDynamicReserveConfig()
    );

    assertEq(reserveId, expectedReserveId, 'reserve id');
    assertTrue(spoke4.getReserveConfig(reserveId).borrowable, 'other reserve borrowable');
  }

  /// @dev Upgrading a spoke whose managed collateral reserve is already listed as borrowable reverts.
  function test_revert_upgrade_borrowableManagedCollateral() public {
    MockBabylonSpokeInstance implementation = new MockBabylonSpokeInstance(
      2,
      address(oracle4),
      liquidationManager,
      debtReserveId
    );

    vm.expectRevert(IBabylonSpoke.UnsupportedBorrowableCollateral.selector);
    vm.prank(ProxyHelper.getProxyAdmin(address(spoke4)));
    ITransparentUpgradeableProxy(address(spoke4)).upgradeToAndCall(
      address(implementation),
      abi.encodeCall(ISpokeInstance.initialize, (address(accessManager)))
    );
  }

  /// @dev An unlisted managed collateral reserve has no flags, so the check passes and the spoke
  /// initializes before the reserve exists.
  function test_upgrade_unlistedManagedCollateralReserve() public {
    uint256 unlistedReserveId = spoke4.getReserveCount();
    MockBabylonSpokeInstance implementation = new MockBabylonSpokeInstance(
      2,
      address(oracle4),
      liquidationManager,
      unlistedReserveId
    );

    vm.expectEmit(address(spoke4));
    emit IBabylonSpoke.SetBabylonSpokeImmutables(liquidationManager, unlistedReserveId);
    vm.prank(ProxyHelper.getProxyAdmin(address(spoke4)));
    ITransparentUpgradeableProxy(address(spoke4)).upgradeToAndCall(
      address(implementation),
      abi.encodeCall(ISpokeInstance.initialize, (address(accessManager)))
    );

    assertEq(
      babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID(),
      unlistedReserveId,
      'managed collateral reserve id'
    );
  }

  function test_upgrade_nonBorrowableManagedCollateral() public {
    MockBabylonSpokeInstance implementation = new MockBabylonSpokeInstance(
      2,
      address(oracle4),
      liquidationManager,
      collateralReserveId
    );

    vm.expectEmit(address(spoke4));
    emit IBabylonSpoke.SetBabylonSpokeImmutables(liquidationManager, collateralReserveId);
    vm.prank(ProxyHelper.getProxyAdmin(address(spoke4)));
    ITransparentUpgradeableProxy(address(spoke4)).upgradeToAndCall(
      address(implementation),
      abi.encodeCall(ISpokeInstance.initialize, (address(accessManager)))
    );

    assertEq(babylonSpoke.LIQUIDATION_MANAGER(), liquidationManager, 'liquidation manager');
    assertEq(
      babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID(),
      collateralReserveId,
      'managed collateral reserve id'
    );
  }

  /// @dev A babylon spoke with no reserve listed, managing reserve 0.
  function _deployFreshBabylonSpoke() private returns (ISpoke) {
    vm.startPrank(ADMIN);
    TestTypes.TestSpokeReport memory report = AaveV4TestOrchestration.deployTestBabylonSpoke({
      proxyAdminOwner: ADMIN,
      accessManager: address(accessManager),
      liquidationManager: liquidationManager,
      managedCollateralReserveId: 0,
      babylonSpokeBytecode: BytecodeHelper.getBabylonSpokeBytecode(),
      salt: keccak256('fresh-babylon-spoke')
    });
    AaveV4SpokeRolesProcedure.setupSpokeAllRoles(address(accessManager), report.spoke);
    vm.stopPrank();

    assertEq(ISpoke(report.spoke).getReserveCount(), 0, 'no reserve listed');
    return ISpoke(report.spoke);
  }

  function _getFreshDynamicReserveConfig()
    private
    pure
    returns (ISpoke.DynamicReserveConfig memory)
  {
    return
      ISpoke.DynamicReserveConfig({
        collateralFactor: 10_00,
        maxLiquidationBonus: 110_00,
        liquidationFee: 0
      });
  }

  function test_revert_addDynamicReserveConfig_nonZeroLiquidationFee() public {
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(
      spoke4,
      debtReserveId
    );
    config.liquidationFee = 1;

    vm.expectRevert(IBabylonSpoke.UnsupportedLiquidationFee.selector);
    vm.prank(SPOKE_ADMIN);
    spoke4.addDynamicReserveConfig(debtReserveId, config);
  }

  function test_revert_addReserve_nonZeroLiquidationFee() public {
    ISpoke.DynamicReserveConfig memory config = ISpoke.DynamicReserveConfig({
      collateralFactor: 10_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 1
    });
    address priceSource = _deployMockPriceFeed(spoke4, 1e8);

    vm.expectRevert(IBabylonSpoke.UnsupportedLiquidationFee.selector);
    vm.prank(SPOKE_ADMIN);
    spoke4.addReserve(
      address(hub1),
      usdzAssetId,
      priceSource,
      _getDefaultReserveConfig(10_00),
      config
    );
  }

  function test_revert_updateDynamicReserveConfig_nonZeroLiquidationFee() public {
    uint32 dynamicConfigKey = spoke4.getReserve(debtReserveId).dynamicConfigKey;
    ISpoke.DynamicReserveConfig memory config = _getLatestDynamicReserveConfig(
      spoke4,
      debtReserveId
    );
    config.liquidationFee = 1;

    vm.expectRevert(IBabylonSpoke.UnsupportedLiquidationFee.selector);
    vm.prank(SPOKE_ADMIN);
    spoke4.updateDynamicReserveConfig(debtReserveId, dynamicConfigKey, config);
  }

  function test_revert_updateReserveConfig_borrowableManagedCollateral() public {
    ISpoke.ReserveConfig memory config = spoke4.getReserveConfig(collateralReserveId);
    config.borrowable = true;

    vm.expectRevert(IBabylonSpoke.UnsupportedBorrowableCollateral.selector);
    vm.prank(SPOKE_ADMIN);
    spoke4.updateReserveConfig(collateralReserveId, config);
  }

  /// @dev The guard is scoped to the managed collateral reserve: every other reserve stays
  /// borrowable, and a reserve being listed is never the managed one.
  function test_updateReserveConfig_borrowableOtherReserve() public {
    ISpoke.ReserveConfig memory config = spoke4.getReserveConfig(debtReserveId);
    config.borrowable = true;

    vm.prank(SPOKE_ADMIN);
    spoke4.updateReserveConfig(debtReserveId, config);

    assertTrue(spoke4.getReserveConfig(debtReserveId).borrowable, 'debt reserve borrowable');
  }

  function test_userReservesLimit() public view {
    assertEq(spoke4.MAX_USER_RESERVES_LIMIT(), 1, 'one collateral and one debt reserve per user');
  }

  function test_setUsingAsCollateral_managedCollateralReserve() public {
    vm.startPrank(alice);
    spoke4.setUsingAsCollateral(collateralReserveId, true, alice);

    // the managed collateral can be disabled and registered again
    spoke4.setUsingAsCollateral(collateralReserveId, false, alice);
    spoke4.setUsingAsCollateral(collateralReserveId, true, alice);
    vm.stopPrank();

    (bool isUsingAsCollateral, ) = spoke4.getUserReserveStatus(collateralReserveId, alice);
    assertTrue(isUsingAsCollateral, 'managed collateral registered');
  }

  function test_revert_setUsingAsCollateral_unsupportedCollateralReserve() public {
    vm.expectRevert(IBabylonSpoke.UnsupportedCollateralReserve.selector);
    vm.prank(alice);
    spoke4.setUsingAsCollateral(debtReserveId, true, alice);
  }
}
