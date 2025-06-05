// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';

contract SpokeAccrueInterestTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMath for uint256;

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

  struct Indices {
    uint256 daiIndex;
    uint256 wethIndex;
    uint256 usdxIndex;
    uint256 wbtcIndex;
  }

  struct BaseShares {
    uint256 dai;
    uint256 weth;
    uint256 usdx;
    uint256 wbtc;
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
    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(daiReserveId, bob);

    uint256 baseDebt = _calculateExpectedBaseDebt(borrowAmount, baseBorrowRate, startTime);
    uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(userRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      baseDebt,
      expectedPremiumDebt,
      'after accrual'
    );

    startTime = uint40(vm.getBlockTimestamp());
    baseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    uint256 interest = (baseDebt + expectedPremiumDebt) - borrowAmount;

    // Full repayment, so back to zero debt
    Utils.repay(spoke1, daiReserveId, bob, type(uint256).max);

    bobPosition = spoke1.getUserPosition(daiReserveId, bob);

    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      supplyAmount + interest,
      'dai asset supplied amount'
    );
    (uint256 bobBaseDebt, uint256 bobPremiumDebt) = spoke1.getUserDebt(daiReserveId, bob);
    assertEq(bobBaseDebt, 0, 'bob base debt after repay');
    assertEq(bobPremiumDebt, 0, 'bob premium debt after repay');
    assertEq(spoke1.getUserTotalDebt(daiReserveId, bob), 0, 'bob total debt after repay');

    // Time passes
    skip(elapsed);

    bobPosition = spoke1.getUserPosition(daiReserveId, bob);

    (bobBaseDebt, bobPremiumDebt) = spoke1.getUserDebt(daiReserveId, bob);
    assertEq(bobBaseDebt, 0, 'bob base debt after repay and time skip');
    assertEq(bobPremiumDebt, 0, 'bob premium debt after repay and time skip');
    assertEq(
      spoke1.getUserTotalDebt(daiReserveId, bob),
      0,
      'bob total debt after repay and time skip'
    );
    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      supplyAmount + interest,
      'dai asset supplied amount after second time skip'
    );
    assertEq(getAssetBaseDebt(daiAssetId), 0, 'baseDebt');
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

    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(daiReserveId, bob);

    uint256 baseDebt = _calculateExpectedBaseDebt(borrowAmount, baseBorrowRate, startTime);
    uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(userRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      baseDebt,
      expectedPremiumDebt,
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

    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(usdxReserveId, bob);

    uint256 expectedBaseDebt = _calculateExpectedBaseDebt(borrowAmount, baseBorrowRate, startTime);
    uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(riskPremium);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(
      usdxAssetId,
      expectedPremiumDrawnShares
    ) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;

    _assertSingleUserProtocolDebt(
      spoke1,
      usdxReserveId,
      bob,
      expectedBaseDebt,
      expectedPremiumDebt,
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
    _ensureSufficientCollateral(amounts);

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
      _deployLiquidity(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT - amounts.daiSupplyAmount);
    }
    if (amounts.wethSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
        spoke1,
        _wethReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.wethSupplyAmount
      );
    }
    if (amounts.usdxSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
        spoke1,
        _usdxReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.usdxSupplyAmount
      );
    }
    if (amounts.wbtcSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
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

    // Check bob's base debt and premium debt for all assets at user, reserve, spoke, and asset level
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

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's base debt and premium debt for all assets at user, reserve, spoke, and asset level
    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'dai after accrual'
    );

    bobPosition = spoke1.getUserPosition(_wethReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(wethAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'weth after accrual'
    );

    bobPosition = spoke1.getUserPosition(_usdxReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(usdxAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'usdx after accrual'
    );

    bobPosition = spoke1.getUserPosition(_wbtcReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(wbtcAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      baseDebt,
      expectedPremiumDebt,
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
    _ensureSufficientCollateral(amounts);

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
      _deployLiquidity(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT - amounts.daiSupplyAmount);
    }
    if (amounts.wethSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
        spoke1,
        _wethReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.wethSupplyAmount
      );
    }
    if (amounts.usdxSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
        spoke1,
        _usdxReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.usdxSupplyAmount
      );
    }
    if (amounts.wbtcSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
        spoke1,
        _wbtcReserveId(spoke1),
        MAX_SUPPLY_AMOUNT - amounts.wbtcSupplyAmount
      );
    }

    // Bob borrows dai from spoke 1
    if (amounts.daiBorrowAmount > 0) {
      DataTypes.Asset memory asset = hub.getAsset(daiAssetId);
      (uint256 baseDebt, ) = hub.getAssetDebt(daiAssetId);
      DataTypes.CalculateInterestRatesParams memory params = DataTypes
        .CalculateInterestRatesParams({
          liquidityAdded: 0,
          liquidityTaken: amounts.daiBorrowAmount,
          totalDebt: baseDebt,
          reserveFactor: 0,
          assetId: daiAssetId,
          virtualUnderlyingBalance: asset.availableLiquidity,
          usingVirtualBalance: true
        });
      vm.mockCall(
        address(irStrategy),
        abi.encodeCall(IReserveInterestRateStrategy.calculateInterestRates, (params)),
        abi.encode(rates.daiBaseBorrowRate)
      );
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amounts.daiBorrowAmount, bob);
    }

    // Bob borrows weth from spoke 1
    if (amounts.wethBorrowAmount > 0) {
      DataTypes.Asset memory asset = hub.getAsset(wethAssetId);
      (uint256 baseDebt, ) = hub.getAssetDebt(wethAssetId);
      DataTypes.CalculateInterestRatesParams memory params = DataTypes
        .CalculateInterestRatesParams({
          liquidityAdded: 0,
          liquidityTaken: amounts.wethBorrowAmount,
          totalDebt: baseDebt,
          reserveFactor: 0,
          assetId: wethAssetId,
          virtualUnderlyingBalance: asset.availableLiquidity,
          usingVirtualBalance: true
        });
      vm.mockCall(
        address(irStrategy),
        abi.encodeCall(IReserveInterestRateStrategy.calculateInterestRates, (params)),
        abi.encode(rates.wethBaseBorrowRate)
      );
      Utils.borrow(spoke1, _wethReserveId(spoke1), bob, amounts.wethBorrowAmount, bob);
    }

    // Bob borrows usdx from spoke 1
    if (amounts.usdxBorrowAmount > 0) {
      DataTypes.Asset memory asset = hub.getAsset(usdxAssetId);
      (uint256 baseDebt, ) = hub.getAssetDebt(usdxAssetId);
      DataTypes.CalculateInterestRatesParams memory params = DataTypes
        .CalculateInterestRatesParams({
          liquidityAdded: 0,
          liquidityTaken: amounts.usdxBorrowAmount,
          totalDebt: baseDebt,
          reserveFactor: 0,
          assetId: usdxAssetId,
          virtualUnderlyingBalance: asset.availableLiquidity,
          usingVirtualBalance: true
        });
      vm.mockCall(
        address(irStrategy),
        abi.encodeCall(IReserveInterestRateStrategy.calculateInterestRates, (params)),
        abi.encode(rates.usdxBaseBorrowRate)
      );
      Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, amounts.usdxBorrowAmount, bob);
    }

    // Bob borrows wbtc from spoke 1
    if (amounts.wbtcBorrowAmount > 0) {
      DataTypes.Asset memory asset = hub.getAsset(wbtcAssetId);
      (uint256 baseDebt, ) = hub.getAssetDebt(wbtcAssetId);
      DataTypes.CalculateInterestRatesParams memory params = DataTypes
        .CalculateInterestRatesParams({
          liquidityAdded: 0,
          liquidityTaken: amounts.wbtcBorrowAmount,
          totalDebt: baseDebt,
          reserveFactor: 0,
          assetId: wbtcAssetId,
          virtualUnderlyingBalance: asset.availableLiquidity,
          usingVirtualBalance: true
        });
      vm.mockCall(
        address(irStrategy),
        abi.encodeCall(IReserveInterestRateStrategy.calculateInterestRates, (params)),
        abi.encode(rates.wbtcBaseBorrowRate)
      );
      Utils.borrow(spoke1, _wbtcReserveId(spoke1), bob, amounts.wbtcBorrowAmount, bob);
    }

    // Check Bob's risk premium
    uint256 bobRp = spoke1.getUserRiskPremium(bob);
    assertEq(bobRp, _calculateExpectedUserRP(bob, spoke1), 'user risk premium Before');

    // Check bob's base debt and premium debt for all assets at user, reserve, spoke, and asset level
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

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's base debt and premium debt for all assets at user, reserve, spoke, and asset level
    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'dai after accrual'
    );

    bobPosition = spoke1.getUserPosition(_wethReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(wethAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke1,
      _wethReserveId(spoke1),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'weth after accrual'
    );

    bobPosition = spoke1.getUserPosition(_usdxReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(usdxAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke1,
      _usdxReserveId(spoke1),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'usdx after accrual'
    );

    bobPosition = spoke1.getUserPosition(_wbtcReserveId(spoke1), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(wbtcAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke1,
      _wbtcReserveId(spoke1),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'wbtc after accrual'
    );
  }

  /// Second accrual after an action - which should update the user rp
  function test_accrueInterest_fuzz_RPBorrowAndskipTime_twoActions(
    TestAmounts memory amounts,
    uint40 skipTime
  ) public {
    amounts = _bound(amounts);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME / 2));

    // Ensure bob does not draw more than half his normalized supply value
    _ensureSufficientCollateral(amounts);

    uint40 startTime = uint40(vm.getBlockTimestamp());
    uint40 beginningTime = startTime;

    // Bob supply dai on spoke 2
    if (amounts.daiSupplyAmount > 0) {
      Utils.supplyCollateral(spoke2, _daiReserveId(spoke2), bob, amounts.daiSupplyAmount, bob);
    }

    // Bob supply weth on spoke 2
    if (amounts.wethSupplyAmount > 0) {
      Utils.supplyCollateral(spoke2, _wethReserveId(spoke2), bob, amounts.wethSupplyAmount, bob);
    }

    // Bob supply usdx on spoke 2
    if (amounts.usdxSupplyAmount > 0) {
      Utils.supplyCollateral(spoke2, _usdxReserveId(spoke2), bob, amounts.usdxSupplyAmount, bob);
    }

    // Bob supply wbtc on spoke 2
    if (amounts.wbtcSupplyAmount > 0) {
      Utils.supplyCollateral(spoke2, _wbtcReserveId(spoke2), bob, amounts.wbtcSupplyAmount, bob);
    }

    // Deploy remainder of liquidity
    if (amounts.daiSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(spoke2, _daiReserveId(spoke2), MAX_SUPPLY_AMOUNT - amounts.daiSupplyAmount);
    }
    if (amounts.wethSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
        spoke2,
        _wethReserveId(spoke2),
        MAX_SUPPLY_AMOUNT - amounts.wethSupplyAmount
      );
    }
    if (amounts.usdxSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
        spoke2,
        _usdxReserveId(spoke2),
        MAX_SUPPLY_AMOUNT - amounts.usdxSupplyAmount
      );
    }
    if (amounts.wbtcSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _deployLiquidity(
        spoke2,
        _wbtcReserveId(spoke2),
        MAX_SUPPLY_AMOUNT - amounts.wbtcSupplyAmount
      );
    }

    // Bob borrows dai from spoke 2
    if (amounts.daiBorrowAmount > 0) {
      Utils.borrow(spoke2, _daiReserveId(spoke2), bob, amounts.daiBorrowAmount, bob);
    }

    // Bob borrows weth from spoke 2
    if (amounts.wethBorrowAmount > 0) {
      Utils.borrow(spoke2, _wethReserveId(spoke2), bob, amounts.wethBorrowAmount, bob);
    }

    // Bob borrows usdx from spoke 2
    if (amounts.usdxBorrowAmount > 0) {
      Utils.borrow(spoke2, _usdxReserveId(spoke2), bob, amounts.usdxBorrowAmount, bob);
    }

    // Bob borrows wbtc from spoke 2
    if (amounts.wbtcBorrowAmount > 0) {
      Utils.borrow(spoke2, _wbtcReserveId(spoke2), bob, amounts.wbtcBorrowAmount, bob);
    }

    // Check Bob's risk premium
    uint256 bobRp = spoke2.getUserRiskPremium(bob);
    assertEq(bobRp, _calculateExpectedUserRP(bob, spoke2), 'user risk premium Before');

    // Store base borrow rates
    Rates memory rates;
    rates.daiBaseBorrowRate = hub.getBaseInterestRate(daiAssetId);
    rates.wethBaseBorrowRate = hub.getBaseInterestRate(wethAssetId);
    rates.usdxBaseBorrowRate = hub.getBaseInterestRate(usdxAssetId);
    rates.wbtcBaseBorrowRate = hub.getBaseInterestRate(wbtcAssetId);

    // Check bob's base debt and premium debt for all assets at user, reserve, spoke, and asset level
    uint256 baseDebt = _calculateExpectedBaseDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke2,
      _daiReserveId(spoke2),
      bob,
      baseDebt,
      0,
      'dai before accrual'
    );

    baseDebt = _calculateExpectedBaseDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke2,
      _wethReserveId(spoke2),
      bob,
      baseDebt,
      0,
      'weth before accrual'
    );

    baseDebt = _calculateExpectedBaseDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke2,
      _usdxReserveId(spoke2),
      bob,
      baseDebt,
      0,
      'usdx before accrual'
    );

    baseDebt = _calculateExpectedBaseDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke2,
      _wbtcReserveId(spoke2),
      bob,
      baseDebt,
      0,
      'wbtc before accrual'
    );

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's base debt and premium debt for all assets at user, reserve, spoke, and asset level
    DataTypes.UserPosition memory bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.daiBorrowAmount,
      rates.daiBaseBorrowRate,
      startTime
    );
    uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    uint256 expectedPremiumDebt = hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke2,
      _daiReserveId(spoke2),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'dai after accrual'
    );

    bobPosition = spoke2.getUserPosition(_wethReserveId(spoke2), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(wethAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke2,
      _wethReserveId(spoke2),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'weth after accrual'
    );

    bobPosition = spoke2.getUserPosition(_usdxReserveId(spoke2), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(usdxAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke2,
      _usdxReserveId(spoke2),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'usdx after accrual'
    );

    bobPosition = spoke2.getUserPosition(_wbtcReserveId(spoke2), bob);
    baseDebt = _calculateExpectedBaseDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(bobRp);
    expectedPremiumDebt =
      hub.convertToDrawnAssets(wbtcAssetId, expectedPremiumDrawnShares) -
      bobPosition.premiumOffset +
      bobPosition.realizedPremium;
    _assertSingleUserProtocolDebt(
      spoke2,
      _wbtcReserveId(spoke2),
      bob,
      baseDebt,
      expectedPremiumDebt,
      'wbtc after accrual'
    );

    // Only proceed with test if position is healthy
    if (spoke2.getHealthFactor(bob) >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      // Supply more collateral to ensure bob can borrow more dai to trigger accrual
      deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT);
      Utils.supplyCollateral(spoke2, _dai2ReserveId(spoke2), bob, MAX_SUPPLY_AMOUNT, bob);

      // Handle case that bob isn't already borrowing dai by borrowing 1 share
      bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
      if (bobPosition.baseDrawnShares == 0) {
        Utils.borrow(
          spoke2,
          _daiReserveId(spoke2),
          bob,
          hub.convertToDrawnAssets(daiAssetId, 1),
          bob
        );
      }
      // Construct mock call so we can see the same user rp calc as within the borrow function
      vm.mockCall(
        address(spoke2),
        abi.encodeCall(Spoke.getUserTotalDebt, (_daiReserveId(spoke2), bob)),
        abi.encode(spoke2.getUserTotalDebt(_daiReserveId(spoke2), bob) + 1e18) // Debt amount seen in the borrow function when calculating user rp
      );
      bobRp = _calculateExpectedUserRP(bob, spoke2);
      vm.clearMockedCalls();

      // Bob borrows more dai to trigger accrual
      Utils.borrow(spoke2, _daiReserveId(spoke2), bob, 1e18, bob);

      // Refresh debt values
      (amounts.daiBorrowAmount, ) = spoke2.getUserDebt(_daiReserveId(spoke2), bob);
      (amounts.wethBorrowAmount, ) = spoke2.getUserDebt(_wethReserveId(spoke2), bob);
      (amounts.usdxBorrowAmount, ) = spoke2.getUserDebt(_usdxReserveId(spoke2), bob);
      (amounts.wbtcBorrowAmount, ) = spoke2.getUserDebt(_wbtcReserveId(spoke2), bob);

      // Refresh base borrow rates
      rates.daiBaseBorrowRate = hub.getBaseInterestRate(daiAssetId);
      rates.wethBaseBorrowRate = hub.getBaseInterestRate(wethAssetId);
      rates.usdxBaseBorrowRate = hub.getBaseInterestRate(usdxAssetId);
      rates.wbtcBaseBorrowRate = hub.getBaseInterestRate(wbtcAssetId);

      BaseShares memory baseShares;

      // Check debt values before accrual
      bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
      expectedPremiumDebt = bobPosition.realizedPremium;
      _assertSingleUserProtocolDebt(
        spoke2,
        _daiReserveId(spoke2),
        bob,
        amounts.daiBorrowAmount,
        expectedPremiumDebt,
        'dai before second accrual'
      );
      baseShares.dai = bobPosition.baseDrawnShares;

      bobPosition = spoke2.getUserPosition(_wethReserveId(spoke2), bob);
      expectedPremiumDebt = bobPosition.realizedPremium;
      _assertSingleUserProtocolDebt(
        spoke2,
        _wethReserveId(spoke2),
        bob,
        amounts.wethBorrowAmount,
        expectedPremiumDebt,
        'weth before second accrual'
      );
      baseShares.weth = bobPosition.baseDrawnShares;

      bobPosition = spoke2.getUserPosition(_usdxReserveId(spoke2), bob);
      expectedPremiumDebt = bobPosition.realizedPremium;
      _assertSingleUserProtocolDebt(
        spoke2,
        _usdxReserveId(spoke2),
        bob,
        amounts.usdxBorrowAmount,
        expectedPremiumDebt,
        'usdx before second accrual'
      );
      baseShares.usdx = bobPosition.baseDrawnShares;

      bobPosition = spoke2.getUserPosition(_wbtcReserveId(spoke2), bob);
      expectedPremiumDebt = bobPosition.realizedPremium;
      _assertSingleUserProtocolDebt(
        spoke2,
        _wbtcReserveId(spoke2),
        bob,
        amounts.wbtcBorrowAmount,
        expectedPremiumDebt,
        'wbtc before second accrual'
      );
      baseShares.wbtc = bobPosition.baseDrawnShares;

      // Store index before accrual, and use this for calculating expected base debt
      Indices memory indices;
      indices.daiIndex = hub.getAsset(daiAssetId).baseDebtIndex;
      indices.wethIndex = hub.getAsset(wethAssetId).baseDebtIndex;
      indices.usdxIndex = hub.getAsset(usdxAssetId).baseDebtIndex;
      indices.wbtcIndex = hub.getAsset(wbtcAssetId).baseDebtIndex;

      // Store timestamp before next skip time
      startTime = uint40(vm.getBlockTimestamp());
      skipTime = uint40(randomizer(0, MAX_SKIP_TIME / 2));
      skip(skipTime);

      // Check bob's base debt and premium debt for all assets at user, reserve, spoke, and asset level
      indices.daiIndex = calculateExpectedDebtIndex(
        indices.daiIndex,
        rates.daiBaseBorrowRate,
        startTime
      );
      bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
      baseDebt = baseShares.dai.rayMulUp(indices.daiIndex);
      expectedPremiumDrawnShares = baseShares.dai.percentMul(bobRp);
      expectedPremiumDebt =
        hub.convertToDrawnAssets(daiAssetId, expectedPremiumDrawnShares) -
        bobPosition.premiumOffset +
        bobPosition.realizedPremium;
      _assertSingleUserProtocolDebt(
        spoke2,
        _daiReserveId(spoke2),
        bob,
        baseDebt,
        expectedPremiumDebt,
        'dai after second accrual'
      );

      indices.wethIndex = calculateExpectedDebtIndex(
        indices.wethIndex,
        rates.wethBaseBorrowRate,
        beginningTime // Weth and remaining assets have not been interacted with
      );
      bobPosition = spoke2.getUserPosition(_wethReserveId(spoke2), bob);
      assertEq(
        bobPosition.baseDrawnShares,
        baseShares.weth,
        'weth base drawn shares after second accrual'
      );
      baseDebt = baseShares.weth.rayMulUp(indices.wethIndex);
      expectedPremiumDrawnShares = baseShares.weth.percentMul(bobRp);
      expectedPremiumDebt =
        hub.convertToDrawnAssets(wethAssetId, expectedPremiumDrawnShares) -
        bobPosition.premiumOffset +
        bobPosition.realizedPremium;
      _assertSingleUserProtocolDebt(
        spoke2,
        _wethReserveId(spoke2),
        bob,
        baseDebt,
        expectedPremiumDebt,
        'weth after second accrual'
      );

      indices.usdxIndex = calculateExpectedDebtIndex(
        indices.usdxIndex,
        rates.usdxBaseBorrowRate,
        beginningTime
      );
      bobPosition = spoke2.getUserPosition(_usdxReserveId(spoke2), bob);
      baseDebt = baseShares.usdx.rayMulUp(indices.usdxIndex);
      expectedPremiumDrawnShares = baseShares.usdx.percentMul(bobRp);
      expectedPremiumDebt =
        hub.convertToDrawnAssets(usdxAssetId, expectedPremiumDrawnShares) -
        bobPosition.premiumOffset +
        bobPosition.realizedPremium;
      _assertSingleUserProtocolDebt(
        spoke2,
        _usdxReserveId(spoke2),
        bob,
        baseDebt,
        expectedPremiumDebt,
        'usdx after second accrual'
      );

      indices.wbtcIndex = calculateExpectedDebtIndex(
        indices.wbtcIndex,
        rates.wbtcBaseBorrowRate,
        beginningTime
      );
      bobPosition = spoke2.getUserPosition(_wbtcReserveId(spoke2), bob);
      baseDebt = baseShares.wbtc.rayMulUp(indices.wbtcIndex);
      expectedPremiumDrawnShares = baseShares.wbtc.percentMul(bobRp);
      expectedPremiumDebt =
        hub.convertToDrawnAssets(wbtcAssetId, expectedPremiumDrawnShares) -
        bobPosition.premiumOffset +
        bobPosition.realizedPremium;
      _assertSingleUserProtocolDebt(
        spoke2,
        _wbtcReserveId(spoke2),
        bob,
        baseDebt,
        expectedPremiumDebt,
        'wbtc after second accrual'
      );
    }
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

  function _ensureSufficientCollateral(TestAmounts memory amounts) internal view {
    vm.assume(
      _getValueInBaseCurrency(daiAssetId, amounts.daiSupplyAmount) +
        _getValueInBaseCurrency(wethAssetId, amounts.wethSupplyAmount) +
        _getValueInBaseCurrency(usdxAssetId, amounts.usdxSupplyAmount) +
        _getValueInBaseCurrency(wbtcAssetId, amounts.wbtcSupplyAmount) >
        2 *
          (_getValueInBaseCurrency(daiAssetId, amounts.daiBorrowAmount) +
            _getValueInBaseCurrency(wethAssetId, amounts.wethBorrowAmount) +
            _getValueInBaseCurrency(usdxAssetId, amounts.usdxBorrowAmount) +
            _getValueInBaseCurrency(wbtcAssetId, amounts.wbtcBorrowAmount))
    );
  }

  function _bpsToRay(uint256 bps) internal pure returns (uint256) {
    return (bps * WadRayMathExtended.RAY) / PercentageMath.PERCENTAGE_FACTOR;
  }
}
