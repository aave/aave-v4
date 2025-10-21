// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowValidationTest is SpokeBase {
  using SafeCast for uint256;

  function test_borrow_revertsWith_ReserveNotBorrowable() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    test_borrow_fuzz_revertsWith_ReserveNotBorrowable({reserveId: daiReserveId, amount: 1});
  }

  function test_borrow_fuzz_revertsWith_ReserveNotBorrowable(
    uint256 reserveId,
    uint256 amount
  ) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    // set reserve not borrowable
    updateReserveBorrowableFlag(spoke1, reserveId, false);
    assertFalse(spoke1.getReserve(reserveId).borrowable);

    // Bob tries to draw
    vm.expectRevert(ISpoke.ReserveNotBorrowable.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, amount, bob);
  }

  function test_borrow_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1; // invalid reserveId

    test_borrow_fuzz_revertsWith_ReserveNotListed({reserveId: reserveId, amount: 1});
  }

  function test_borrow_fuzz_revertsWith_ReserveNotListed(uint256 reserveId, uint256 amount) public {
    vm.assume(reserveId >= spoke1.getReserveCount());
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    // Bob try to draw some dai
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, amount, bob);
  }

  function test_borrow_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    test_borrow_fuzz_revertsWith_ReservePaused({reserveId: daiReserveId, amount: 1});
  }

  function test_borrow_fuzz_revertsWith_ReservePaused(uint256 reserveId, uint256 amount) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    _updateReservePausedFlag(spoke1, reserveId, true);
    assertTrue(spoke1.getReserve(reserveId).paused);

    // Bob try to draw
    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, 1, bob);
  }

  function test_borrow_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    test_borrow_fuzz_revertsWith_ReserveFrozen({reserveId: daiReserveId, amount: 1});
  }

  function test_borrow_fuzz_revertsWith_ReserveFrozen(uint256 reserveId, uint256 amount) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateReserveFrozenFlag(spoke1, reserveId, true);
    assertTrue(spoke1.getReserve(reserveId).frozen);

    // Bob try to draw
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, 1, bob);
  }

  function test_borrow_revertsWith_InsufficientLiquidity() public {
    test_borrow_fuzz_revertsWith_InsufficientLiquidity({
      daiAmount: 100e18,
      wethAmount: 10e18,
      borrowAmount: 100e18 + 1
    });
  }

  function test_borrow_fuzz_revertsWith_InsufficientLiquidity(
    uint256 daiAmount,
    uint256 wethAmount,
    uint256 borrowAmount
  ) public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    wethAmount = bound(wethAmount, 10, MAX_SUPPLY_AMOUNT);
    daiAmount = wethAmount / 10;
    vm.assume(borrowAmount > daiAmount);

    // Bob supply weth
    Utils.supply(spoke1, wethReserveId, bob, wethAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw more than supplied dai amount
    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, daiAmount));
    vm.prank(bob);
    spoke1.borrow(daiReserveId, borrowAmount, bob);
  }

  function test_borrow_revertsWith_InvalidAmount() public {
    // Bob draws 0 dai
    test_borrow_fuzz_revertsWith_InvalidAmount(_daiReserveId(spoke1));
  }

  function test_borrow_fuzz_revertsWith_InvalidAmount(uint256 reserveId) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);

    // Bob draws 0
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, 0, bob);
  }

  function test_borrow_fuzz_revertsWith_DrawCapExceeded(uint256 reserveId, uint40 drawCap) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    drawCap = bound(drawCap, 1, MAX_SUPPLY_AMOUNT / 10 ** tokenList.dai.decimals()).toUint40();

    uint256 drawAmount = drawCap * 10 ** tokenList.dai.decimals() + 1;

    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    updateDrawCap(hub1, assetId, address(spoke1), drawCap);
    assertEq(hub1.getSpoke(assetId, address(spoke1)).drawCap, drawCap);

    // Bob borrow dai amount exceeding draw cap
    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    vm.prank(bob);
    spoke1.borrow(reserveId, drawAmount, bob);
  }

  function test_borrow_fuzz_revertsWith_DrawCapExceeded_due_to_interest(uint256 skipTime) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint40 drawCap = 100;
    uint256 daiAmount = drawCap * 10 ** tokenList.dai.decimals();
    uint256 wethSupplyAmount = 10e18;
    uint256 drawAmount = daiAmount - 1;

    updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);
    assertEq(hub1.getSpoke(daiAssetId, address(spoke1)).drawCap, drawCap);

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw dai
    Utils.borrow(spoke1, daiReserveId, bob, drawAmount, bob);

    skip(skipTime);
    vm.assume(spoke1.getReserveTotalDebt(daiReserveId) > drawCap);

    // Additional supply to accrue interest
    Utils.supply(spoke1, daiReserveId, bob, 1e18, bob);

    // Bob should be able to borrow 1 dai
    assertGt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    Utils.borrow(spoke1, daiReserveId, bob, 1, bob);
  }
}
