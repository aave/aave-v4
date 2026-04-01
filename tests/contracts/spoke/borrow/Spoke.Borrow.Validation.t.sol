// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeBorrowValidationTest is Base {
  using SafeCast for uint256;
  using ReserveFlagsMap for ReserveFlags;

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
    _updateReserveBorrowableFlag(spoke1, reserveId, false);
    assertFalse(spoke1.getReserve(reserveId).flags.borrowable());

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
    assertTrue(spoke1.getReserve(reserveId).flags.paused());

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

    _updateReserveFrozenFlag(spoke1, reserveId, true);
    assertTrue(spoke1.getReserve(reserveId).flags.frozen());

    // Bob try to draw
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.borrow(reserveId, 1, bob);
  }

  function test_borrow_revertsWith_InsufficientLiquidity() public {
    test_borrow_fuzz_revertsWith_InsufficientLiquidity({daiAmount: 100e18, wethAmount: 10e18});
  }

  function test_borrow_fuzz_revertsWith_InsufficientLiquidity(
    uint256 daiAmount,
    uint256 wethAmount
  ) public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    wethAmount = bound(wethAmount, 10, MAX_SUPPLY_AMOUNT);
    daiAmount = wethAmount / 10;
    uint256 borrowAmount = vm.randomUint(daiAmount + 1, MAX_SUPPLY_AMOUNT);

    // Bob supply weth
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: bob,
      amount: wethAmount,
      onBehalfOf: bob
    });

    // Alice supply dai
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiAmount,
      onBehalfOf: alice
    });

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
    _updateDrawCap(hub1, assetId, address(spoke1), drawCap);
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

    _updateDrawCap(hub1, daiAssetId, address(spoke1), drawCap);
    assertEq(hub1.getSpoke(daiAssetId, address(spoke1)).drawCap, drawCap);

    // Bob supply weth collateral
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Alice supply dai
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiAmount,
      onBehalfOf: alice
    });

    // Bob draw dai
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: drawAmount,
      onBehalfOf: bob
    });

    skip(skipTime);
    vm.assume(spoke1.getReserveTotalDebt(daiReserveId) > drawCap);

    // Additional supply to accrue interest
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });

    // Bob should be able to borrow 1 dai
    assertGt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, drawCap));
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: 1,
      onBehalfOf: bob
    });
  }

  function test_borrow_revertsWith_MaximumUserReservesExceeded() public {
    uint16 maxUserReservesLimit = (spoke1.getReserveCount() - 1).toUint16();
    _updateMaxUserReservesLimit(spoke1, maxUserReservesLimit);
    assertEq(spoke1.MAX_USER_RESERVES_LIMIT(), maxUserReservesLimit, 'Reserve limit adjusted');
    assertGt(spoke1.getReserveCount(), maxUserReservesLimit, 'More reserves than limit');

    for (uint256 i = 0; i < maxUserReservesLimit; ++i) {
      SpokeActions.supplyCollateral({
        spoke: spoke1,
        reserveId: i,
        caller: bob,
        amount: MAX_SUPPLY_AMOUNT,
        onBehalfOf: bob
      });
      SpokeActions.borrow({
        spoke: spoke1,
        reserveId: i,
        caller: bob,
        amount: 1e18,
        onBehalfOf: bob
      });
    }
    ISpoke.UserAccountData memory accountData = spoke1.getUserAccountData(bob);
    assertEq(accountData.borrowCount, maxUserReservesLimit, 'Bob has reached the borrow limit');

    // Ensure the next reserve has supply
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: maxUserReservesLimit,
      caller: bob,
      amount: MAX_SUPPLY_AMOUNT,
      onBehalfOf: bob
    });

    // Bob tries to borrow from the last reserve - should revert due to limit
    vm.expectRevert(ISpoke.MaximumUserReservesExceeded.selector);
    vm.prank(bob);
    spoke1.borrow(maxUserReservesLimit, 1e18, bob);
  }

  /// @dev Test that borrows up to the user reserves limit, repays one reserve, and then borrows again.
  function test_borrow_to_limit_repay_borrow_again() public {
    uint16 maxUserReservesLimit = (spoke1.getReserveCount() - 1).toUint16();
    _updateMaxUserReservesLimit(spoke1, maxUserReservesLimit);
    assertEq(spoke1.MAX_USER_RESERVES_LIMIT(), maxUserReservesLimit, 'Reserve limit adjusted');
    assertGt(spoke1.getReserveCount(), maxUserReservesLimit, 'More reserves than limit');

    uint256 borrowAmount = 1e18;
    for (uint256 i = 0; i < maxUserReservesLimit; ++i) {
      SpokeActions.supplyCollateral({
        spoke: spoke1,
        reserveId: i,
        caller: bob,
        amount: MAX_SUPPLY_AMOUNT,
        onBehalfOf: bob
      });
      SpokeActions.borrow({
        spoke: spoke1,
        reserveId: i,
        caller: bob,
        amount: borrowAmount,
        onBehalfOf: bob
      });
    }

    ISpoke.UserAccountData memory accountData = spoke1.getUserAccountData(bob);
    assertEq(accountData.borrowCount, maxUserReservesLimit, 'Bob has reached the borrow limit');

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: 0,
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    accountData = spoke1.getUserAccountData(bob);
    assertEq(accountData.borrowCount, maxUserReservesLimit - 1, 'Bob has repaid one reserve');

    // Ensure the next reserve has supply
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: maxUserReservesLimit,
      caller: bob,
      amount: MAX_SUPPLY_AMOUNT,
      onBehalfOf: bob
    });

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: maxUserReservesLimit,
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    accountData = spoke1.getUserAccountData(bob);
    assertEq(accountData.borrowCount, maxUserReservesLimit, 'Bob has reached the borrow limit');
  }

  /// @dev Test showing that when the borrow limit is max, all reserves can be borrowed.
  function test_borrow_unlimited_whenLimitIsMax() public {
    assertEq(spoke1.MAX_USER_RESERVES_LIMIT(), MAX_ALLOWED_USER_RESERVES_LIMIT);

    uint256 reservesToBorrow = spoke1.getReserveCount();

    for (uint256 i = 0; i < reservesToBorrow; ++i) {
      SpokeActions.supplyCollateral({
        spoke: spoke1,
        reserveId: i,
        caller: bob,
        amount: MAX_SUPPLY_AMOUNT,
        onBehalfOf: bob
      });
      SpokeActions.borrow({
        spoke: spoke1,
        reserveId: i,
        caller: bob,
        amount: 1e18,
        onBehalfOf: bob
      });
    }

    ISpoke.UserAccountData memory accountData = spoke1.getUserAccountData(bob);
    assertEq(accountData.borrowCount, reservesToBorrow);
  }
}
