// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawValidationTest is SpokeBase {
  function test_withdraw_revertsWith_ReserveNotActive() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReserveActiveFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.prank(bob);
    spoke1.withdraw(daiReserveId, amount, bob);
  }

  function test_withdraw_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

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

  function test_withdraw_revertsWith_InsufficientSupply_zero_supplied() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 1;

    assertEq(spoke1.getUserSuppliedAmount(reserveId, alice), 0);

    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, 0));
    vm.prank(alice);
    spoke1.withdraw(reserveId, amount, alice);
  }

  function test_withdraw_fuzz_revertsWith_InsufficientSupply_zero_supplied(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    uint256 reserveId = _daiReserveId(spoke1);

    assertEq(spoke1.getUserSuppliedAmount(reserveId, alice), 0);

    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, 0));
    vm.prank(alice);
    spoke1.withdraw(reserveId, amount, alice);
  }

  // Withdraw reverts when there is not enough avaulable liquidity
  function test_withdraw_revertsWith_InsufficientSupply_with_supply() public {
    uint256 amount = 100e18;
    uint256 reserveId = _daiReserveId(spoke1);

    // User spoke supply
    Utils.supply({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      onBehalfOf: alice
    });

    uint256 withdrawalLimit = getWithdrawalLimit(spoke1, reserveId, alice);
    assertGt(withdrawalLimit, 0);

    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, withdrawalLimit));
    vm.prank(alice);
    spoke1.withdraw(reserveId, withdrawalLimit + 1, alice);

    // skip time but no index increase with no borrow
    skip(365 days);
    // withdrawal limit remains constant
    assertEq(withdrawalLimit, getWithdrawalLimit(spoke1, reserveId, alice));

    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, withdrawalLimit));
    vm.prank(alice);
    spoke1.withdraw(reserveId, withdrawalLimit + 1, alice);
  }

  // Withdrawal limit increases due to debt interest, but still cannot withdraw more than available liquidity
  function test_withdraw_revertsWith_InsufficientSupply_with_debt() public {
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;
    uint256 reserveId = _daiReserveId(spoke1);

    // Alice supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    setUsingAsCollateral(spoke1, alice, reserveId, true);

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, supplyAmount));
    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount + 1, to: bob});

    // accrue interest
    skip(365 days);

    uint256 newWithdrawalLimit = getWithdrawalLimit(spoke1, reserveId, alice);
    // newWithdrawalLimit with accrued interest should be greater than supplyAmount
    assertGt(newWithdrawalLimit, supplyAmount);

    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, newWithdrawalLimit));
    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: newWithdrawalLimit + 1, to: alice});
  }

  // Cannot withdraw more than available liquidity, before and after time skip, fuzzed
  function test_withdraw_fuzz_revertsWith_InsufficientSupply_with_debt(
    uint256 reserveId,
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 rate,
    uint256 skipTime
  ) public {
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2); // ensure it is within Collateral Factor
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    _mockInterestRateBps(rate);

    // Alice supply
    Utils.supply({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    setUsingAsCollateral(spoke1, alice, reserveId, true);
    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, supplyAmount));
    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount + 1, to: alice});

    // debt accrues
    skip(skipTime);

    uint256 newWithdrawalLimit = getWithdrawalLimit(spoke1, reserveId, alice);
    // newWithdrawalLimit with accrued interest should be greater than supplyAmount
    vm.assume(newWithdrawalLimit > supplyAmount);

    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, newWithdrawalLimit));
    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: newWithdrawalLimit + 1, to: alice});
  }
}
