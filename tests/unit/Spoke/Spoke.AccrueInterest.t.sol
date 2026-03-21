// SPDX-License-Identifier: MIT
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
    uint96 daiBaseDrawnRate;
    uint96 wethBaseDrawnRate;
    uint96 usdxBaseDrawnRate;
    uint96 wbtcBaseDrawnRate;
  }

  struct TestAmount {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 reserveId;
    uint256 assetId;
    string name;
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
    TestAmount[] memory testAmounts = _parseTestInputs(amounts);

    uint40 startTime = vm.getBlockTimestamp().toUint40();

    // Bob supplies amounts on spoke 1, then we deploy remainder of liquidity up to respective add caps
    for (uint256 i = 0; i < 4; ++i) {
      if (testAmounts[i].supplyAmount > 0) {
        Utils.supplyCollateral(
          spoke1,
          testAmounts[i].reserveId,
          bob,
          testAmounts[i].supplyAmount,
          bob
        );
      }
      if (testAmounts[i].supplyAmount < MAX_SUPPLY_AMOUNT) {
        _openSupplyPosition(
          spoke1,
          testAmounts[i].reserveId,
          MAX_SUPPLY_AMOUNT - testAmounts[i].supplyAmount
        );
      }
    }

    // Bob borrows amounts from spoke 1
    for (uint256 i = 0; i < 4; ++i) {
      if (testAmounts[i].borrowAmount > 0) {
        Utils.borrow(spoke1, testAmounts[i].reserveId, bob, testAmounts[i].borrowAmount, bob);
      }
    }

    // Check Bob's risk premium
    uint256 bobRp = _getUserRiskPremium(spoke1, bob);
    assertEq(bobRp, _calculateExpectedUserRP(spoke1, bob), 'user risk premium Before');

    // Store base borrow rates
    uint96[] memory baseDrawnRates = new uint96[](4);
    for (uint256 i = 0; i < 4; ++i) {
      baseDrawnRates[i] = hub1.getAssetDrawnRate(testAmounts[i].assetId).toUint96();
    }

    // Check bob's drawn debt, premium debt, and supplied amounts before accrual
    for (uint256 i = 0; i < 4; ++i) {
      uint256 drawnDebt = _calculateExpectedDrawnDebt(
        testAmounts[i].borrowAmount,
        baseDrawnRates[i],
        startTime
      );
      _assertProtocolSupplyAndDebt({
        spoke: spoke1,
        reserveId: testAmounts[i].reserveId,
        user: bob,
        reserveName: testAmounts[i].name,
        expectedUserSupply: testAmounts[i].supplyAmount,
        expectedReserveSupply: MAX_SUPPLY_AMOUNT,
        expectedDrawnDebt: drawnDebt,
        expectedPremiumDebt: 0,
        label: ' before accrual'
      });
    }

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's drawn debt, premium debt, and supplied amounts after accrual
    for (uint256 i = 0; i < 4; ++i) {
      uint256 drawnDebt = _calculateExpectedDrawnDebt(
        testAmounts[i].borrowAmount,
        baseDrawnRates[i],
        startTime
      );
      uint256 expectedPremiumDebt = _calculateExpectedPremiumDebt(
        testAmounts[i].borrowAmount,
        drawnDebt,
        bobRp
      );
      uint256 interest = (drawnDebt + expectedPremiumDebt) -
        testAmounts[i].borrowAmount -
        _calculateBurntInterest(hub1, testAmounts[i].assetId);
      uint256 expectedUserSupply = testAmounts[i].supplyAmount +
        (interest * testAmounts[i].supplyAmount) / MAX_SUPPLY_AMOUNT;

      _assertProtocolSupplyAndDebt({
        spoke: spoke1,
        reserveId: testAmounts[i].reserveId,
        user: bob,
        reserveName: testAmounts[i].name,
        expectedUserSupply: expectedUserSupply,
        expectedReserveSupply: MAX_SUPPLY_AMOUNT + interest,
        expectedDrawnDebt: drawnDebt,
        expectedPremiumDebt: expectedPremiumDebt,
        label: ' after accrual'
      });
    }
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
    TestAmount[] memory testAmounts = _parseTestInputs(amounts);
    uint96[] memory baseDrawnRates = _parseRates(rates);

    uint40 startTime = vm.getBlockTimestamp().toUint40();

    // Bob supplies amounts on spoke 1, then we deploy remainder of liquidity up to respective add caps
    for (uint256 i = 0; i < 4; ++i) {
      if (testAmounts[i].supplyAmount > 0) {
        Utils.supplyCollateral(
          spoke1,
          testAmounts[i].reserveId,
          bob,
          testAmounts[i].supplyAmount,
          bob
        );
      }
      if (testAmounts[i].supplyAmount < MAX_SUPPLY_AMOUNT) {
        _openSupplyPosition(
          spoke1,
          testAmounts[i].reserveId,
          MAX_SUPPLY_AMOUNT - testAmounts[i].supplyAmount
        );
      }
    }

    // Bob borrows amounts from spoke 1, mocking interest rates for each asset
    for (uint256 i = 0; i < 4; ++i) {
      if (testAmounts[i].borrowAmount > 0) {
        IHub.Asset memory asset = hub1.getAsset(testAmounts[i].assetId);
        uint256 borrowShares = hub1.previewDrawByAssets(
          testAmounts[i].assetId,
          testAmounts[i].borrowAmount
        );
        _mockDrawnRateRay({
          drawnRateRay: baseDrawnRates[i],
          assetId: testAmounts[i].assetId,
          liquidity: asset.liquidity - testAmounts[i].borrowAmount,
          drawn: hub1.previewRestoreByShares(
            testAmounts[i].assetId,
            asset.drawnShares + borrowShares
          )
        });
        Utils.borrow(spoke1, testAmounts[i].reserveId, bob, testAmounts[i].borrowAmount, bob);
      }
    }

    // Check Bob's risk premium
    uint256 bobRp = _getUserRiskPremium(spoke1, bob);
    assertEq(bobRp, _calculateExpectedUserRP(spoke1, bob), 'user risk premium Before');

    // Check bob's drawn debt, premium debt, and supplied amounts before accrual
    for (uint256 i = 0; i < 4; ++i) {
      uint256 drawnDebt = _calculateExpectedDrawnDebt(
        testAmounts[i].borrowAmount,
        baseDrawnRates[i],
        startTime
      );
      _assertProtocolSupplyAndDebt({
        spoke: spoke1,
        reserveId: testAmounts[i].reserveId,
        user: bob,
        reserveName: testAmounts[i].name,
        expectedUserSupply: testAmounts[i].supplyAmount,
        expectedReserveSupply: MAX_SUPPLY_AMOUNT,
        expectedDrawnDebt: drawnDebt,
        expectedPremiumDebt: 0,
        label: ' before accrual'
      });
    }

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's drawn debt, premium debt, and supplied amounts after accrual
    for (uint256 i = 0; i < 4; ++i) {
      ISpoke.UserPosition memory bobPosition = spoke1.getUserPosition(
        testAmounts[i].reserveId,
        bob
      );
      uint256 drawnDebt = _calculateExpectedDrawnDebt(
        testAmounts[i].borrowAmount,
        baseDrawnRates[i],
        startTime
      );
      uint256 expectedpremiumShares = bobPosition.drawnShares.percentMulUp(bobRp);
      uint256 expectedPremiumDebt = _calculatePremiumDebt(
        hub1,
        testAmounts[i].assetId,
        expectedpremiumShares,
        bobPosition.premiumOffsetRay
      );
      uint256 interest = (drawnDebt + expectedPremiumDebt) -
        testAmounts[i].borrowAmount -
        _calculateBurntInterest(hub1, testAmounts[i].assetId);
      uint256 expectedUserSupply = testAmounts[i].supplyAmount +
        (interest * testAmounts[i].supplyAmount) / MAX_SUPPLY_AMOUNT;

      _assertProtocolSupplyAndDebt({
        spoke: spoke1,
        reserveId: testAmounts[i].reserveId,
        user: bob,
        reserveName: testAmounts[i].name,
        expectedUserSupply: expectedUserSupply,
        expectedReserveSupply: MAX_SUPPLY_AMOUNT + interest,
        expectedDrawnDebt: drawnDebt,
        expectedPremiumDebt: expectedPremiumDebt,
        label: ' after accrual'
      });
    }
  }

  function _bound(TestAmounts memory amounts) internal view returns (TestAmounts memory) {
    amounts.daiSupplyAmount = bound(amounts.daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT_DAI);
    amounts.wethSupplyAmount = bound(amounts.wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT_WETH);
    amounts.usdxSupplyAmount = bound(amounts.usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT_USDX);
    amounts.wbtcSupplyAmount = bound(amounts.wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT_WBTC);
    amounts.daiBorrowAmount = bound(amounts.daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT_DAI);
    amounts.wethBorrowAmount = bound(amounts.wethBorrowAmount, 0, MAX_SUPPLY_AMOUNT_WETH);
    amounts.usdxBorrowAmount = bound(amounts.usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT_USDX);
    amounts.wbtcBorrowAmount = bound(amounts.wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT_WBTC);

    return amounts;
  }

  function _bound(Rates memory rates) internal view returns (Rates memory) {
    rates.daiBaseDrawnRate = _bpsToRay(
      bound(rates.daiBaseDrawnRate, 1, Constants.MAX_ALLOWED_DRAWN_RATE)
    ).toUint96();
    rates.wethBaseDrawnRate = _bpsToRay(
      bound(rates.wethBaseDrawnRate, 1, Constants.MAX_ALLOWED_DRAWN_RATE)
    ).toUint96();
    rates.usdxBaseDrawnRate = _bpsToRay(
      bound(rates.usdxBaseDrawnRate, 1, Constants.MAX_ALLOWED_DRAWN_RATE)
    ).toUint96();
    rates.wbtcBaseDrawnRate = _bpsToRay(
      bound(rates.wbtcBaseDrawnRate, 1, Constants.MAX_ALLOWED_DRAWN_RATE)
    ).toUint96();

    return rates;
  }

  function _parseTestInputs(
    TestAmounts memory amounts
  ) internal view returns (TestAmount[] memory) {
    TestAmount[] memory testAmounts = new TestAmount[](4);

    testAmounts[0] = TestAmount({
      supplyAmount: amounts.daiSupplyAmount,
      borrowAmount: amounts.daiBorrowAmount,
      reserveId: _daiReserveId(spoke1),
      assetId: daiAssetId,
      name: 'DAI'
    });

    testAmounts[1] = TestAmount({
      supplyAmount: amounts.wethSupplyAmount,
      borrowAmount: amounts.wethBorrowAmount,
      reserveId: _wethReserveId(spoke1),
      assetId: wethAssetId,
      name: 'WETH'
    });

    testAmounts[2] = TestAmount({
      supplyAmount: amounts.usdxSupplyAmount,
      borrowAmount: amounts.usdxBorrowAmount,
      reserveId: _usdxReserveId(spoke1),
      assetId: usdxAssetId,
      name: 'USDX'
    });

    testAmounts[3] = TestAmount({
      supplyAmount: amounts.wbtcSupplyAmount,
      borrowAmount: amounts.wbtcBorrowAmount,
      reserveId: _wbtcReserveId(spoke1),
      assetId: wbtcAssetId,
      name: 'WBTC'
    });

    return testAmounts;
  }

  function _parseRates(Rates memory rates) internal pure returns (uint96[] memory) {
    uint96[] memory parsedRates = new uint96[](4);
    parsedRates[0] = rates.daiBaseDrawnRate;
    parsedRates[1] = rates.wethBaseDrawnRate;
    parsedRates[2] = rates.usdxBaseDrawnRate;
    parsedRates[3] = rates.wbtcBaseDrawnRate;
    return parsedRates;
  }

  function _ensureSufficientCollateral(
    ISpoke spoke,
    TestAmounts memory amounts
  ) internal view returns (TestAmounts memory) {
    uint256 remainingCollateralValue = _convertAmountToValue(
      spoke,
      _daiReserveId(spoke),
      amounts.daiSupplyAmount
    ) +
      _convertAmountToValue(spoke, _wethReserveId(spoke), amounts.wethSupplyAmount) +
      _convertAmountToValue(spoke, _usdxReserveId(spoke), amounts.usdxSupplyAmount) +
      _convertAmountToValue(spoke, _wbtcReserveId(spoke), amounts.wbtcSupplyAmount);

    // Bound each debt amount to be no more than half the remaining collateral value
    amounts.daiBorrowAmount = bound(
      amounts.daiBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _convertAmountToValue(spoke, _daiReserveId(spoke), 1)
    );
    // Subtract out the set debt value from the remaining collateral value
    remainingCollateralValue -=
      _convertAmountToValue(spoke, _daiReserveId(spoke), amounts.daiBorrowAmount) * 2;
    amounts.wethBorrowAmount = bound(
      amounts.wethBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _convertAmountToValue(spoke, _wethReserveId(spoke), 1)
    );
    remainingCollateralValue -=
      _convertAmountToValue(spoke, _wethReserveId(spoke), amounts.wethBorrowAmount) * 2;
    amounts.usdxBorrowAmount = bound(
      amounts.usdxBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _convertAmountToValue(spoke, _usdxReserveId(spoke), 1)
    );
    remainingCollateralValue -=
      _convertAmountToValue(spoke, _usdxReserveId(spoke), amounts.usdxBorrowAmount) * 2;
    amounts.wbtcBorrowAmount = bound(
      amounts.wbtcBorrowAmount,
      0,
      (remainingCollateralValue / 2) / _convertAmountToValue(spoke, _wbtcReserveId(spoke), 1)
    );

    assertGt(
      _convertAmountToValue(spoke, _daiReserveId(spoke), amounts.daiSupplyAmount) +
        _convertAmountToValue(spoke, _wethReserveId(spoke), amounts.wethSupplyAmount) +
        _convertAmountToValue(spoke, _usdxReserveId(spoke), amounts.usdxSupplyAmount) +
        _convertAmountToValue(spoke, _wbtcReserveId(spoke), amounts.wbtcSupplyAmount),
      2 *
        (_convertAmountToValue(spoke, _daiReserveId(spoke), amounts.daiBorrowAmount) +
          _convertAmountToValue(spoke, _wethReserveId(spoke), amounts.wethBorrowAmount) +
          _convertAmountToValue(spoke, _usdxReserveId(spoke), amounts.usdxBorrowAmount) +
          _convertAmountToValue(spoke, _wbtcReserveId(spoke), amounts.wbtcBorrowAmount)),
      'collateral sufficiently covers debt'
    );

    return amounts;
  }
}
