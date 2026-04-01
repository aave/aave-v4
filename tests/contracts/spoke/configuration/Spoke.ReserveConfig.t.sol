// SPDX-License-Identifier: MIT
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
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    // not paused / frozen; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    // paused / not frozen; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    // not paused / not frozen; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    _deal(spoke1, daiReserveId, bob, amount);
    SpokeActions.approve({spoke: spoke1, reserveId: daiReserveId, owner: bob, amount: amount});
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });
  }

  function test_withdraw_paused_scenarios() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 100e18;
    uint256 withdrawAmount = 1e18;

    // ensure user can withdraw
    _deal(spoke1, daiReserveId, bob, supplyAmount);
    SpokeActions.approve({
      spoke: spoke1,
      reserveId: daiReserveId,
      owner: bob,
      amount: supplyAmount
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    // frozen does not matter
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: withdrawAmount,
      onBehalfOf: bob
    });

    // unpaused; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: withdrawAmount,
      onBehalfOf: bob
    });
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
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });
  }

  function test_repay_fuzz_paused_scenarios(bool frozen) public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // create a simple debt position for bob
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 wethCollateral = 10e18;
    uint256 daiLiquidity = 1_000e18;
    uint256 borrowAmount = 100e18;

    _deal(spoke1, wethReserveId, bob, wethCollateral);
    SpokeActions.approve({
      spoke: spoke1,
      reserveId: wethReserveId,
      owner: bob,
      amount: wethCollateral
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: bob,
      amount: wethCollateral,
      onBehalfOf: bob
    });

    _deal(spoke1, daiReserveId, alice, daiLiquidity);
    SpokeActions.approve({
      spoke: spoke1,
      reserveId: daiReserveId,
      owner: alice,
      amount: daiLiquidity
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiLiquidity,
      onBehalfOf: alice
    });

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });
    SpokeActions.approve({spoke: spoke1, reserveId: daiReserveId, owner: bob, amount: UINT256_MAX});

    _updateReserveFrozenFlag(spoke1, daiReserveId, frozen);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // unpaused; succeeds
    _updateReservePausedFlag(spoke1, daiReserveId, false);
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });
  }

  function test_setUsingAsCollateral_fuzz_paused_frozen_scenarios(bool frozen) public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    _updateReserveFrozenFlag(spoke1, daiReserveId, frozen);

    // paused; reverts
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      usingAsCollateral: true,
      onBehalfOf: alice
    });

    _updateReserveFrozenFlag(spoke1, daiReserveId, false);
    _updateReservePausedFlag(spoke1, daiReserveId, false);

    // alice enables collateral
    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      usingAsCollateral: true,
      onBehalfOf: alice
    });
    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, alice), 'alice using as collateral');

    // frozen: disallow when enabling, allow when disabling
    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      usingAsCollateral: true,
      onBehalfOf: bob
    });

    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      usingAsCollateral: false,
      onBehalfOf: alice
    });
    assertFalse(_isUsingAsCollateral(spoke1, daiReserveId, alice));
  }
}
