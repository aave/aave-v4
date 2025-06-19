// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueInterestTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMathExtended for uint256;

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
    uint256 daiBaseBorrowRate;
    uint256 wethBaseBorrowRate;
    uint256 usdxBaseBorrowRate;
    uint256 wbtcBaseBorrowRate;
  }

  function setUp() public override {
    super.setUp();
    updateLiquidityFee(hub, daiAssetId, 0);
    updateLiquidityFee(hub, wethAssetId, 0);
    updateLiquidityFee(hub, usdxAssetId, 0);
    updateLiquidityFee(hub, wbtcAssetId, 0);
  }

  function test_accrueInterest_NoActionTaken() public {
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
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
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
    elapsed = uint40(bound(elapsed, 1, MAX_SKIP_TIME));

    uint256 supplyAmount = 1000e18;
    uint40 startTime = uint40(vm.getBlockTimestamp());
    uint256 borrowAmount = 100e18;
    uint256 daiReserveId = _daiReserveId(spoke1);

    Utils.supplyCollateral(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 userRp = spoke1.getUserRiskPremium(bob);

    // Time passes
    skip(elapsed);

    // Check debts after interest accrual
    uint256 baseDebt = _calculateExpectedBaseDebt(borrowAmount, baseBorrowRate, startTime);
    uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(borrowAmount, baseDebt, userRp);
    uint256 interest = (baseDebt + expectedPremiumDebt) - borrowAmount;

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      baseDebt,
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

    startTime = uint40(vm.getBlockTimestamp());
    baseBorrowRate = hub.getBaseInterestRate(daiAssetId);

    // Full repayment, so back to zero debt
    Utils.repay(spoke1, daiReserveId, bob, type(uint256).max);

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
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
    uint256 supplyAmount = borrowAmount * 2;
    uint40 startTime = uint40(vm.getBlockTimestamp());
    uint256 daiReserveId = _daiReserveId(spoke1);

    // Bob supplies and borrows through spoke 1
    Utils.supplyCollateral(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 userRp = spoke1.getUserRiskPremium(bob);

    // Time passes
    skip(skipTime);

    uint256 baseDebt = _calculateExpectedBaseDebt(borrowAmount, baseBorrowRate, startTime);
    uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(borrowAmount, baseDebt, userRp);
    uint256 interest = (baseDebt + expectedPremiumDebt) - borrowAmount;

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      baseDebt,
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
  }

  function test_accrueInterest_TenPercentRp(uint256 borrowAmount, uint40 skipTime) public {
    borrowAmount = bound(borrowAmount, 1e6, MAX_SUPPLY_AMOUNT / 2);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
    uint256 supplyAmount = borrowAmount * 2;
    uint40 startTime = uint40(vm.getBlockTimestamp());
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    // Set liquidity premium of usdx on spoke1 to 10%
    updateLiquidityPremium(spoke1, usdxReserveId, 10_00);
    assertEq(10_00, _getLiquidityPremium(spoke1, usdxReserveId), 'usdx liquidity premium');

    // Bob supply usdx
    Utils.supplyCollateral(spoke1, usdxReserveId, bob, supplyAmount, bob);

    // Bob borrows usdx
    Utils.borrow(spoke1, usdxReserveId, bob, borrowAmount, bob);

    // User risk premium should be 10%
    uint256 riskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(riskPremium, 10_00, 'user risk premium');
    uint256 baseBorrowRate = hub.getBaseInterestRate(usdxAssetId);

    skip(skipTime);

    uint256 expectedBaseDebt = _calculateExpectedBaseDebt(borrowAmount, baseBorrowRate, startTime);
    uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(
      borrowAmount,
      expectedBaseDebt,
      riskPremium
    );
    uint256 interest = (expectedBaseDebt + expectedPremiumDebt) - borrowAmount;

    _assertSingleUserProtocolDebt(
      spoke1,
      usdxReserveId,
      bob,
      expectedBaseDebt,
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
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));

    // Ensure bob does not draw more than half his normalized supply value
    amounts = _ensureSufficientCollateral(amounts);

    uint40 startTime = uint40(vm.getBlockTimestamp());

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
    uint256 bobRp = spoke1.getUserRiskPremium(bob);
    assertEq(bobRp, _calculateExpectedUserRP(bob, spoke1), 'user risk premium Before');

    // Store base borrow rates
    Rates memory rates;
    rates.daiBaseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    rates.wethBaseBorrowRate = hub.getBaseInterestRate(wethAssetId);
    rates.usdxBaseBorrowRate = hub.getBaseInterestRate(usdxAssetId);
    rates.wbtcBaseBorrowRate = hub.getBaseInterestRate(wbtcAssetId);

    // Check bob's base debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    uint256 baseDebt = _calculateExpectedBaseDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      baseDebt,
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

    // Check bob's base debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    baseDebt = _calculateExpectedBaseDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(
      amounts.daiBorrowAmount,
      baseDebt,
      bobRp
    );
    uint256 interest = (baseDebt + expectedPremiumDebt) - amounts.daiBorrowAmount;
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    expectedPremiumDebt = _calculateExpectedPremiumDebt(amounts.wethBorrowAmount, baseDebt, bobRp);
    interest = (baseDebt + expectedPremiumDebt) - amounts.wethBorrowAmount;
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    expectedPremiumDebt = _calculateExpectedPremiumDebt(amounts.usdxBorrowAmount, baseDebt, bobRp);
    interest = (baseDebt + expectedPremiumDebt) - amounts.usdxBorrowAmount;
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    expectedPremiumDebt = _calculateExpectedPremiumDebt(amounts.wbtcBorrowAmount, baseDebt, bobRp);
    interest = (baseDebt + expectedPremiumDebt) - amounts.wbtcBorrowAmount;
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      baseDebt,
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
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));

    // Ensure bob does not draw more than half his normalized supply value
    amounts = _ensureSufficientCollateral(amounts);

    uint40 startTime = uint40(vm.getBlockTimestamp());

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
      DataTypes.Asset memory asset = hub.getAsset(daiAssetId);
      (uint256 baseDebt, ) = hub.getAssetDebt(daiAssetId);
      vm.mockCall(
        address(irStrategy),
        abi.encodeCall(
          IBasicInterestRateStrategy.calculateInterestRate,
          (daiAssetId, asset.availableLiquidity, baseDebt, 0, amounts.daiBorrowAmount)
        ),
        abi.encode(rates.daiBaseBorrowRate)
      );
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amounts.daiBorrowAmount, bob);
    }

    // Bob borrows weth from spoke 1
    if (amounts.wethBorrowAmount > 0) {
      DataTypes.Asset memory asset = hub.getAsset(wethAssetId);
      (uint256 baseDebt, ) = hub.getAssetDebt(wethAssetId);
      vm.mockCall(
        address(irStrategy),
        abi.encodeCall(
          IBasicInterestRateStrategy.calculateInterestRate,
          (wethAssetId, asset.availableLiquidity, baseDebt, 0, amounts.wethBorrowAmount)
        ),
        abi.encode(rates.wethBaseBorrowRate)
      );
      Utils.borrow(spoke1, _wethReserveId(spoke1), bob, amounts.wethBorrowAmount, bob);
    }

    // Bob borrows usdx from spoke 1
    if (amounts.usdxBorrowAmount > 0) {
      DataTypes.Asset memory asset = hub.getAsset(usdxAssetId);
      (uint256 baseDebt, ) = hub.getAssetDebt(usdxAssetId);
      vm.mockCall(
        address(irStrategy),
        abi.encodeCall(
          IBasicInterestRateStrategy.calculateInterestRate,
          (usdxAssetId, asset.availableLiquidity, baseDebt, 0, amounts.usdxBorrowAmount)
        ),
        abi.encode(rates.usdxBaseBorrowRate)
      );
      Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, amounts.usdxBorrowAmount, bob);
    }

    // Bob borrows wbtc from spoke 1
    if (amounts.wbtcBorrowAmount > 0) {
      DataTypes.Asset memory asset = hub.getAsset(wbtcAssetId);
      (uint256 baseDebt, ) = hub.getAssetDebt(wbtcAssetId);
      vm.mockCall(
        address(irStrategy),
        abi.encodeCall(
          IBasicInterestRateStrategy.calculateInterestRate,
          (wbtcAssetId, asset.availableLiquidity, baseDebt, 0, amounts.wbtcBorrowAmount)
        ),
        abi.encode(rates.wbtcBaseBorrowRate)
      );
      Utils.borrow(spoke1, _wbtcReserveId(spoke1), bob, amounts.wbtcBorrowAmount, bob);
    }

    // Check Bob's risk premium
    uint256 bobRp = spoke1.getUserRiskPremium(bob);
    assertEq(bobRp, _calculateExpectedUserRP(bob, spoke1), 'user risk premium Before');

    // Check bob's base debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    uint256 baseDebt = _calculateExpectedBaseDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      baseDebt,
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

    baseDebt = _calculateExpectedBaseDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      baseDebt,
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

    // Check bob's base debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMulUp(bobRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    uint256 interest = (baseDebt + expectedPremiumDebt) - amounts.daiBorrowAmount;
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      baseDebt,
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
    baseDebt = _calculateExpectedBaseDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMulUp(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(wethAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    interest = (baseDebt + expectedPremiumDebt) - amounts.wethBorrowAmount;
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      baseDebt,
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
    baseDebt = _calculateExpectedBaseDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMulUp(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(usdxAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    interest = (baseDebt + expectedPremiumDebt) - amounts.usdxBorrowAmount;
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      baseDebt,
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
    baseDebt = _calculateExpectedBaseDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMulUp(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(wbtcAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    interest = (baseDebt + expectedPremiumDebt) - amounts.wbtcBorrowAmount;
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      baseDebt,
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
    rates.daiBaseBorrowRate = bound(rates.daiBaseBorrowRate, 1, irStrategy.MAX_BORROW_RATE());
    rates.wethBaseBorrowRate = bound(rates.wethBaseBorrowRate, 1, irStrategy.MAX_BORROW_RATE());
    rates.usdxBaseBorrowRate = bound(rates.usdxBaseBorrowRate, 1, irStrategy.MAX_BORROW_RATE());
    rates.wbtcBaseBorrowRate = bound(rates.wbtcBaseBorrowRate, 1, irStrategy.MAX_BORROW_RATE());

    // Put rates in ray
    rates.daiBaseBorrowRate = _bpsToRay(rates.daiBaseBorrowRate);
    rates.wethBaseBorrowRate = _bpsToRay(rates.wethBaseBorrowRate);
    rates.usdxBaseBorrowRate = _bpsToRay(rates.usdxBaseBorrowRate);
    rates.wbtcBaseBorrowRate = _bpsToRay(rates.wbtcBaseBorrowRate);

    return rates;
  }

  function _ensureSufficientCollateral(
    TestAmounts memory amounts
  ) internal view returns (TestAmounts memory) {
    uint256 remainingCollateralValue = _getValueInBaseCurrency(
      daiAssetId,
      amounts.daiSupplyAmount
    ) +
      _getValueInBaseCurrency(wethAssetId, amounts.wethSupplyAmount) +
      _getValueInBaseCurrency(usdxAssetId, amounts.usdxSupplyAmount) +
      _getValueInBaseCurrency(wbtcAssetId, amounts.wbtcSupplyAmount);

    // Bound each debt amount to be no more than half the remaining collateral value
    amounts.daiBorrowAmount = bound(
      amounts.daiBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _getValueInBaseCurrency(daiAssetId, 1)
    );
    // Subtract out the set debt value from the remaining collateral value
    remainingCollateralValue -= _getValueInBaseCurrency(daiAssetId, amounts.daiBorrowAmount) * 2;
    amounts.wethBorrowAmount = bound(
      amounts.wethBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _getValueInBaseCurrency(wethAssetId, 1)
    );
    remainingCollateralValue -= _getValueInBaseCurrency(wethAssetId, amounts.wethBorrowAmount) * 2;
    amounts.usdxBorrowAmount = bound(
      amounts.usdxBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _getValueInBaseCurrency(usdxAssetId, 1)
    );
    remainingCollateralValue -= _getValueInBaseCurrency(usdxAssetId, amounts.usdxBorrowAmount) * 2;
    amounts.wbtcBorrowAmount = bound(
      amounts.wbtcBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _getValueInBaseCurrency(wbtcAssetId, 1)
    );

    assertGt(
      _getValueInBaseCurrency(daiAssetId, amounts.daiSupplyAmount) +
        _getValueInBaseCurrency(wethAssetId, amounts.wethSupplyAmount) +
        _getValueInBaseCurrency(usdxAssetId, amounts.usdxSupplyAmount) +
        _getValueInBaseCurrency(wbtcAssetId, amounts.wbtcSupplyAmount),
      2 *
        (_getValueInBaseCurrency(daiAssetId, amounts.daiBorrowAmount) +
          _getValueInBaseCurrency(wethAssetId, amounts.wethBorrowAmount) +
          _getValueInBaseCurrency(usdxAssetId, amounts.usdxBorrowAmount) +
          _getValueInBaseCurrency(wbtcAssetId, amounts.wbtcBorrowAmount)),
      'collateral sufficiently covers debt'
    );

    return amounts;
  }

  function _bpsToRay(uint256 bps) internal pure returns (uint256) {
    return (bps * WadRayMathExtended.RAY) / PercentageMath.PERCENTAGE_FACTOR;
  }
}
