// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ForkBase} from 'tests/fork/ForkBase.t.sol';

/// @notice Full-lifecycle integration tests run against a live mainnet Spoke AFTER it has been upgraded
///         to the position-nonces implementation: pre-existing positions keep working, and the new
///         salt-based positions behave as isolated sub-accounts.
contract SpokeUpgradeIntegrationForkTest is ForkBase {
  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');
  address internal dave = makeAddr('dave');
  address internal liquidator = makeAddr('liquidator');

  /// @dev Supplies collateral, enables it, and borrows a small amount for `user`.
  function _seedBorrower(
    address user,
    uint256 collId,
    uint256 borrowId
  ) internal returns (uint256 collAmount, uint256 borrowAmount) {
    collAmount = 1000 * _unit(collId);
    borrowAmount = _unit(borrowId);
    _seedSupply(user, collId, collAmount);
    vm.prank(user);
    spoke.setUsingAsCollateral(collId, true, user);
    vm.prank(user);
    spoke.borrow(borrowId, borrowAmount, user);
  }

  function test_withdrawAfterUpgrade() public onFork {
    (uint256 reserveId, ) = _collateralAndBorrowReserves();
    _seedSupply(alice, reserveId, 1000 * _unit(reserveId));
    _upgradeSpoke();

    address underlying = spoke.getReserve(reserveId).underlying;
    uint256 sharesBefore = spoke.getUserSuppliedShares(reserveId, alice);
    uint256 balanceBefore = IERC20(underlying).balanceOf(alice);
    uint256 withdrawAmount = spoke.getUserSuppliedAssets(reserveId, alice) / 2;

    vm.prank(alice);
    spoke.withdraw(reserveId, withdrawAmount, alice);

    assertLt(spoke.getUserSuppliedShares(reserveId, alice), sharesBefore, 'shares not reduced');
    assertGt(IERC20(underlying).balanceOf(alice), balanceBefore, 'no assets received');
  }

  function test_repayAfterUpgrade() public onFork {
    (uint256 collId, uint256 borrowId) = _collateralAndBorrowReserves();
    _seedBorrower(bob, collId, borrowId);
    _upgradeSpoke();

    uint256 debtBefore = spoke.getUserTotalDebt(borrowId, bob);
    assertGt(debtBefore, 0, 'precondition: bob has debt');

    address debtAsset = spoke.getReserve(borrowId).underlying;
    deal(debtAsset, bob, debtBefore * 2);
    vm.startPrank(bob);
    IERC20(debtAsset).approve(address(spoke), type(uint256).max);
    spoke.repay(borrowId, debtBefore * 2, bob);
    vm.stopPrank();

    assertEq(spoke.getUserTotalDebt(borrowId, bob), 0, 'debt not fully repaid');
  }

  function test_borrowMoreAfterUpgrade() public onFork {
    (uint256 collId, uint256 borrowId) = _collateralAndBorrowReserves();
    _seedBorrower(bob, collId, borrowId);
    _upgradeSpoke();

    uint256 drawnBefore = spoke.getUserPosition(borrowId, bob).drawnShares;
    uint256 borrowAmount = _unit(borrowId); // precompute: an arg-call would consume the prank below
    vm.prank(bob);
    spoke.borrow(borrowId, borrowAmount, bob);

    assertGt(spoke.getUserPosition(borrowId, bob).drawnShares, drawnBefore, 'debt not increased');
  }

  function test_toggleCollateralAfterUpgrade() public onFork {
    (uint256 reserveId, ) = _collateralAndBorrowReserves();
    _seedSupply(alice, reserveId, 1000 * _unit(reserveId));
    _upgradeSpoke();

    vm.prank(alice);
    spoke.setUsingAsCollateral(reserveId, true, alice);
    (bool enabled, ) = spoke.getUserReserveStatus(reserveId, alice);
    assertTrue(enabled, 'collateral not enabled');

    vm.prank(alice);
    spoke.setUsingAsCollateral(reserveId, false, alice);
    (enabled, ) = spoke.getUserReserveStatus(reserveId, alice);
    assertFalse(enabled, 'collateral not disabled');
  }

  /// @dev A non-default salt opens an isolated sub-account that does not touch the default position.
  function test_saltedPositionIsIsolated() public onFork {
    (uint256 reserveId, ) = _collateralAndBorrowReserves();
    uint256 amount = 1000 * _unit(reserveId);
    _seedSupply(alice, reserveId, amount); // default position
    _upgradeSpoke();

    uint256 defaultSharesBefore = spoke.getUserSuppliedShares(reserveId, alice);
    assertGt(defaultSharesBefore, 0, 'precondition: default position');

    bytes32 salt = keccak256('position-2');
    address underlying = spoke.getReserve(reserveId).underlying;
    deal(underlying, alice, amount);
    vm.startPrank(alice);
    IERC20(underlying).approve(address(spoke), amount);
    spoke.supply(reserveId, amount, alice, salt);
    vm.stopPrank();

    assertEq(
      spoke.getUserSuppliedShares(reserveId, alice),
      defaultSharesBefore,
      'default position affected by salted supply'
    );
    assertGt(spoke.getUserSuppliedShares(reserveId, alice, salt), 0, 'salted position not created');
  }

  function test_multicallAfterUpgrade() public onFork {
    (uint256 reserveId, ) = _collateralAndBorrowReserves();
    _upgradeSpoke();

    uint256 amount = 1000 * _unit(reserveId);
    address underlying = spoke.getReserve(reserveId).underlying;
    deal(underlying, alice, amount);

    // `supply` and `setUsingAsCollateral` are overloaded (salt variants), so encode by signature.
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature('supply(uint256,uint256,address)', reserveId, amount, alice);
    calls[1] = abi.encodeWithSignature(
      'setUsingAsCollateral(uint256,bool,address)',
      reserveId,
      true,
      alice
    );

    vm.startPrank(alice);
    IERC20(underlying).approve(address(spoke), amount);
    spoke.multicall(calls);
    vm.stopPrank();

    assertGt(spoke.getUserSuppliedShares(reserveId, alice), 0, 'multicall supply failed');
    (bool enabled, ) = spoke.getUserReserveStatus(reserveId, alice);
    assertTrue(enabled, 'multicall collateral toggle failed');
  }

  function test_liquidationAfterUpgrade() public onFork {
    (uint256 collId, uint256 borrowId) = _collateralAndBorrowReserves();
    _seedBorrower(dave, collId, borrowId);
    _upgradeSpoke();

    // Crash the collateral price far enough below the current health factor to force liquidation.
    uint256 hf0 = spoke.getUserAccountData(dave).healthFactor;
    uint256 denominator = (hf0 / 1e18 + 2) * 10;
    _dropReservePrice(collId, 1, denominator);
    assertLt(
      spoke.getUserAccountData(dave).healthFactor,
      1e18,
      'precondition: position not liquidatable'
    );

    uint256 debtBefore = spoke.getUserTotalDebt(borrowId, dave);
    uint256 collSharesBefore = spoke.getUserSuppliedShares(collId, dave);

    address debtAsset = spoke.getReserve(borrowId).underlying;
    deal(debtAsset, liquidator, debtBefore * 2);
    vm.startPrank(liquidator);
    IERC20(debtAsset).approve(address(spoke), type(uint256).max);
    spoke.liquidationCall(collId, borrowId, dave, type(uint256).max, false);
    vm.stopPrank();

    // The collateral is worthless after the crash, so it is fully seized.
    assertLt(spoke.getUserSuppliedShares(collId, dave), collSharesBefore, 'collateral not seized');
  }
}
