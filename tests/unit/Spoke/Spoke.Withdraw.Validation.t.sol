// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawValidationTest is SpokeBase {
  function test_withdraw_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReservePausedFlag(spoke1, daiReserveId, true);
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

    assertEq(spoke1.getUserSuppliedAmount(reserveId, alice), 0);

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    spoke1.withdraw(reserveId, amount, alice);
  }

  function test_withdraw_fuzz_revertsWith_InsufficientSupply_zero_supplied(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    uint256 reserveId = _daiReserveId(spoke1);

    assertEq(spoke1.getUserSuppliedAmount(reserveId, alice), 0);

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    spoke1.withdraw(reserveId, amount, alice);
  }
}
