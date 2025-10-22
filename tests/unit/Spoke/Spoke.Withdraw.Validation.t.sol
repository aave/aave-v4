// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawValidationTest is SpokeBase {
  function test_withdraw_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    _updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.withdraw(daiReserveId, amount, bob);
  }

  function test_withdraw_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.withdraw(reserveId, amount, bob);
  }

  /// @dev Test passes 1 as amount with no supplied assets.
  /// @dev The spoke contract changes the calling amount to the total user supplied, but since it's zero, it reverts.
  function test_withdraw_revertsWith_InvalidAmount_zero_supplied() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 1;

    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), 0);

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    spoke1.withdraw(reserveId, amount, alice);
  }

  function test_withdraw_fuzz_revertsWith_InsufficientSupply_zero_supplied(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    uint256 reserveId = _daiReserveId(spoke1);

    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), 0);

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    spoke1.withdraw(reserveId, amount, alice);
  }

  // Withdrawal limit increases due to debt interest, but still cannot withdraw more than available liquidity
  function test_withdraw_revertsWith_InsufficientLiquidity_with_debt() public {
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;
    uint256 reserveId = _daiReserveId(spoke1);

    // Alice supplies dai
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    vm.expectRevert(
      abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, supplyAmount - borrowAmount)
    );
    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount + 1, onBehalfOf: alice});

    // accrue interest
    skip(365 days);

    uint256 newWithdrawalLimit = getTotalWithdrawable(spoke1, reserveId, alice);
    // newWithdrawalLimit with accrued interest should be greater than supplyAmount
    assertGt(newWithdrawalLimit, supplyAmount);

    // Interest added on both sides, so can ignore
    vm.expectRevert(
      abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, supplyAmount - borrowAmount)
    );
    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: newWithdrawalLimit + 1, onBehalfOf: alice});
  }

  // Cannot withdraw more than available liquidity, before and after time skip, fuzzed
  function test_withdraw_fuzz_revertsWith_InsufficientLiquidity_with_debt(
    uint256 reserveId,
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 rate,
    uint256 skipTime
  ) public {
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_ALLOWED_ASSET_ID);
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2); // ensure it is within Collateral Factor
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    _mockInterestRateBps(rate);

    // Alice supply
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    vm.expectRevert(
      abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, supplyAmount - borrowAmount)
    );
    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount + 1, onBehalfOf: alice});

    // debt accrues
    skip(skipTime);

    uint256 newWithdrawalLimit = getTotalWithdrawable(spoke1, reserveId, alice);
    // newWithdrawalLimit with accrued interest should be greater than supplyAmount
    vm.assume(newWithdrawalLimit > supplyAmount);

    // Interest added on both sides, so can ignore
    vm.expectRevert(
      abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, supplyAmount - borrowAmount)
    );
    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: newWithdrawalLimit + 1, onBehalfOf: alice});
  }
}
