// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeReserveConfigTest is SpokeBase {
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
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);

    // not paused / frozen; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);

    // paused / not frozen; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);

    // not paused / not frozen; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    deal(spoke1, daiReserveId, bob, amount);
    Utils.approve(spoke1, daiReserveId, bob, amount);
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);
  }

  function test_withdraw_paused_scenarios() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 100e18;
    uint256 withdrawAmount = 1e18;

    // ensure user can withdraw
    deal(spoke1, daiReserveId, bob, supplyAmount);
    Utils.approve(spoke1, daiReserveId, bob, supplyAmount);
    Utils.supplyCollateral(spoke1, daiReserveId, bob, supplyAmount, bob);

    // frozen does not matter
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    Utils.withdraw(spoke1, daiReserveId, bob, withdrawAmount, bob);

    // unpaused; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    Utils.withdraw(spoke1, daiReserveId, bob, withdrawAmount, bob);
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
    Utils.borrow(spoke1, daiReserveId, bob, amount, bob);
  }

  function test_repay_fuzz_paused_scenarios(bool frozen) public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // create a simple debt position for bob
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 wethCollateral = 10e18;
    uint256 daiLiquidity = 1_000e18;
    uint256 borrowAmount = 100e18;

    deal(spoke1, wethReserveId, bob, wethCollateral);
    Utils.approve(spoke1, wethReserveId, bob, wethCollateral);
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollateral, bob);

    deal(spoke1, daiReserveId, alice, daiLiquidity);
    Utils.approve(spoke1, daiReserveId, alice, daiLiquidity);
    Utils.supply(spoke1, daiReserveId, alice, daiLiquidity, alice);

    Utils.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);
    Utils.approve(spoke1, daiReserveId, bob, UINT256_MAX);

    _updateReserveFrozenFlag(spoke1, daiReserveId, frozen);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    Utils.repay(spoke1, daiReserveId, bob, borrowAmount, bob);

    // unpaused; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    Utils.repay(spoke1, daiReserveId, bob, borrowAmount, bob);
  }

  function test_setUsingAsCollateral_fuzz_paused_frozen_scenarios(bool frozen) public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    _updateReserveFrozenFlag(spoke1, daiReserveId, frozen);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    Utils.setUsingAsCollateral(spoke1, daiReserveId, alice, true, alice);

    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    _updateReservePausedFlag(spoke1, daiReserveId, false);

    // alice enables collateral
    Utils.setUsingAsCollateral(spoke1, daiReserveId, alice, true, alice);
    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, alice), 'alice using as collateral');

    // frozen: disallow when enabling, allow when disabling
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    Utils.setUsingAsCollateral(spoke1, daiReserveId, bob, true, bob);

    Utils.setUsingAsCollateral(spoke1, daiReserveId, alice, false, alice);
    assertFalse(_isUsingAsCollateral(spoke1, daiReserveId, alice));
  }
}
