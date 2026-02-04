// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueInterestTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for *;
  using SafeCast for uint256;

  struct TestAmounts {
    uint256 daiSupplyAmount;
    uint256 wethSupplyAmount;
    uint256 usdxSupplyAmount;
    uint256 wbtcSupplyAmount;
    uint256 daiBorrowAmount;
    uint256 wethBorrowAmount;
    uint256 usdxBorrowAmount;
    uint256 wbtcBorrowAmount;
  }

  struct Rates {
    uint96 daiBaseBorrowRate;
    uint96 wethBaseBorrowRate;
    uint96 usdxBaseBorrowRate;
    uint96 wbtcBaseBorrowRate;
  }

  function setUp() public override {
    super.setUp();
    updateLiquidityFee(hub1, daiAssetId, 0);
    updateLiquidityFee(hub1, wethAssetId, 0);
    updateLiquidityFee(hub1, usdxAssetId, 0);
    updateLiquidityFee(hub1, wbtcAssetId, 0);
  }

  function test_accrueInterest_NoActionTaken() public view {
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      0,
      0,
      'no debt without action'
    );
    _assertSingleUserProtocolSupply(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      0,
      'no supply without action'
    );
  }

  /// Supply an asset only, and check no interest accrued.
  function test_accrueInterest_NoInterest_OnlySupply(uint40 skipTime) public {
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();
    uint256 amount = 1000e18;
    uint256 daiReserveId = _daiReserveId(spoke1);

    // Bob supplies through spoke 1
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);

    // Skip time
    skip(skipTime);

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      0,
      0,
      'after supply, no interest accrued'
    );
    _assertSingleUserProtocolSupply(
      spoke1,
      daiReserveId,
      bob,
      amount,
      'after supply, no interest accrued'
    );
  }

  /// no interest accrued when no debt after repay
  function test_accrueInterest_NoInterest_NoDebt(uint40 elapsed) public {
    elapsed = bound(elapsed, 1, MAX_SKIP_TIME).toUint40();

    uint256 supplyAmount = 1000e18;
    uint40 startTime = vm.getBlockTimestamp().toUint40();
    uint256 borrowAmount = 100e18;
    uint256 daiReserveId = _daiReserveId(spoke1);

    Utils.supplyCollateral(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint96 drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();
    uint256 userRp = _getUserRiskPremium(spoke1, bob);

    // Time passes
    skip(elapsed);

    // Check debts after interest accrual
    uint256 drawnDebt = _calculateExpectedDrawnDebt(borrowAmount, drawnRate, startTime);
    uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(borrowAmount, drawnDebt, userRp);
    uint256 interest = (drawnDebt + expectedPremiumDebt) -
      borrowAmount -
      _calculateBurntInterest(hub1, daiAssetId);

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'after accrual'
    );
    _assertSingleUserProtocolSupply(
      spoke1,
      daiReserveId,
      bob,
      supplyAmount + interest,
      'after accrual'
    );

    startTime = vm.getBlockTimestamp().toUint40();
    drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();

    // Full repayment, so back to zero debt
    Utils.repay(spoke1, daiReserveId, bob, UINT256_MAX, bob);

    _assertSingleUserProtocolDebt(spoke1, daiReserveId, bob, 0, 0, 'after repay, no debt');
    _assertSingleUserProtocolSupply(
      spoke1,
      daiReserveId,
      bob,
      supplyAmount + interest,
      'after repay, no additional supply'
    );

    // Time passes
    skip(elapsed);

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      0,
      0,
      'after repay and time skip, no debt'
    );
    _assertSingleUserProtocolSupply(
      spoke1,
      daiReserveId,
      bob,
      supplyAmount + interest,
      'after repay and time skip, no additional supply'
    );
  }

  function test_accrueInterest_fuzz_BorrowAmountAndSkipTime(
    uint256 borrowAmount,
    uint40 skipTime
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();
    uint256 supplyAmount = borrowAmount * 2;
    uint40 startTime = vm.getBlockTimestamp().toUint40();
    uint256 daiReserveId = _daiReserveId(spoke1);

    // Bob supplies and borrows through spoke 1
    Utils.supplyCollateral(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint96 drawnRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();
    uint256 userRp = _getUserRiskPremium(spoke1, bob);

    // Time passes
    skip(skipTime);

    uint256 drawnDebt = _calculateExpectedDrawnDebt(borrowAmount, drawnRate, startTime);
    uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(borrowAmount, drawnDebt, userRp);
    uint256 interest = (drawnDebt + expectedPremiumDebt) - borrowAmount;

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'after accrual'
    );
    _assertSingleUserProtocolSupply(
      spoke1,
      daiReserveId,
      bob,
      supplyAmount + interest - _calculateBurntInterest(hub1, daiAssetId),
      'after accrual'
    );
  }

  function test_accrueInterest_TenPercentRp(uint256 borrowAmount, uint40 skipTime) public {
    borrowAmount = bound(borrowAmount, 1e6, MAX_SUPPLY_AMOUNT / 2);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();
    uint256 supplyAmount = borrowAmount * 2;
    uint40 startTime = vm.getBlockTimestamp().toUint40();
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    // Set collateral risk of usdx on spoke1 to 10%
    _updateCollateralRisk(spoke1, usdxReserveId, 10_00);
    assertEq(10_00, _getCollateralRisk(spoke1, usdxReserveId), 'usdx collateral risk');

    // Bob supply usdx
    Utils.supplyCollateral(spoke1, usdxReserveId, bob, supplyAmount, bob);

    // Bob borrows usdx
    Utils.borrow(spoke1, usdxReserveId, bob, borrowAmount, bob);

    // User risk premium should be 10%
    uint256 riskPremium = _getUserRiskPremium(spoke1, bob);
    assertEq(riskPremium, 10_00, 'user risk premium');
    uint96 drawnRate = hub1.getAssetDrawnRate(usdxAssetId).toUint96();

    skip(skipTime);

    uint256 expectedDrawnDebt = _calculateExpectedDrawnDebt(borrowAmount, drawnRate, startTime);
    uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(
      borrowAmount,
      expectedDrawnDebt,
      riskPremium
    );
    uint256 interest = (expectedDrawnDebt + expectedPremiumDebt) -
      borrowAmount -
      _calculateBurntInterest(hub1, usdxAssetId);

    _assertSingleUserProtocolDebt(
      spoke1,
      usdxReserveId,
      bob,
      expectedDrawnDebt,
      expectedPremiumDebt,
      'after accrual'
    );
    _assertSingleUserProtocolSupply(
      spoke1,
      usdxReserveId,
      bob,
      supplyAmount + interest,
      'after accrual'
    );
  }

  // Fuzz a mix of borrowed and supplied assets for bob, check his RP, ensure correct interest accrual
  function test_accrueInterest_fuzz_RPBorrowAndSkipTime(
    TestAmounts memory amounts,
    uint40 skipTime
  ) public {
    amounts = _bound(amounts);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();

    // Ensure bob does not draw more than half his normalized supply value
    amounts = _ensureSufficientCollateral(spoke1, amounts);

    uint40 startTime = vm.getBlockTimestamp().toUint40();

    // Bob supply dai on spoke 1
    if (amounts.daiSupplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, amounts.daiSupplyAmount, bob);
    }

    // Bob supply weth on spoke 1
    if (amounts.wethSupplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, amounts.wethSupplyAmount, bob);
    }

    // Bob supply usdx on spoke 1
    if (amounts.usdxSupplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), bob, amounts.usdxSupplyAmount, bob);
    }

    // Bob supply wbtc on spoke 1
    if (amounts.wbtcSupplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), bob, amounts.wbtcSupplyAmount, bob);
    }

    // Deploy remainder of liquidity
    if (amounts.daiSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke1,
        _daiReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.daiSupplyAmount
      );
    }
    if (amounts.wethSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke1,
        _wethReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.wethSupplyAmount
      );
    }
    if (amounts.usdxSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke1,
        _usdxReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.usdxSupplyAmount
      );
    }
    if (amounts.wbtcSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke1,
        _wbtcReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.wbtcSupplyAmount
      );
    }

    // Bob borrows dai from spoke 1
    if (amounts.daiBorrowAmount > 0) {
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amounts.daiBorrowAmount, bob);
    }

    // Bob borrows weth from spoke 1
    if (amounts.wethBorrowAmount > 0) {
      Utils.borrow(spoke1, _wethReserveId(spoke1), bob, amounts.wethBorrowAmount, bob);
    }

    // Bob borrows usdx from spoke 1
    if (amounts.usdxBorrowAmount > 0) {
      Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, amounts.usdxBorrowAmount, bob);
    }

    // Bob borrows wbtc from spoke 1
    if (amounts.wbtcBorrowAmount > 0) {
      Utils.borrow(spoke1, _wbtcReserveId(spoke1), bob, amounts.wbtcBorrowAmount, bob);
    }

    // Check Bob's risk premium
    uint256 bobRp = _getUserRiskPremium(spoke1, bob);
    assertEq(bobRp, _calculateExpectedUserRP(spoke1, bob), 'user risk premium Before');

    // Store base borrow rates
    Rates memory rates;
    rates.daiBaseBorrowRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();
    rates.wethBaseBorrowRate = hub1.getAssetDrawnRate(wethAssetId).toUint96();
    rates.usdxBaseBorrowRate = hub1.getAssetDrawnRate(usdxAssetId).toUint96();
    rates.wbtcBaseBorrowRate = hub1.getAssetDrawnRate(wbtcAssetId).toUint96();

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    uint256 drawnDebt = _calculateExpectedDrawnDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      drawnDebt,
      0,
      'dai before accrual'
    );
    _assertUserSupply(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      amounts.daiSupplyAmount,
      'dai before accrual'
    );
    _assertReserveSupply(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'dai before accrual');
    _assertSpokeSupply(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'dai before accrual');
    _assertAssetSupply(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'dai before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      drawnDebt,
      0,
      'weth before accrual'
    );
    _assertUserSupply(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      amounts.wethSupplyAmount,
      'weth before accrual'
    );
    _assertReserveSupply(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'weth before accrual');
    _assertSpokeSupply(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'weth before accrual');
    _assertAssetSupply(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'weth before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      drawnDebt,
      0,
      'usdx before accrual'
    );
    _assertUserSupply(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      amounts.usdxSupplyAmount,
      'usdx before accrual'
    );
    _assertReserveSupply(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'usdx before accrual');
    _assertSpokeSupply(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'usdx before accrual');
    _assertAssetSupply(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'usdx before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      drawnDebt,
      0,
      'wbtc before accrual'
    );
    _assertUserSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      amounts.wbtcSupplyAmount,
      'wbtc before accrual'
    );
    _assertReserveSupply(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');
    _assertSpokeSupply(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');
    _assertAssetSupply(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(
      amounts.daiBorrowAmount,
      drawnDebt,
      bobRp
    );
    uint256 interest = (drawnDebt + expectedPremiumDebt) -
      amounts.daiBorrowAmount -
      _calculateBurntInterest(hub1, daiAssetId);
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'dai after accrual'
    );
    _assertUserSupply(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      amounts.daiSupplyAmount + (interest * amounts.daiSupplyAmount) / MAX_SUPPLY_AMOUNT, // Bob's pro-rata share of interest
      'dai after accrual'
    );
    _assertReserveSupply(
      spoke1,
      _daiReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );
    _assertSpokeSupply(
      spoke1,
      _daiReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );
    _assertAssetSupply(
      spoke1,
      _daiReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    expectedPremiumDebt = _calculateExpectedPremiumDebt(amounts.wethBorrowAmount, drawnDebt, bobRp);
    interest =
      (drawnDebt + expectedPremiumDebt) -
      amounts.wethBorrowAmount -
      _calculateBurntInterest(hub1, wethAssetId);
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'weth after accrual'
    );
    _assertUserSupply(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      amounts.wethSupplyAmount + (interest * amounts.wethSupplyAmount) / MAX_SUPPLY_AMOUNT, // Bob's pro-rata share of interest
      'weth after accrual'
    );
    _assertReserveSupply(
      spoke1,
      _wethReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );
    _assertSpokeSupply(
      spoke1,
      _wethReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );
    _assertAssetSupply(
      spoke1,
      _wethReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    expectedPremiumDebt = _calculateExpectedPremiumDebt(amounts.usdxBorrowAmount, drawnDebt, bobRp);
    interest =
      (drawnDebt + expectedPremiumDebt) -
      amounts.usdxBorrowAmount -
      _calculateBurntInterest(hub1, usdxAssetId);
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'usdx after accrual'
    );
    _assertUserSupply(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      amounts.usdxSupplyAmount + (interest * amounts.usdxSupplyAmount) / MAX_SUPPLY_AMOUNT, // Bob's pro-rata share of interest
      'usdx after accrual'
    );
    _assertReserveSupply(
      spoke1,
      _usdxReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );
    _assertSpokeSupply(
      spoke1,
      _usdxReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );
    _assertAssetSupply(
      spoke1,
      _usdxReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    expectedPremiumDebt = _calculateExpectedPremiumDebt(amounts.wbtcBorrowAmount, drawnDebt, bobRp);
    interest =
      (drawnDebt + expectedPremiumDebt) -
      amounts.wbtcBorrowAmount -
      _calculateBurntInterest(hub1, wbtcAssetId);
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'wbtc after accrual'
    );
    _assertUserSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      amounts.wbtcSupplyAmount + (interest * amounts.wbtcSupplyAmount) / MAX_SUPPLY_AMOUNT, // Bob's pro-rata share of interest
      'wbtc after accrual'
    );
    _assertReserveSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );
    _assertSpokeSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );
    _assertAssetSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );
  }

  // Fuzz a mix of borrowed and supplied assets for bob and rates, check his RP, ensure correct interest accrual
  function test_accrueInterest_fuzz_RatesRPBorrowAndSkipTime(
    TestAmounts memory amounts,
    Rates memory rates,
    uint40 skipTime
  ) public {
    amounts = _bound(amounts);
    rates = _bound(rates);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();

    // Ensure bob does not draw more than half his normalized supply value
    amounts = _ensureSufficientCollateral(spoke1, amounts);

    uint40 startTime = vm.getBlockTimestamp().toUint40();

    // Bob supply dai on spoke 1
    if (amounts.daiSupplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, amounts.daiSupplyAmount, bob);
    }

    // Bob supply weth on spoke 1
    if (amounts.wethSupplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, amounts.wethSupplyAmount, bob);
    }

    // Bob supply usdx on spoke 1
    if (amounts.usdxSupplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), bob, amounts.usdxSupplyAmount, bob);
    }

    // Bob supply wbtc on spoke 1
    if (amounts.wbtcSupplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), bob, amounts.wbtcSupplyAmount, bob);
    }

    // Deploy remainder of liquidity
    if (amounts.daiSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke1,
        _daiReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.daiSupplyAmount
      );
    }
    if (amounts.wethSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke1,
        _wethReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.wethSupplyAmount
      );
    }
    if (amounts.usdxSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke1,
        _usdxReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.usdxSupplyAmount
      );
    }
    if (amounts.wbtcSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke1,
        _wbtcReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.wbtcSupplyAmount
      );
    }

    // Bob borrows dai from spoke 1
    if (amounts.daiBorrowAmount > 0) {
      IHub.Asset memory asset = hub1.getAsset(daiAssetId);
      uint256 daiBorrowShares = hub1.previewDrawByAssets(daiAssetId, amounts.daiBorrowAmount);
      _mockInterestRateRay({
        interestRateRay: rates.daiBaseBorrowRate,
        assetId: daiAssetId,
        liquidity: asset.liquidity - amounts.daiBorrowAmount,
        drawn: hub1.previewRestoreByShares(daiAssetId, asset.drawnShares + daiBorrowShares)
      });
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amounts.daiBorrowAmount, bob);
    }

    // Bob borrows weth from spoke 1
    if (amounts.wethBorrowAmount > 0) {
      IHub.Asset memory asset = hub1.getAsset(wethAssetId);
      uint256 wethBorrowShares = hub1.previewDrawByAssets(wethAssetId, amounts.wethBorrowAmount);
      _mockInterestRateRay({
        interestRateRay: rates.wethBaseBorrowRate,
        assetId: wethAssetId,
        liquidity: asset.liquidity - amounts.wethBorrowAmount,
        drawn: hub1.previewRestoreByShares(wethAssetId, asset.drawnShares + wethBorrowShares)
      });
      Utils.borrow(spoke1, _wethReserveId(spoke1), bob, amounts.wethBorrowAmount, bob);
    }

    // Bob borrows usdx from spoke 1
    if (amounts.usdxBorrowAmount > 0) {
      IHub.Asset memory asset = hub1.getAsset(usdxAssetId);
      uint256 usdxBorrowShares = hub1.previewDrawByAssets(usdxAssetId, amounts.usdxBorrowAmount);
      _mockInterestRateRay({
        interestRateRay: rates.usdxBaseBorrowRate,
        assetId: usdxAssetId,
        liquidity: asset.liquidity - amounts.usdxBorrowAmount,
        drawn: hub1.previewRestoreByShares(usdxAssetId, asset.drawnShares + usdxBorrowShares)
      });
      Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, amounts.usdxBorrowAmount, bob);
    }

    // Bob borrows wbtc from spoke 1
    if (amounts.wbtcBorrowAmount > 0) {
      IHub.Asset memory asset = hub1.getAsset(wbtcAssetId);
      uint256 wbtcBorrowShares = hub1.previewDrawByAssets(wbtcAssetId, amounts.wbtcBorrowAmount);
      _mockInterestRateRay({
        interestRateRay: rates.wbtcBaseBorrowRate,
        assetId: wbtcAssetId,
        liquidity: asset.liquidity - amounts.wbtcBorrowAmount,
        drawn: hub1.previewRestoreByShares(wbtcAssetId, asset.drawnShares + wbtcBorrowShares)
      });
      Utils.borrow(spoke1, _wbtcReserveId(spoke1), bob, amounts.wbtcBorrowAmount, bob);
    }

    // Check Bob's risk premium
    uint256 bobRp = _getUserRiskPremium(spoke1, bob);
    assertEq(bobRp, _calculateExpectedUserRP(spoke1, bob), 'user risk premium Before');

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    uint256 drawnDebt = _calculateExpectedDrawnDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      drawnDebt,
      0,
      'dai before accrual'
    );
    _assertUserSupply(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      amounts.daiSupplyAmount,
      'dai before accrual'
    );
    _assertReserveSupply(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'dai before accrual');
    _assertSpokeSupply(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'dai before accrual');
    _assertAssetSupply(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'dai before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      drawnDebt,
      0,
      'weth before accrual'
    );
    _assertUserSupply(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      amounts.wethSupplyAmount,
      'weth before accrual'
    );
    _assertReserveSupply(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'weth before accrual');
    _assertSpokeSupply(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'weth before accrual');
    _assertAssetSupply(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'weth before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      drawnDebt,
      0,
      'usdx before accrual'
    );
    _assertUserSupply(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      amounts.usdxSupplyAmount,
      'usdx before accrual'
    );
    _assertReserveSupply(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'usdx before accrual');
    _assertSpokeSupply(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'usdx before accrual');
    _assertAssetSupply(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'usdx before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      drawnDebt,
      0,
      'wbtc before accrual'
    );
    _assertUserSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      amounts.wbtcSupplyAmount,
      'wbtc before accrual'
    );
    _assertReserveSupply(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');
    _assertSpokeSupply(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');
    _assertAssetSupply(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    ISpoke.UserPosition memory bobPosition = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    uint256 expectedpremiumShares = bobPosition.drawnShares.percentMulUp(bobRp);
    uint256 expectedPremiumDebt = _calculatePremiumDebt(
      hub1,
      daiAssetId,
      expectedpremiumShares,
      bobPosition.premiumOffsetRay
    );
    uint256 interest = (drawnDebt + expectedPremiumDebt) -
      amounts.daiBorrowAmount -
      _calculateBurntInterest(hub1, daiAssetId);
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'dai after accrual'
    );
    _assertUserSupply(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      amounts.daiSupplyAmount + (interest * amounts.daiSupplyAmount) / MAX_SUPPLY_AMOUNT, // Bob's pro-rata share of interest
      'dai after accrual'
    );
    _assertReserveSupply(
      spoke1,
      _daiReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );
    _assertSpokeSupply(
      spoke1,
      _daiReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );
    _assertAssetSupply(
      spoke1,
      _daiReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );

    bobPosition = spoke1.getUserPosition(_wethReserveId(spoke1), bob);
    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    expectedpremiumShares = bobPosition.drawnShares.percentMulUp(bobRp);
    expectedPremiumDebt = _calculatePremiumDebt(
      hub1,
      wethAssetId,
      expectedpremiumShares,
      bobPosition.premiumOffsetRay
    );
    interest =
      (drawnDebt + expectedPremiumDebt) -
      amounts.wethBorrowAmount -
      _calculateBurntInterest(hub1, wethAssetId);
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'weth after accrual'
    );
    _assertUserSupply(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      amounts.wethSupplyAmount + (interest * amounts.wethSupplyAmount) / MAX_SUPPLY_AMOUNT, // Bob's pro-rata share of interest
      'weth after accrual'
    );
    _assertReserveSupply(
      spoke1,
      _wethReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );
    _assertSpokeSupply(
      spoke1,
      _wethReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );
    _assertAssetSupply(
      spoke1,
      _wethReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );

    bobPosition = spoke1.getUserPosition(_usdxReserveId(spoke1), bob);
    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    expectedpremiumShares = bobPosition.drawnShares.percentMulUp(bobRp);
    expectedPremiumDebt = _calculatePremiumDebt(
      hub1,
      usdxAssetId,
      expectedpremiumShares,
      bobPosition.premiumOffsetRay
    );
    interest =
      (drawnDebt + expectedPremiumDebt) -
      amounts.usdxBorrowAmount -
      _calculateBurntInterest(hub1, usdxAssetId);
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'usdx after accrual'
    );
    _assertUserSupply(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      amounts.usdxSupplyAmount + (interest * amounts.usdxSupplyAmount) / MAX_SUPPLY_AMOUNT, // Bob's pro-rata share of interest
      'usdx after accrual'
    );
    _assertReserveSupply(
      spoke1,
      _usdxReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );
    _assertSpokeSupply(
      spoke1,
      _usdxReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );
    _assertAssetSupply(
      spoke1,
      _usdxReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );

    bobPosition = spoke1.getUserPosition(_wbtcReserveId(spoke1), bob);
    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    expectedpremiumShares = bobPosition.drawnShares.percentMulUp(bobRp);
    expectedPremiumDebt = _calculatePremiumDebt(
      hub1,
      wbtcAssetId,
      expectedpremiumShares,
      bobPosition.premiumOffsetRay
    );
    interest =
      (drawnDebt + expectedPremiumDebt) -
      amounts.wbtcBorrowAmount -
      _calculateBurntInterest(hub1, wbtcAssetId);
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'wbtc after accrual'
    );
    _assertUserSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      amounts.wbtcSupplyAmount + (interest * amounts.wbtcSupplyAmount) / MAX_SUPPLY_AMOUNT, // Bob's pro-rata share of interest
      'wbtc after accrual'
    );
    _assertReserveSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );
    _assertSpokeSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );
    _assertAssetSupply(
      spoke1,
      _wbtcReserveId(spoke1),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );
  }

  function _bound(TestAmounts memory amounts) internal pure returns (TestAmounts memory) {
    amounts.daiSupplyAmount = bound(amounts.daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    amounts.wethSupplyAmount = bound(amounts.wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    amounts.usdxSupplyAmount = bound(amounts.usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    amounts.wbtcSupplyAmount = bound(amounts.wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    amounts.daiBorrowAmount = bound(amounts.daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    amounts.wethBorrowAmount = bound(amounts.wethBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    amounts.usdxBorrowAmount = bound(amounts.usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    amounts.wbtcBorrowAmount = bound(amounts.wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);

    return amounts;
  }

  function _bound(Rates memory rates) internal view returns (Rates memory) {
    rates.daiBaseBorrowRate = _bpsToRay(
      bound(rates.daiBaseBorrowRate, 1, irStrategy.MAX_BORROW_RATE())
    ).toUint96();
    rates.wethBaseBorrowRate = _bpsToRay(
      bound(rates.wethBaseBorrowRate, 1, irStrategy.MAX_BORROW_RATE())
    ).toUint96();
    rates.usdxBaseBorrowRate = _bpsToRay(
      bound(rates.usdxBaseBorrowRate, 1, irStrategy.MAX_BORROW_RATE())
    ).toUint96();
    rates.wbtcBaseBorrowRate = _bpsToRay(
      bound(rates.wbtcBaseBorrowRate, 1, irStrategy.MAX_BORROW_RATE())
    ).toUint96();

    return rates;
  }

  function _ensureSufficientCollateral(
    ISpoke spoke,
    TestAmounts memory amounts
  ) internal view returns (TestAmounts memory) {
    uint256 remainingCollateralValue = _getValue(
      spoke,
      _daiReserveId(spoke),
      amounts.daiSupplyAmount
    ) +
      _getValue(spoke, _wethReserveId(spoke), amounts.wethSupplyAmount) +
      _getValue(spoke, _usdxReserveId(spoke), amounts.usdxSupplyAmount) +
      _getValue(spoke, _wbtcReserveId(spoke), amounts.wbtcSupplyAmount);

    // Bound each debt amount to be no more than half the remaining collateral value
    amounts.daiBorrowAmount = bound(
      amounts.daiBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _getValue(spoke, _daiReserveId(spoke), 1)
    );
    // Subtract out the set debt value from the remaining collateral value
    remainingCollateralValue -= _getValue(spoke, _daiReserveId(spoke), amounts.daiBorrowAmount) * 2;
    amounts.wethBorrowAmount = bound(
      amounts.wethBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _getValue(spoke, _wethReserveId(spoke), 1)
    );
    remainingCollateralValue -=
      _getValue(spoke, _wethReserveId(spoke), amounts.wethBorrowAmount) *
      2;
    amounts.usdxBorrowAmount = bound(
      amounts.usdxBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _getValue(spoke, _usdxReserveId(spoke), 1)
    );
    remainingCollateralValue -=
      _getValue(spoke, _usdxReserveId(spoke), amounts.usdxBorrowAmount) *
      2;
    amounts.wbtcBorrowAmount = bound(
      amounts.wbtcBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _getValue(spoke, _wbtcReserveId(spoke), 1)
    );

    assertGt(
      _getValue(spoke, _daiReserveId(spoke), amounts.daiSupplyAmount) +
        _getValue(spoke, _wethReserveId(spoke), amounts.wethSupplyAmount) +
        _getValue(spoke, _usdxReserveId(spoke), amounts.usdxSupplyAmount) +
        _getValue(spoke, _wbtcReserveId(spoke), amounts.wbtcSupplyAmount),
      2 *
        (_getValue(spoke, _daiReserveId(spoke), amounts.daiBorrowAmount) +
          _getValue(spoke, _wethReserveId(spoke), amounts.wethBorrowAmount) +
          _getValue(spoke, _usdxReserveId(spoke), amounts.usdxBorrowAmount) +
          _getValue(spoke, _wbtcReserveId(spoke), amounts.wbtcBorrowAmount)),
      'collateral sufficiently covers debt'
    );

    return amounts;
  }
}
