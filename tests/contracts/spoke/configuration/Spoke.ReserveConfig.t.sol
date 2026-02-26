// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeReserveConfigTest is Base {
  function setUp() public override {
    super.setUp();
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 100e18);
  }

  function test_supply_paused_frozen_scenarios() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    // paused / frozen; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.supply(spoke1, daiReserveId, bob, amount, bob);

    // not paused / frozen; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    SpokeActions.supply(spoke1, daiReserveId, bob, amount, bob);

    // paused / not frozen; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.supply(spoke1, daiReserveId, bob, amount, bob);

    // not paused / not frozen; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    _deal(spoke1, daiReserveId, bob, amount);
    SpokeActions.approve(spoke1, daiReserveId, bob, amount);
    SpokeActions.supply(spoke1, daiReserveId, bob, amount, bob);
  }

  function test_withdraw_paused_scenarios() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 100e18;
    uint256 withdrawAmount = 1e18;

    // ensure user can withdraw
    _deal(spoke1, daiReserveId, bob, supplyAmount);
    SpokeActions.approve(spoke1, daiReserveId, bob, supplyAmount);
    SpokeActions.supplyCollateral(spoke1, daiReserveId, bob, supplyAmount, bob);

    // frozen does not matter
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.withdraw(spoke1, daiReserveId, bob, withdrawAmount, bob);

    // unpaused; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    SpokeActions.withdraw(spoke1, daiReserveId, bob, withdrawAmount, bob);
  }

  function test_borrow_fuzz_borrowable_paused_frozen_scenarios(
    bool borrowable,
    bool paused,
    bool frozen
  ) public {
    _increaseCollateralSupply(spoke1, _daiReserveId(spoke1), 100e18, bob);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 1;

    // paused / borrowable / frozen; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, paused);
    _updateReserveBorrowableFlag(spoke1, daiReserveId, borrowable);
    _updateReserveFrozenFlag(spoke1, daiReserveId, frozen);
    if (paused) {
      vm.expectRevert(ISpoke.ReservePaused.selector);
    } else if (frozen) {
      vm.expectRevert(ISpoke.ReserveFrozen.selector);
    } else if (!borrowable) {
      vm.expectRevert(ISpoke.ReserveNotBorrowable.selector);
    }
    SpokeActions.borrow(spoke1, daiReserveId, bob, amount, bob);
  }

  function test_repay_fuzz_paused_scenarios(bool frozen) public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // create a simple debt position for bob
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 wethCollateral = 10e18;
    uint256 daiLiquidity = 1_000e18;
    uint256 borrowAmount = 100e18;

    _deal(spoke1, wethReserveId, bob, wethCollateral);
    SpokeActions.approve(spoke1, wethReserveId, bob, wethCollateral);
    SpokeActions.supplyCollateral(spoke1, wethReserveId, bob, wethCollateral, bob);

    _deal(spoke1, daiReserveId, alice, daiLiquidity);
    SpokeActions.approve(spoke1, daiReserveId, alice, daiLiquidity);
    SpokeActions.supply(spoke1, daiReserveId, alice, daiLiquidity, alice);

    SpokeActions.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);
    SpokeActions.approve(spoke1, daiReserveId, bob, UINT256_MAX);

    _updateReserveFrozenFlag(spoke1, daiReserveId, frozen);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.repay(spoke1, daiReserveId, bob, borrowAmount, bob);

    // unpaused; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    SpokeActions.repay(spoke1, daiReserveId, bob, borrowAmount, bob);
  }

  function test_setUsingAsCollateral_fuzz_paused_frozen_scenarios(bool frozen) public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    _updateReserveFrozenFlag(spoke1, daiReserveId, frozen);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.setUsingAsCollateral(spoke1, daiReserveId, alice, true, alice);

    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    _updateReservePausedFlag(spoke1, daiReserveId, false);

    // alice enables collateral
    SpokeActions.setUsingAsCollateral(spoke1, daiReserveId, alice, true, alice);
    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, alice), 'alice using as collateral');

    // frozen: disallow when enabling, allow when disabling
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    SpokeActions.setUsingAsCollateral(spoke1, daiReserveId, bob, true, bob);

    SpokeActions.setUsingAsCollateral(spoke1, daiReserveId, alice, false, alice);
    assertFalse(_isUsingAsCollateral(spoke1, daiReserveId, alice));
  }
}
