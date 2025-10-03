// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawHealthFactorTest is SpokeBase {
  /// @dev cannot withdraw an amount if resulting withdrawal would result in HF < threshold
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_singleBorrow() public {
    uint256 collAmount = 1e18; // $2k in weth
    uint256 collReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: collReserveId,
      debtReserveId: debtReserveId,
      collAmount: collAmount
    });

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collReserveId,
      caller: alice,
      amount: collAmount,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: bob,
      amount: maxDebtAmount,
      onBehalfOf: bob
    });

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: alice,
      amount: maxDebtAmount,
      onBehalfOf: alice
    });

    assertEq(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any amount will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: collReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if resulting withdrawal would result in HF < threshold
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_singleBorrow(
    uint256 debtAmount
  ) public {
    debtAmount = bound(debtAmount, 1, MAX_SUPPLY_AMOUNT); // to stay within uint256 bounds for _calcMaxDebtAmount
    uint256 collReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    uint256 collAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: collReserveId,
      debtReserveId: debtReserveId,
      debtAmount: debtAmount
    });

    vm.assume(collAmount < MAX_SUPPLY_AMOUNT && collAmount > 1);

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collReserveId,
      caller: alice,
      amount: collAmount,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: bob,
      amount: debtAmount,
      onBehalfOf: bob
    });

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: alice,
      amount: debtAmount,
      onBehalfOf: alice
    });

    assertGe(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing coll will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: collReserveId, amount: collAmount, onBehalfOf: alice}); // todo: resolve precision, should be 1?
  }

  /// @dev cannot unset a collateral if unsetting would result in HF < threshold
  function test_unsetCollateral_fuzz_revertsWith_HealthFactorBelowThreshold(
    uint256 daiBorrowAmount
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 wbtcSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wbtcReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), daiBorrowAmount);

    Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), alice, wbtcSupplyAmount, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(_wbtcReserveId(spoke1), false, alice);
  }

  /// @dev cannot withdraw an amount if HF < threshold due to price drop
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_price_drop() public {
    uint256 collAmount = 1e18;
    uint256 collReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: collReserveId,
      debtReserveId: debtReserveId,
      collAmount: collAmount
    });

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collReserveId,
      caller: alice,
      amount: collAmount,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: bob,
      amount: maxDebtAmount,
      onBehalfOf: bob
    });

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: alice,
      amount: maxDebtAmount,
      onBehalfOf: alice
    });

    // alice is above HF threshold right after borrowing
    assertGe(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop by half so that alice is undercollateralized
    _mockReservePriceByPercent(spoke1, collReserveId, 50_00);
    assertLt(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any amount will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: collReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if resulting withdrawal would result in HF < threshold
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_price_drop(
    uint256 collAmount,
    uint256 newPrice
  ) public {
    uint256 currPrice = IPriceOracle(spoke1.ORACLE()).getReservePrice(_wethReserveId(spoke1));
    newPrice = bound(newPrice, 1, currPrice - 1);
    collAmount = bound(collAmount, 1, MAX_SUPPLY_AMOUNT / 2); // to stay within uint256 bounds for _calcMaxDebtAmount
    uint256 collReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: collReserveId,
      debtReserveId: debtReserveId,
      collAmount: collAmount
    });

    vm.assume(maxDebtAmount < MAX_SUPPLY_AMOUNT && maxDebtAmount > 1);

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collReserveId,
      caller: alice,
      amount: collAmount,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: bob,
      amount: maxDebtAmount,
      onBehalfOf: bob
    });

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: alice,
      amount: maxDebtAmount,
      onBehalfOf: alice
    });

    // alice is above HF threshold right after borrowing
    assertGe(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop so that alice is undercollateralized
    _mockReservePrice(spoke1, collReserveId, newPrice);
    vm.assume(_getUserHealthFactor(spoke1, alice) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any amount will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: collReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev cannot withdraw an amount if HF < threshold due to interest
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_interest_increase() public {
    uint256 collAmount = 50e18;
    uint256 collReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: collReserveId,
      debtReserveId: debtReserveId,
      collAmount: collAmount
    });

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collReserveId,
      caller: alice,
      amount: collAmount,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: bob,
      amount: maxDebtAmount,
      onBehalfOf: bob
    });

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: alice,
      amount: maxDebtAmount,
      onBehalfOf: alice
    });

    // alice is above HF threshold right after borrowing
    assertGe(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // accrue interest so that alice is undercollateralized
    skip(365 days);
    assertLt(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any amount will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: collReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < threshold due to interest
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_interest_increase(
    uint256 collAmount,
    uint256 skipTime
  ) public {
    collAmount = bound(collAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    uint256 collReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: collReserveId,
      debtReserveId: debtReserveId,
      collAmount: collAmount
    });

    vm.assume(maxDebtAmount < MAX_SUPPLY_AMOUNT && maxDebtAmount > 1);

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collReserveId,
      caller: alice,
      amount: collAmount,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: bob,
      amount: maxDebtAmount,
      onBehalfOf: bob
    });

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: alice,
      amount: maxDebtAmount,
      onBehalfOf: alice
    });

    // alice is above HF threshold right after borrowing
    assertGe(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // accrue interest so that alice is undercollateralized
    skip(skipTime);
    vm.assume(_getUserHealthFactor(spoke1, alice) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any amount will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: collReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev cannot withdraw an amount to bring HF < 1, if multiple debts for same coll
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_debts() public {
    uint256 daiDebtAmount = 1000e18;
    uint256 usdxDebtAmount = 2000e6;

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmountDai = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    });

    uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmount
    });

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: alice,
      amount: wethCollAmountDai + wethCollAmountUsdx,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: daiDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiDebtAmount,
      onBehalfOf: alice
    });

    // Bob supplies usdx
    Utils.supply({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: bob,
      amount: usdxDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows usdx
    Utils.borrow({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: alice,
      amount: usdxDebtAmount,
      onBehalfOf: alice
    });

    assertApproxEqAbs(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD, 1);

    // withdrawing any non trivial amount of dai will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 3, onBehalfOf: alice}); // todo: resolve precision. Should be 1
  }

  /// @dev fuzz - cannot withdraw an amount to bring HF < 1, if multiple debts for same coll
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts(
    uint256 daiDebtAmount,
    uint256 usdxDebtAmount
  ) public {
    daiDebtAmount = bound(daiDebtAmount, 1, MAX_SUPPLY_AMOUNT);
    usdxDebtAmount = bound(usdxDebtAmount, 1, MAX_SUPPLY_AMOUNT);

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmountDai = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    });

    uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmount
    });

    vm.assume(
      wethCollAmountDai + wethCollAmountUsdx < MAX_SUPPLY_AMOUNT &&
        wethCollAmountDai + wethCollAmountUsdx > 0
    );

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: alice,
      amount: wethCollAmountDai + wethCollAmountUsdx,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: daiDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiDebtAmount,
      onBehalfOf: alice
    });

    // Bob supplies usdx
    Utils.supply({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: bob,
      amount: usdxDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows usdx
    Utils.borrow({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: alice,
      amount: usdxDebtAmount,
      onBehalfOf: alice
    });

    assertGe(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any non trivial amount of weth will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({
      reserveId: wethReserveId,
      amount: (wethCollAmountDai + wethCollAmountUsdx) / 2,
      onBehalfOf: alice
    }); // todo: resolve precision. Should be 1
  }

  /// @dev cannot withdraw an amount if HF < 1 due to price drop, if multiple debts for same coll
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_debts_price_drop() public {
    uint256 daiDebtAmount = 1000e18;
    uint256 usdxDebtAmount = 2000e6;

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmountDai = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    });

    uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmount
    });

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: alice,
      amount: wethCollAmountDai + wethCollAmountUsdx,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: daiDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiDebtAmount,
      onBehalfOf: alice
    });

    // Bob supplies usdx
    Utils.supply({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: bob,
      amount: usdxDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows usdx
    Utils.borrow({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: alice,
      amount: usdxDebtAmount,
      onBehalfOf: alice
    });

    assertApproxEqAbs(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD, 1);

    _mockReservePriceByPercent(spoke1, wethReserveId, 50_00);

    assertLt(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any non trivial amount of dai will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < 1 due to price drop, if multiple debts for same coll
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts_price_drop(
    uint256 daiDebtAmount,
    uint256 usdxDebtAmount,
    uint256 newPrice
  ) public {
    uint256 currPrice = IPriceOracle(spoke1.ORACLE()).getReservePrice(_wethReserveId(spoke1));
    newPrice = bound(newPrice, 1, currPrice - 1);

    daiDebtAmount = bound(daiDebtAmount, 1, MAX_SUPPLY_AMOUNT);
    usdxDebtAmount = bound(usdxDebtAmount, 1, MAX_SUPPLY_AMOUNT);

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmountDai = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    });

    uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmount
    });

    vm.assume(
      wethCollAmountDai + wethCollAmountUsdx < MAX_SUPPLY_AMOUNT &&
        wethCollAmountDai + wethCollAmountUsdx > 0
    );

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: alice,
      amount: wethCollAmountDai + wethCollAmountUsdx,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: daiDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiDebtAmount,
      onBehalfOf: alice
    });

    // Bob supplies usdx
    Utils.supply({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: bob,
      amount: usdxDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows usdx
    Utils.borrow({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: alice,
      amount: usdxDebtAmount,
      onBehalfOf: alice
    });

    assertGe(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop so that alice is undercollateralized
    _mockReservePrice(spoke1, wethReserveId, newPrice);
    vm.assume(_getUserHealthFactor(spoke1, alice) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any non trivial amount of weth will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev cannot withdraw an amount if HF < 1 due to interest, if multiple debts for same coll
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest()
    public
  {
    uint256 daiDebtAmount = 1000e18;
    uint256 usdxDebtAmount = 2000e6;

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmountDai = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    });

    uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmount
    });

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: alice,
      amount: wethCollAmountDai + wethCollAmountUsdx,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: daiDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiDebtAmount,
      onBehalfOf: alice
    });

    // Bob supplies usdx
    Utils.supply({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: bob,
      amount: usdxDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows usdx
    Utils.borrow({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: alice,
      amount: usdxDebtAmount,
      onBehalfOf: alice
    });

    assertApproxEqAbs(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD, 1);

    // skip time to accrue interest
    skip(365 days);

    assertLt(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot withdraw any amount of weth (HF already < threshold)
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < 1 due to interest, if multiple debts for same coll
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest(
    uint256 daiDebtAmount,
    uint256 usdxDebtAmount,
    uint256 skipTime
  ) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    daiDebtAmount = bound(daiDebtAmount, 1, MAX_SUPPLY_AMOUNT);
    usdxDebtAmount = bound(usdxDebtAmount, 1, MAX_SUPPLY_AMOUNT);

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmountDai = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    });

    uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmount
    });

    vm.assume(
      wethCollAmountDai + wethCollAmountUsdx < MAX_SUPPLY_AMOUNT &&
        wethCollAmountDai + wethCollAmountUsdx > 0
    );

    // Alice supplies weth as collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: alice,
      amount: wethCollAmountDai + wethCollAmountUsdx,
      onBehalfOf: alice
    });

    // Bob supplies dai
    Utils.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: daiDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: daiDebtAmount,
      onBehalfOf: alice
    });

    // Bob supplies usdx
    Utils.supply({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: bob,
      amount: usdxDebtAmount,
      onBehalfOf: bob
    });
    // Alice borrows usdx
    Utils.borrow({
      spoke: spoke1,
      reserveId: usdxReserveId,
      caller: alice,
      amount: usdxDebtAmount,
      onBehalfOf: alice
    });

    assertGe(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // debt accrual so that alice is undercollateralized
    skip(skipTime);
    vm.assume(_getUserHealthFactor(spoke1, alice) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing any amount of weth will result in HF < threshold
    vm.prank(alice);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: alice});
  }

  /// @dev cannot withdraw an amount to bring HF < 1, if multiple colls for same debt
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_colls() public {
    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 usdxDebtAmountWeth = 3000e6;
    uint256 usdxDebtAmountDai = 5000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiCollAmount, bob);

    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing weth will result in HF < threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: wethCollAmount, onBehalfOf: bob}); // todo: resolve precision, should be 1

    // withdrawing dai will result in HF < threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: daiReserveId, amount: daiCollAmount, onBehalfOf: bob}); // todo: resolve precision, should be 1
  }

  /// @dev cannot withdraw an amount to bring HF < 1, if multiple colls for same debt
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT);
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT);

    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiCollAmount, bob);

    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing some nontrivial amount of weth will result in HF < threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: wethCollAmount, onBehalfOf: bob}); // todo: resolve precision, should be 1

    // withdrawing some nontrivial amount of dai will result in HF < threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: daiReserveId, amount: daiCollAmount, onBehalfOf: bob}); // todo: resolve precision, should be 1
  }

  /// @dev cannot withdraw an amount if HF < 1 due to interest, if multiple colls for same debt
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest()
    public
  {
    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 usdxDebtAmountWeth = 3000e6;
    uint256 usdxDebtAmountDai = 5000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiCollAmount, bob);

    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // skip time to accrue debt
    skip(365 days);
    // invalid HF
    assertLt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // withdrawing weth will result in HF < threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: bob});

    // withdrawing dai will result in HF < threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: daiReserveId, amount: 1, onBehalfOf: bob});
  }

  /// @dev cannot withdraw an amount if HF < 1 due to interest, if multiple colls for same debt
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT);
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT);

    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiCollAmount, bob);

    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // skip time to accrue debt
    skip(365 days);
    // invalid HF
    vm.assume(_getUserHealthFactor(spoke1, bob) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot withdraw any amount of weth (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: bob});

    // cannot withdraw any amount of dai (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: daiReserveId, amount: 1, onBehalfOf: bob});
  }

  /// @dev cannot withdraw an amount if HF < 1 due to price drop, if multiple colls for same debt
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_weth()
    public
  {
    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 usdxDebtAmountWeth = 3000e6;
    uint256 usdxDebtAmountDai = 5000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiCollAmount, bob);

    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePriceByPercent(spoke1, wethReserveId, 50_00);
    // invalid HF
    assertLt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot withdraw any amount of weth (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: bob});

    // cannot withdraw any amount of dai (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: daiReserveId, amount: 1, onBehalfOf: bob});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < 1 due to price drop, if multiple colls for same debt
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_weth(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai,
    uint256 newPrice
  ) public {
    uint256 currPrice = IPriceOracle(spoke1.ORACLE()).getReservePrice(_wethReserveId(spoke1));
    newPrice = bound(newPrice, 1, currPrice - 1);
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT);
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT);

    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiCollAmount, bob);

    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePrice(spoke1, wethReserveId, newPrice);
    // invalid HF
    vm.assume(_getUserHealthFactor(spoke1, bob) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot withdraw any amount of weth (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: bob});

    // cannot withdraw any amount of dai (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: daiReserveId, amount: 1, onBehalfOf: bob});
  }

  /// @dev cannot withdraw an amount if HF < 1 due to price drop, if multiple colls for same debt
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_dai()
    public
  {
    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 usdxDebtAmountWeth = 3000e6;
    uint256 usdxDebtAmountDai = 5000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiCollAmount, bob);

    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePriceByPercent(spoke1, daiReserveId, 50_00);
    // invalid HF
    assertLt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot withdraw any amount of weth (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: bob});

    // cannot withdraw any amount of dai (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: daiReserveId, amount: 1, onBehalfOf: bob});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < 1 due to price drop, if multiple colls for same debt
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_dai(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai,
    uint256 newPrice
  ) public {
    uint256 currPrice = IPriceOracle(spoke1.ORACLE()).getReservePrice(_daiReserveId(spoke1));
    newPrice = bound(newPrice, 1, currPrice - 1);
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT);
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT);

    // weth/dai collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    // usdx debt
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountWeth
    });
    uint256 daiCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: daiReserveId,
      debtReserveId: usdxReserveId,
      debtAmount: usdxDebtAmountDai
    });

    vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Bob supply dai collateral
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiCollAmount, bob);

    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePrice(spoke1, daiReserveId, newPrice);
    // invalid HF
    vm.assume(_getUserHealthFactor(spoke1, bob) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot withdraw any amount of weth (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: wethReserveId, amount: 1, onBehalfOf: bob});

    // cannot withdraw any amount of dai (HF already < threshold)
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.withdraw({reserveId: daiReserveId, amount: 1, onBehalfOf: bob});
  }

  // TODO: tests with other combos of collateral/debt, particularly with different units
  // - 2 colls, 1e18/1e6, with 1 debt, 1e0
  // - 2 colls, 1e18/1e0, with 1 debt, 1e6
  // - 2 colls, 1e6/1e0, with 1 debt, 1e18
  // - 1 coll, 1e0, with 2 debts, 1e18/1e6
  // - 1 coll, 1e6, with 2 debts, 1e18/1e0
  // - 1 coll, 1e18, with 2 debts, 1e6/1e0
}
