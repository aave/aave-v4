// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ITransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IPriceFeed} from 'src/spoke/interfaces/IPriceFeed.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {AaveV4MainnetAddresses} from 'tests/fork/AaveV4MainnetAddresses.sol';

/// @title ForkBase
/// @notice Base harness for Ethereum-mainnet fork tests that upgrade a live Aave V4 Spoke to the
///         current branch implementation and verify storage/behavior are preserved.
/// @dev Tests self-skip when no mainnet RPC is configured, so the default `forge test` run is unaffected.
///      Run with `RPC_MAINNET` set (see `make test-fork`). Pin a block via the `FORK_BLOCK` env var.
abstract contract ForkBase is Test {
  /// @dev Snapshot of a single (user, reserve) position.
  struct PositionSnapshot {
    uint256 suppliedShares;
    uint256 suppliedAssets;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
    uint256 premiumDebtRay;
    bool usingAsCollateral;
    bool borrowing;
  }

  /// @dev Snapshot of a user's account-level data.
  struct AccountSnapshot {
    uint256 riskPremium;
    uint256 avgCollateralFactor;
    uint256 healthFactor;
    uint256 totalCollateralValue;
    uint256 totalDebtValueRay;
    uint256 activeCollateralCount;
    uint256 borrowCount;
    uint256 lastRiskPremium;
  }

  /// @dev Snapshot of reserve-level aggregates.
  struct ReserveSnapshot {
    uint256 suppliedShares;
    uint256 suppliedAssets;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
  }

  bool internal forkReady;
  ISpoke internal spoke;
  address internal oracle;
  uint16 internal maxUserReservesLimit;
  address internal proxyAdmin;
  address internal oldImplementation;

  /// @dev Spoke targeted by the suite. Override `_target()` to point at a different live spoke.
  function _target() internal pure virtual returns (address) {
    return AaveV4MainnetAddresses.MAIN_SPOKE;
  }

  function setUp() public virtual {
    forkReady = _createFork();
    if (!forkReady) return;

    address target = _target();
    if (target.code.length == 0) {
      // The forked block predates the deployment (or the address is wrong): skip rather than fail.
      forkReady = false;
      return;
    }
    _useSpoke(target);
  }

  /// @dev Guards every fork test: marks it skipped (not failed) when no fork is available.
  modifier onFork() {
    if (!forkReady) {
      vm.skip(true);
      return;
    }
    _;
  }

  function _createFork() private returns (bool) {
    uint256 forkBlock = vm.envOr('FORK_BLOCK', uint256(0));
    if (forkBlock == 0) {
      try vm.createSelectFork('mainnet') returns (uint256) {
        return true;
      } catch {
        return false;
      }
    }
    try vm.createSelectFork('mainnet', forkBlock) returns (uint256) {
      return true;
    } catch {
      return false;
    }
  }

  function _useSpoke(address target) internal {
    spoke = ISpoke(target);
    oracle = spoke.ORACLE();
    maxUserReservesLimit = spoke.MAX_USER_RESERVES_LIMIT();
    proxyAdmin = ProxyHelper.getProxyAdmin(target);
    oldImplementation = ProxyHelper.getImplementation(target);
    vm.label(target, 'Spoke');
    vm.label(oracle, 'AaveOracle');
  }

  /// @dev Deploys the branch implementation (immutables copied from the live proxy) and upgrades the
  ///      proxy to it. Empty calldata performs a pure implementation swap with no reinitialization,
  ///      which is the strongest test of storage preservation.
  function _upgradeSpoke() internal returns (address newImplementation) {
    newImplementation = address(new SpokeInstance(oracle, maxUserReservesLimit));
    vm.prank(proxyAdmin);
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(newImplementation, '');
    assertEq(
      ProxyHelper.getImplementation(address(spoke)),
      newImplementation,
      'implementation not updated'
    );
  }

  /// @dev Finds a reserve usable as collateral (collateral factor > 0) and a borrowable reserve, both
  ///      active and distinct when possible. Reverts if the live spoke has no suitable reserves.
  function _collateralAndBorrowReserves()
    internal
    view
    returns (uint256 collateralReserveId, uint256 borrowReserveId)
  {
    uint256 count = spoke.getReserveCount();

    bool foundCollateral;
    for (uint256 i = 0; i < count; i++) {
      ISpoke.ReserveConfig memory cfg = spoke.getReserveConfig(i);
      if (cfg.paused || cfg.frozen) continue;
      ISpoke.Reserve memory r = spoke.getReserve(i);
      if (spoke.getDynamicReserveConfig(i, r.dynamicConfigKey).collateralFactor > 0) {
        collateralReserveId = i;
        foundCollateral = true;
        break;
      }
    }
    require(foundCollateral, 'no collateral reserve on live spoke');

    bool foundBorrow;
    for (uint256 i = 0; i < count; i++) {
      ISpoke.ReserveConfig memory cfg = spoke.getReserveConfig(i);
      if (cfg.paused || cfg.frozen || !cfg.borrowable) continue;
      borrowReserveId = i;
      foundBorrow = true;
      if (i != collateralReserveId) break; // prefer a reserve distinct from the collateral
    }
    require(foundBorrow, 'no borrowable reserve on live spoke');
  }

  /// @dev A modest amount expressed in the reserve's underlying decimals.
  function _unit(uint256 reserveId) internal view returns (uint256) {
    return 10 ** spoke.getReserve(reserveId).decimals;
  }

  /// @dev Funds `user`, approves the spoke, and supplies `amount` of `reserveId` (default salt).
  function _seedSupply(address user, uint256 reserveId, uint256 amount) internal {
    address underlying = spoke.getReserve(reserveId).underlying;
    deal(underlying, user, amount);
    vm.startPrank(user);
    IERC20(underlying).approve(address(spoke), amount);
    spoke.supply(reserveId, amount, user);
    vm.stopPrank();
  }

  /// @dev Mocks `reserveId`'s price feed down to `numerator/denominator` of its current value, e.g. to
  ///      push a borrower below the liquidation threshold on the fork.
  function _dropReservePrice(uint256 reserveId, uint256 numerator, uint256 denominator) internal {
    address source = IAaveOracle(oracle).getReserveSource(reserveId);
    int256 current = IPriceFeed(source).latestAnswer();
    int256 dropped = (current * int256(numerator)) / int256(denominator);
    vm.mockCall(
      source,
      abi.encodeWithSelector(IPriceFeed.latestAnswer.selector),
      abi.encode(dropped)
    );
  }

  function _snapshotPosition(
    address user,
    uint256 reserveId
  ) internal view returns (PositionSnapshot memory s) {
    s.suppliedShares = spoke.getUserSuppliedShares(reserveId, user);
    s.suppliedAssets = spoke.getUserSuppliedAssets(reserveId, user);
    (s.drawnDebt, s.premiumDebt) = spoke.getUserDebt(reserveId, user);
    s.totalDebt = spoke.getUserTotalDebt(reserveId, user);
    s.premiumDebtRay = spoke.getUserPremiumDebtRay(reserveId, user);
    (s.usingAsCollateral, s.borrowing) = spoke.getUserReserveStatus(reserveId, user);
  }

  function _snapshotAccount(address user) internal view returns (AccountSnapshot memory s) {
    ISpoke.UserAccountData memory d = spoke.getUserAccountData(user);
    s.riskPremium = d.riskPremium;
    s.avgCollateralFactor = d.avgCollateralFactor;
    s.healthFactor = d.healthFactor;
    s.totalCollateralValue = d.totalCollateralValue;
    s.totalDebtValueRay = d.totalDebtValueRay;
    s.activeCollateralCount = d.activeCollateralCount;
    s.borrowCount = d.borrowCount;
    s.lastRiskPremium = spoke.getUserLastRiskPremium(user);
  }

  function _snapshotReserve(uint256 reserveId) internal view returns (ReserveSnapshot memory s) {
    s.suppliedShares = spoke.getReserveSuppliedShares(reserveId);
    s.suppliedAssets = spoke.getReserveSuppliedAssets(reserveId);
    (s.drawnDebt, s.premiumDebt) = spoke.getReserveDebt(reserveId);
    s.totalDebt = spoke.getReserveTotalDebt(reserveId);
  }

  function _assertPositionPreserved(
    PositionSnapshot memory pre,
    PositionSnapshot memory post,
    string memory ctx
  ) internal pure {
    assertEq(post.suppliedShares, pre.suppliedShares, string.concat(ctx, ': suppliedShares'));
    assertEq(post.suppliedAssets, pre.suppliedAssets, string.concat(ctx, ': suppliedAssets'));
    assertEq(post.drawnDebt, pre.drawnDebt, string.concat(ctx, ': drawnDebt'));
    assertEq(post.premiumDebt, pre.premiumDebt, string.concat(ctx, ': premiumDebt'));
    assertEq(post.totalDebt, pre.totalDebt, string.concat(ctx, ': totalDebt'));
    assertEq(post.premiumDebtRay, pre.premiumDebtRay, string.concat(ctx, ': premiumDebtRay'));
    assertEq(
      post.usingAsCollateral,
      pre.usingAsCollateral,
      string.concat(ctx, ': usingAsCollateral')
    );
    assertEq(post.borrowing, pre.borrowing, string.concat(ctx, ': borrowing'));
  }

  function _assertAccountPreserved(
    AccountSnapshot memory pre,
    AccountSnapshot memory post,
    string memory ctx
  ) internal pure {
    assertEq(post.riskPremium, pre.riskPremium, string.concat(ctx, ': riskPremium'));
    assertEq(post.avgCollateralFactor, pre.avgCollateralFactor, string.concat(ctx, ': avgCF'));
    assertEq(post.healthFactor, pre.healthFactor, string.concat(ctx, ': healthFactor'));
    assertEq(
      post.totalCollateralValue,
      pre.totalCollateralValue,
      string.concat(ctx, ': collateral')
    );
    assertEq(post.totalDebtValueRay, pre.totalDebtValueRay, string.concat(ctx, ': debtValue'));
    assertEq(
      post.activeCollateralCount,
      pre.activeCollateralCount,
      string.concat(ctx, ': activeColl')
    );
    assertEq(post.borrowCount, pre.borrowCount, string.concat(ctx, ': borrowCount'));
    assertEq(post.lastRiskPremium, pre.lastRiskPremium, string.concat(ctx, ': lastRiskPremium'));
  }

  function _assertReservePreserved(
    ReserveSnapshot memory pre,
    ReserveSnapshot memory post,
    string memory ctx
  ) internal pure {
    assertEq(post.suppliedShares, pre.suppliedShares, string.concat(ctx, ': res suppliedShares'));
    assertEq(post.suppliedAssets, pre.suppliedAssets, string.concat(ctx, ': res suppliedAssets'));
    assertEq(post.drawnDebt, pre.drawnDebt, string.concat(ctx, ': res drawnDebt'));
    assertEq(post.premiumDebt, pre.premiumDebt, string.concat(ctx, ': res premiumDebt'));
    assertEq(post.totalDebt, pre.totalDebt, string.concat(ctx, ': res totalDebt'));
  }
}
