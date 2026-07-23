// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ForkBase} from 'tests/fork/ForkBase.t.sol';

/// @notice Proves that upgrading a live mainnet Spoke to the position-nonces implementation preserves
///         existing storage and user positions byte-for-byte. The default-salt position must keep
///         resolving to the legacy address-keyed storage slot (see `_getPositionIdentifier`).
contract SpokeUpgradePositionPreservationForkTest is ForkBase {
  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');
  address internal carol = makeAddr('carol');

  function test_supplierPositionPreserved() public onFork {
    (uint256 reserveId, ) = _collateralAndBorrowReserves();
    _seedSupply(alice, reserveId, 1000 * _unit(reserveId));

    PositionSnapshot memory prePos = _snapshotPosition(alice, reserveId);
    AccountSnapshot memory preAcc = _snapshotAccount(alice);
    assertGt(prePos.suppliedShares, 0, 'precondition: alice supplied');

    _upgradeSpoke();

    _assertPositionPreserved(prePos, _snapshotPosition(alice, reserveId), 'alice');
    _assertAccountPreserved(preAcc, _snapshotAccount(alice), 'alice');
  }

  function test_borrowerPositionPreserved() public onFork {
    (uint256 collId, uint256 borrowId) = _collateralAndBorrowReserves();
    uint256 borrowAmount = _unit(borrowId); // precompute: an arg-call would consume the prank below

    _seedSupply(bob, collId, 1000 * _unit(collId));
    vm.prank(bob);
    spoke.setUsingAsCollateral(collId, true, bob);
    vm.prank(bob);
    spoke.borrow(borrowId, borrowAmount, bob);

    PositionSnapshot memory preColl = _snapshotPosition(bob, collId);
    PositionSnapshot memory preDebt = _snapshotPosition(bob, borrowId);
    AccountSnapshot memory preAcc = _snapshotAccount(bob);
    assertTrue(preColl.usingAsCollateral, 'precondition: collateral enabled');
    assertGt(preDebt.totalDebt, 0, 'precondition: bob borrowed');

    _upgradeSpoke();

    _assertPositionPreserved(preColl, _snapshotPosition(bob, collId), 'bob collateral');
    _assertPositionPreserved(preDebt, _snapshotPosition(bob, borrowId), 'bob debt');
    _assertAccountPreserved(preAcc, _snapshotAccount(bob), 'bob account');
  }

  /// @dev The regression guard: without the `_getPositionIdentifier` fix, the default position would
  ///      be looked up under `keccak256(user, 0)` after the upgrade and read as empty.
  function test_defaultSaltMapsToLegacyAddressSlot() public onFork {
    (uint256 reserveId, ) = _collateralAndBorrowReserves();
    _seedSupply(carol, reserveId, 1000 * _unit(reserveId));

    uint256 preShares = spoke.getUserSuppliedShares(reserveId, carol);
    assertGt(preShares, 0, 'precondition: carol supplied');

    _upgradeSpoke();

    assertEq(
      spoke.getUserSuppliedShares(reserveId, carol),
      preShares,
      'default position orphaned by upgrade'
    );
    assertEq(
      spoke.getUserSuppliedShares(reserveId, carol, bytes32(0)),
      preShares,
      'default getter disagrees with explicit default salt'
    );
  }

  function test_reserveAggregatesAndImmutablesPreserved() public onFork {
    uint256 count = spoke.getReserveCount();
    uint256 n = count < 12 ? count : 12;

    ReserveSnapshot[] memory pre = new ReserveSnapshot[](n);
    for (uint256 i = 0; i < n; i++) {
      pre[i] = _snapshotReserve(i);
    }
    address preOracle = spoke.ORACLE();
    uint16 preMax = spoke.MAX_USER_RESERVES_LIMIT();
    ISpoke.LiquidationConfig memory preLiq = spoke.getLiquidationConfig();

    _upgradeSpoke();

    for (uint256 i = 0; i < n; i++) {
      _assertReservePreserved(pre[i], _snapshotReserve(i), vm.toString(i));
    }
    assertEq(spoke.ORACLE(), preOracle, 'ORACLE changed');
    assertEq(spoke.MAX_USER_RESERVES_LIMIT(), preMax, 'MAX_USER_RESERVES_LIMIT changed');

    ISpoke.LiquidationConfig memory postLiq = spoke.getLiquidationConfig();
    assertEq(postLiq.targetHealthFactor, preLiq.targetHealthFactor, 'targetHealthFactor');
    assertEq(postLiq.healthFactorForMaxBonus, preLiq.healthFactorForMaxBonus, 'hfForMaxBonus');
    assertEq(postLiq.liquidationBonusFactor, preLiq.liquidationBonusFactor, 'liqBonusFactor');
  }
}
