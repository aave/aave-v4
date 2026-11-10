// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/BabylonBase.t.sol';
import {MockBabylonSpokeInstance} from 'tests/helpers/mocks/MockBabylonSpokeInstance.sol';

/// @dev Upgrades of the BabylonSpoke. Reinitializing only rejects a borrowable managed collateral
/// reserve. It neither compares the managed collateral reserve with the previous implementation's
/// nor checks that the reserve holds no debt.
contract BabylonSpokeUpgradeableTest is BabylonBase {
  uint256 internal collateralReserveId;
  uint256 internal debtReserveId;

  function setUp() public virtual override {
    super.setUp();
    collateralReserveId = babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID();
    debtReserveId = _daiReserveId(spoke4);
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

  /// @dev Collateral left in the previous managed reserve can no longer be liquidated, so the
  /// authority checks that none is left before such an upgrade.
  function test_upgrade_differentManagedCollateralReserve() public {
    _increaseCollateralSupply(spoke4, collateralReserveId, 1e8, alice);
    uint256 suppliedSharesBefore = spoke4.getUserSuppliedShares(collateralReserveId, alice);
    _updateBorrowable(debtReserveId, false);

    _upgradeBabylonSpoke(debtReserveId);

    assertEq(
      babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID(),
      debtReserveId,
      'managed collateral reserve id'
    );
    assertEq(
      spoke4.getUserSuppliedShares(collateralReserveId, alice),
      suppliedSharesBefore,
      'previous collateral untouched'
    );
  }

  /// @dev The check reads the current borrowable flag only, so a reserve still carrying debt from
  /// when it was borrowable can become the managed collateral reserve.
  function test_upgrade_managedCollateralWithExistingDebt() public {
    _increaseCollateralSupply(spoke4, collateralReserveId, 10e8, alice);
    _openSupplyPositionNoCollateral(spoke4, debtReserveId, 1000e18);
    vm.prank(alice);
    spoke4.borrow(debtReserveId, 1e18, alice);
    _updateBorrowable(debtReserveId, false);

    _upgradeBabylonSpoke(debtReserveId);

    assertEq(
      babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID(),
      debtReserveId,
      'managed collateral reserve id'
    );
    assertGt(spoke4.getUserTotalDebt(debtReserveId, alice), 0, 'existing debt');
  }

  function _updateBorrowable(uint256 reserveId, bool borrowable) internal {
    ISpoke.ReserveConfig memory config = spoke4.getReserveConfig(reserveId);
    config.borrowable = borrowable;
    vm.prank(SPOKE_ADMIN);
    spoke4.updateReserveConfig(reserveId, config);
  }

  function _upgradeBabylonSpoke(uint256 managedCollateralReserveId) internal {
    MockBabylonSpokeInstance implementation = new MockBabylonSpokeInstance(
      2,
      address(oracle4),
      liquidationManager,
      managedCollateralReserveId
    );
    vm.prank(ProxyHelper.getProxyAdmin(address(spoke4)));
    ITransparentUpgradeableProxy(address(spoke4)).upgradeToAndCall(
      address(implementation),
      abi.encodeCall(ISpokeInstance.initialize, (address(accessManager)))
    );
  }
}
