// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowHealthFactorTest is SpokeBase {
  /// basic case, cannot borrow an amount that leads to HF < 1
  function test_borrow_revertsWith_HealthFactorBelowThreshold() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint256 wethSupplyAmount = 1e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    // valid HF after borrow
    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow a non trivial amount that brings HF below threshold
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1e4, bob); // TODO: update with exact amount, resolve precision
  }

  /// cannot borrow any amount after interest has brought HF already < 1
  function test_borrow_revertsWith_HealthFactorBelowThreshold_with_interest() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint256 wethSupplyAmount = 10e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // accrue debt to decrease HF
    skip(365 days);

    // now HF is < 1
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  /// fuzz - cannot borrow any amount after interest has brought HF already < 1
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_with_interest(
    uint256 wethSupplyAmount,
    uint256 skipTime
  ) public {
    wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    vm.assume(maxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && maxDebtAmount > 0);

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    assertGe(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    // accrue debt to decrease HF
    skip(skipTime);

    // ensure enough time passes to reduce HF < 1
    vm.assume(spoke1.getHealthFactor(bob) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  /// cannot borrow an amount that brings HF < 1 with multiple debts for same collateral
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_debts() public {
    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 daiDebtAmount = 2000e18;
    uint256 usdxDebtAmount = 3000e6;

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

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmountDai + wethCollAmountUsdx, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai/usdx reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1e12, bob); // todo: update with exact amount, resolve precision

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob); // todo: update with exact amount, resolve precision
  }

  /// fuzz - cannot borrow an amount that brings HF < 1 with multiple debts for same collateral
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts(
    uint256 wethCollAmountDai,
    uint256 wethCollAmountUsdx
  ) public {
    // todo: resolve precision bounds for wethCollAmountDai, wethCollAmountUsdx
    // at high ratios between them, borrowing additional amounts won't bring HF < 1
    wethCollAmountDai = bound(wethCollAmountDai, 1e10, MAX_SUPPLY_AMOUNT / 2);
    wethCollAmountUsdx = bound(wethCollAmountUsdx, 1e10, MAX_SUPPLY_AMOUNT / 2);

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 daiDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethCollAmountDai
    });
    uint256 usdxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      collAmount: wethCollAmountUsdx
    });

    vm.assume(usdxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && usdxDebtAmount > 0);
    vm.assume(daiDebtAmount < MAX_SUPPLY_AMOUNT / 2 && daiDebtAmount > 1e12); // dai is 1e18, keep within similar bounds to usdx (at 1e6)

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmountDai + wethCollAmountUsdx, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai/usdx reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD); // can be GE due to low debt/coll amounts

    // todo: should these failed amounts be 1? Could be off due to extremely edge low debt/coll amounts
    uint256 daiFailedBorrowAmount = daiDebtAmount; // some amount guaranteed to cause HF < 1
    uint256 usdxFailedBorrowAmount = usdxDebtAmount; // some amount guaranteed to cause HF < 1

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, daiFailedBorrowAmount, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, usdxFailedBorrowAmount, bob); // todo: update with exact amount, resolve precision
  }

  /// cannot borrow any amount if HF < 1 due to interest growth (multiple debts for same collateral)
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest()
    public
  {
    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 daiDebtAmount = 1_000e18;
    uint256 usdxDebtAmount = 2_000e6;

    uint256 wethCollAmount = _calcMinimumCollAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      debtAmount: daiDebtAmount
    }) +
      _calcMinimumCollAmount({
        spoke: spoke1,
        collReserveId: wethReserveId,
        debtReserveId: usdxReserveId,
        debtAmount: usdxDebtAmount
      });

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai/usdx reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertApproxEqAbs(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD, 1);

    skip(365 days);

    // after accrual, invalid HF
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow any amount if HF < 1 due to interest growth (multiple debts for same collateral)
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest(
    uint256 wethCollForDai,
    uint256 wethCollForUsdx,
    uint256 skipTime
  ) public {
    wethCollForDai = bound(wethCollForDai, 1, MAX_SUPPLY_AMOUNT / 2);
    wethCollForUsdx = bound(wethCollForUsdx, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // weth collateral
    uint256 wethReserveId = _wethReserveId(spoke1);
    // dai/usdx debt
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    uint256 daiDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethCollForDai
    });
    uint256 usdxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      collAmount: wethCollForUsdx
    });

    vm.assume(daiDebtAmount < MAX_SUPPLY_AMOUNT / 2 && daiDebtAmount > 0);
    vm.assume(usdxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && usdxDebtAmount > 0);

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethCollForDai + wethCollForUsdx, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, daiDebtAmount * 2, alice); // supply enough buffer for multiple borrows
    // Alice supply usdx
    Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai/usdx reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, daiDebtAmount, bob);
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, usdxDebtAmount, bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD); // can be GE for edge cases of coll/debt amount, ie 1

    skip(skipTime);
    vm.assume(spoke1.getHealthFactor(bob) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more dai
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// if HF drops below threshold due to price drop, user cannot borrow more
  function test_borrow_revertsWith_HealthFactorBelowThreshold_collateral_price_drop_weth() public {
    uint256 daiReserveId = _daiReserveId(spoke1); // debt
    uint256 wethReserveId = _wethReserveId(spoke1); // collateral

    uint256 wethSupplyAmount = 10e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePriceByPercent(spoke1, wethReserveId, 50_00);
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  /// fuzz - if HF drops below threshold due to price drop, user cannot borrow more
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_collateral_price_drop(
    uint256 wethSupplyAmount,
    uint256 newPrice
  ) public {
    uint256 currPrice = spoke1.oracle().getReservePrice(_wethReserveId(spoke1));
    newPrice = bound(newPrice, 1, currPrice - 1);
    // weth collateral
    wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);

    uint256 daiReserveId = _daiReserveId(spoke1); // debt
    uint256 wethReserveId = _wethReserveId(spoke1); // collateral

    uint256 wethSupplyAmount = 10e18;
    uint256 maxDebtAmount = _calcMaxDebtAmount({
      spoke: spoke1,
      collReserveId: wethReserveId,
      debtReserveId: daiReserveId,
      collAmount: wethSupplyAmount
    });

    vm.assume(maxDebtAmount < MAX_SUPPLY_AMOUNT / 2 && maxDebtAmount > 0);

    // Bob supply weth
    Utils.supplyCollateral(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, daiReserveId, alice, maxDebtAmount * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed debt amt of dai reserve liquidity
    vm.prank(bob);
    spoke1.borrow(daiReserveId, maxDebtAmount, bob);

    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop so that bob is undercollateralized
    _mockReservePrice(spoke1, wethReserveId, newPrice);
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(daiReserveId, 1, bob);
  }

  /// cannot borrow an amount that brings HF < 1 with multiple colls for same debt
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls() public {
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
    Utils.supply(spoke1, usdxReserveId, alice, (usdxDebtAmountWeth + usdxDebtAmountDai) * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow an amount that brings HF < 1 with multiple colls for same debt
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that liquidity is sufficient for next draw attempt
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that liquidity is sufficient for next draw attempt

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
    Utils.supply(spoke1, usdxReserveId, alice, (usdxDebtAmountWeth + usdxDebtAmountDai) + 1, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD); // can be GE due to edge cases of coll/debt ratios

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// cannot borrow any amount with multiple colls for same debt, once HF < 1 due to interest
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest()
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
    Utils.supply(spoke1, usdxReserveId, alice, (usdxDebtAmountWeth + usdxDebtAmountDai) * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // skip time to accrue debt and reduce HF < 1
    skip(365 days);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow any amount with multiple colls for same debt, once HF < 1 due to interest
  function test_borrow_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai,
    uint256 skipTime
  ) public {
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that additional draw has liquidity
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // so that additional draw has liquidity
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

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
    Utils.supply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD); // can be GE due to edge cases of coll/debt ratios

    // skip time to accrue debt and reduce HF < 1
    skip(skipTime);

    // invalid HF
    vm.assume(spoke1.getHealthFactor(bob) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    vm.assume(hub1.getLiquidity(usdxAssetId) > 0);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_collateral_price_drop_weth()
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
    Utils.supply(spoke1, usdxReserveId, alice, (usdxDebtAmountWeth + usdxDebtAmountDai) * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePriceByPercent(spoke1, wethReserveId, 50_00);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_fuzz_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_collateral_price_drop_weth(
    uint256 newPrice,
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    uint256 currPrice = spoke1.oracle().getReservePrice(_wethReserveId(spoke1));
    newPrice = bound(newPrice, 1, currPrice - 1);
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 4);
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 4);

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
    Utils.supply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD); // can be GE due to edge cases

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePriceByPercent(spoke1, wethReserveId, 50_00);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_collateral_price_drop_dai()
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
    Utils.supply(spoke1, usdxReserveId, alice, (usdxDebtAmountWeth + usdxDebtAmountDai) * 2, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertEq(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePriceByPercent(spoke1, daiReserveId, 50_00);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  /// fuzz - cannot borrow more with multiple colls for same debt, if HF drops below threshold due to price drop
  function test_fuzz_borrow_revertsWith_HealthFactorBelowThreshold_multiple_colls_collateral_price_drop_dai(
    uint256 newPrice,
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    uint256 currPrice = spoke1.oracle().getReservePrice(_wethReserveId(spoke1));
    newPrice = bound(newPrice, 1, currPrice - 1);
    usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT / 4);
    usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT / 4);

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
    Utils.supply(spoke1, usdxReserveId, alice, MAX_SUPPLY_AMOUNT, alice); // supply enough buffer for multiple borrows

    // Bob draw max allowed usdx debt
    vm.prank(bob);
    spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    // valid HF
    assertGe(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD); // can be GE due to edge cases

    // collateral price drop by half so that bob is undercollateralized
    _mockReservePriceByPercent(spoke1, daiReserveId, 50_00);

    // invalid HF
    assertLt(spoke1.getHealthFactor(bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // cannot borrow more usdx
    vm.prank(bob);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    spoke1.borrow(usdxReserveId, 1, bob);
  }

  // TODO: tests with other combos of collateral/debt, particularly with different units
  // - 2 colls, 1e18/1e6, with 1 debt, 1e0
  // - 2 colls, 1e18/1e0, with 1 debt, 1e6
  // - 2 colls, 1e6/1e0, with 1 debt, 1e18
  // - 1 coll, 1e0, with 2 debts, 1e18/1e6
  // - 1 coll, 1e6, with 2 debts, 1e18/1e0
  // - 1 coll, 1e18, with 2 debts, 1e6/1e0
}
