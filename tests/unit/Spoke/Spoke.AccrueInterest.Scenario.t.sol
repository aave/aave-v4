// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueInterestScenarioTest is SpokeBase {
  using WadRayMath for *;
  using SafeCast for *;

  struct TestInputs {
    uint256 daiSupplyAmount;
    uint256 wethSupplyAmount;
    uint256 usdxSupplyAmount;
    uint256 wbtcSupplyAmount;
    uint256 daiBorrowAmount;
    uint256 wethBorrowAmount;
    uint256 usdxBorrowAmount;
    uint256 wbtcBorrowAmount;
  }

  struct TestAmount {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 originalSupplyAmount;
    uint256 originalBorrowAmount;
    uint256 index;
    uint256 originalIndex;
    uint256 reserveId;
    uint256 assetId;
    string name;
  }

  struct TestValues {
    uint96 baseBorrowRate;
    uint256 index;
    uint256 baseShares;
    uint40 timestamp;
  }

  function setUp() public override {
    super.setUp();
    updateLiquidityFee(hub1, daiAssetId, 0);
    updateLiquidityFee(hub1, wethAssetId, 0);
    updateLiquidityFee(hub1, usdxAssetId, 0);
    updateLiquidityFee(hub1, wbtcAssetId, 0);
    updateLiquidityFee(hub1, usdzAssetId, 0);
  }

  /// @dev Check protocol supply and debt values after two separate interest accruals with multiple assets supplied and borrowed
  /// @dev Ensures interest accrues correctly after each accrual, in accordance with the user's expected risk premium
  function test_accrueInterest_fuzz_RPBorrowAndSkipTime_twoActions(
    TestInputs memory amounts,
    uint40 skipTime
  ) public {
    amounts = _bound(amounts);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME / 2).toUint40();
    uint40 startTime = vm.getBlockTimestamp().toUint40();

    // Ensure bob does not draw more than half his normalized supply value
    amounts = _ensureSufficientCollateral(spoke2, amounts);
    TestAmount[] memory testAmounts = _parseTestInputs(amounts);

    // Bob supplies amounts on spoke 2, then we deploy remainder of liquidity up to respective supply caps
    for (uint256 i = 0; i < 4; ++i) {
      if (testAmounts[i].supplyAmount > 0) {
        Utils.supplyCollateral(
          spoke2,
          testAmounts[i].reserveId,
          bob,
          testAmounts[i].supplyAmount,
          bob
        );
      }
      // Deploy remainder of liquidity for each asset
      if (testAmounts[i].supplyAmount < MAX_SUPPLY_AMOUNT) {
        _openSupplyPosition(
          spoke2,
          testAmounts[i].reserveId,
          MAX_SUPPLY_AMOUNT - testAmounts[i].supplyAmount
        );
      }
    }

    // Bob borrows amounts from spoke 2
    for (uint256 i = 0; i < 4; ++i) {
      if (testAmounts[i].borrowAmount > 0) {
        Utils.borrow(spoke2, testAmounts[i].reserveId, bob, testAmounts[i].borrowAmount, bob);
      }
    }

    // Check Bob's risk premium
    uint256 bobRp = _getUserRiskPremium(spoke2, bob);
    assertEq(bobRp, _calculateExpectedUserRP(spoke2, bob), 'user risk premium Before');

    // Store base borrow rates
    TestValues[] memory values = new TestValues[](4);
    for (uint256 i = 0; i < 4; ++i) {
      values[i].baseBorrowRate = hub1.getAsset(testAmounts[i].assetId).drawnRate.toUint96();
    }

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    for (uint256 i = 0; i < 4; ++i) {
      uint256 drawnDebt = _calculateExpectedDrawnDebt(
        testAmounts[i].borrowAmount,
        values[i].baseBorrowRate,
        startTime
      );
      _assertProtocolSupplyAndDebt({
        reserveId: testAmounts[i].reserveId,
        reserveName: testAmounts[i].name,
        expectedUserSupply: testAmounts[i].supplyAmount,
        expectedReserveSupply: MAX_SUPPLY_AMOUNT,
        expectedDrawnDebt: drawnDebt,
        expectedPremiumDebt: 0,
        label: ' before first accrual'
      });
    }

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    for (uint256 i = 0; i < 4; ++i) {
      uint256 drawnDebt = _calculateExpectedDrawnDebt(
        testAmounts[i].borrowAmount,
        values[i].baseBorrowRate,
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
        reserveId: testAmounts[i].reserveId,
        reserveName: testAmounts[i].name,
        expectedUserSupply: expectedUserSupply,
        expectedReserveSupply: MAX_SUPPLY_AMOUNT + interest,
        expectedDrawnDebt: drawnDebt,
        expectedPremiumDebt: expectedPremiumDebt,
        label: ' after first accrual'
      });
    }

    // Only proceed with test if position is healthy
    if (_getUserHealthFactor(spoke2, bob) >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      // Supply more collateral to ensure bob can borrow more dai to trigger accrual
      deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT);
      Utils.supplyCollateral(spoke2, _usdzReserveId(spoke2), bob, MAX_SUPPLY_AMOUNT, bob);

      uint256 daiBorrowAmount = 1e18;

      // Bob borrows more dai to trigger accrual
      Utils.borrow(spoke2, _daiReserveId(spoke2), bob, daiBorrowAmount, bob);
      // Account for the dai we just borrowed
      testAmounts[0].originalBorrowAmount += daiBorrowAmount;

      bobRp = _calculateExpectedUserRP(spoke2, bob);

      // Update amounts for second accrual checks
      for (uint256 i = 0; i < 4; ++i) {
        (testAmounts[i].borrowAmount, ) = spoke2.getUserDebt(testAmounts[i].reserveId, bob);
        values[i].baseBorrowRate = hub1.getAsset(testAmounts[i].assetId).drawnRate.toUint96();
        values[i].index = hub1.getAssetDrawnIndex(testAmounts[i].assetId).toUint120();
        values[i].timestamp = hub1.getAsset(testAmounts[i].assetId).lastUpdateTimestamp;
        values[i].baseShares = spoke2.getUserPosition(testAmounts[i].reserveId, bob).drawnShares;
      }

      // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
      for (uint256 i = 0; i < 4; ++i) {
        ISpoke.UserPosition memory bobPosition = spoke2.getUserPosition(
          testAmounts[i].reserveId,
          bob
        );
        uint256 drawnDebt = testAmounts[i].borrowAmount;
        uint256 expectedPremiumDebt = _calculatePremiumDebt(
          hub1,
          testAmounts[i].assetId,
          bobPosition.premiumShares,
          bobPosition.premiumOffsetRay
        );
        uint256 interest = (drawnDebt + expectedPremiumDebt) -
          testAmounts[i].originalBorrowAmount -
          _calculateBurntInterest(hub1, testAmounts[i].assetId);
        uint256 expectedUserSupply = testAmounts[i].originalSupplyAmount +
          (interest * testAmounts[i].originalSupplyAmount) / MAX_SUPPLY_AMOUNT;

        _assertProtocolSupplyAndDebt({
          reserveId: testAmounts[i].reserveId,
          reserveName: testAmounts[i].name,
          expectedUserSupply: expectedUserSupply,
          expectedReserveSupply: MAX_SUPPLY_AMOUNT + interest,
          expectedDrawnDebt: drawnDebt,
          expectedPremiumDebt: expectedPremiumDebt,
          label: ' before second accrual'
        });
      }

      // Store timestamp before next skip time
      startTime = vm.getBlockTimestamp().toUint40();
      skipTime = randomizer(0, MAX_SKIP_TIME / 2).toUint40();
      skip(skipTime);

      // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
      for (uint256 i = 0; i < 4; ++i) {
        if (testAmounts[i].originalBorrowAmount == 0) {
          _assertProtocolSupplyAndDebt({
            reserveId: testAmounts[i].reserveId,
            reserveName: testAmounts[i].name,
            expectedUserSupply: testAmounts[i].originalSupplyAmount,
            expectedReserveSupply: MAX_SUPPLY_AMOUNT,
            expectedDrawnDebt: 0,
            expectedPremiumDebt: 0,
            label: ' after second accrual'
          });
          continue;
        }
        values[i].index = _calculateExpectedDrawnIndex(
          values[i].timestamp == 1 ? testAmounts[i].originalIndex : values[i].index, // If reserve never updated, use original index
          values[i].baseBorrowRate,
          values[i].timestamp
        );
        ISpoke.UserPosition memory bobPosition = spoke2.getUserPosition(
          testAmounts[i].reserveId,
          bob
        );
        uint256 drawnDebt = values[i].baseShares.rayMulUp(values[i].index);
        uint256 expectedPremiumDebt = _calculatePremiumDebt(
          hub1,
          testAmounts[i].assetId,
          bobPosition.premiumShares,
          bobPosition.premiumOffsetRay
        );
        uint256 interest = (drawnDebt + expectedPremiumDebt) -
          testAmounts[i].originalBorrowAmount -
          _calculateBurntInterest(hub1, testAmounts[i].assetId);
        uint256 expectedUserSupply = testAmounts[i].originalSupplyAmount +
          (interest * testAmounts[i].originalSupplyAmount) / MAX_SUPPLY_AMOUNT;

        _assertProtocolSupplyAndDebt({
          reserveId: testAmounts[i].reserveId,
          reserveName: testAmounts[i].name,
          expectedUserSupply: expectedUserSupply,
          expectedReserveSupply: MAX_SUPPLY_AMOUNT + interest,
          expectedDrawnDebt: drawnDebt,
          expectedPremiumDebt: expectedPremiumDebt,
          label: ' after second accrual'
        });
      }
    }
  }

  function _bound(TestInputs memory amounts) internal view returns (TestInputs memory) {
    amounts.daiSupplyAmount = bound(amounts.daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT_DAI);
    amounts.wethSupplyAmount = bound(amounts.wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT_WETH);
    amounts.usdxSupplyAmount = bound(amounts.usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT_USDX);
    amounts.wbtcSupplyAmount = bound(amounts.wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT_WBTC);
    amounts.daiBorrowAmount = bound(amounts.daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT_DAI / 2);
    amounts.wethBorrowAmount = bound(amounts.wethBorrowAmount, 0, MAX_SUPPLY_AMOUNT_WETH / 2);
    amounts.usdxBorrowAmount = bound(amounts.usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT_USDX / 2);
    amounts.wbtcBorrowAmount = bound(amounts.wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT_WBTC / 2);

    return amounts;
  }

  function _parseTestInputs(TestInputs memory amounts) internal view returns (TestAmount[] memory) {
    TestAmount[] memory testAmounts = new TestAmount[](4);

    testAmounts[0] = TestAmount({
      supplyAmount: amounts.daiSupplyAmount,
      borrowAmount: amounts.daiBorrowAmount,
      originalSupplyAmount: amounts.daiSupplyAmount,
      originalBorrowAmount: amounts.daiBorrowAmount,
      index: hub1.getAssetDrawnIndex(daiAssetId),
      originalIndex: hub1.getAssetDrawnIndex(daiAssetId),
      reserveId: _daiReserveId(spoke2),
      assetId: daiAssetId,
      name: 'DAI'
    });

    testAmounts[1] = TestAmount({
      supplyAmount: amounts.wethSupplyAmount,
      borrowAmount: amounts.wethBorrowAmount,
      originalSupplyAmount: amounts.wethSupplyAmount,
      originalBorrowAmount: amounts.wethBorrowAmount,
      index: hub1.getAssetDrawnIndex(wethAssetId),
      originalIndex: hub1.getAssetDrawnIndex(wethAssetId),
      reserveId: _wethReserveId(spoke2),
      assetId: wethAssetId,
      name: 'WETH'
    });

    testAmounts[2] = TestAmount({
      supplyAmount: amounts.usdxSupplyAmount,
      borrowAmount: amounts.usdxBorrowAmount,
      originalSupplyAmount: amounts.usdxSupplyAmount,
      originalBorrowAmount: amounts.usdxBorrowAmount,
      index: hub1.getAssetDrawnIndex(usdxAssetId),
      originalIndex: hub1.getAssetDrawnIndex(usdxAssetId),
      reserveId: _usdxReserveId(spoke2),
      assetId: usdxAssetId,
      name: 'USDX'
    });

    testAmounts[3] = TestAmount({
      supplyAmount: amounts.wbtcSupplyAmount,
      borrowAmount: amounts.wbtcBorrowAmount,
      originalSupplyAmount: amounts.wbtcSupplyAmount,
      originalBorrowAmount: amounts.wbtcBorrowAmount,
      index: hub1.getAssetDrawnIndex(wbtcAssetId),
      originalIndex: hub1.getAssetDrawnIndex(wbtcAssetId),
      reserveId: _wbtcReserveId(spoke2),
      assetId: wbtcAssetId,
      name: 'WBTC'
    });

    return testAmounts;
  }

  function _ensureSufficientCollateral(
    ISpoke spoke,
    TestInputs memory amounts
  ) internal view returns (TestInputs memory) {
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

  function _assertProtocolSupplyAndDebt(
    uint256 reserveId,
    string memory reserveName,
    uint256 expectedUserSupply,
    uint256 expectedReserveSupply,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    _assertUserSupply(
      spoke2,
      reserveId,
      bob,
      expectedUserSupply,
      string.concat(reserveName, label)
    );
    _assertReserveSupply(
      spoke2,
      reserveId,
      expectedReserveSupply,
      string.concat(reserveName, label)
    );
    _assertSpokeSupply(spoke2, reserveId, expectedReserveSupply, string.concat(reserveName, label));
    _assertAssetSupply(spoke2, reserveId, expectedReserveSupply, string.concat(reserveName, label));
    _assertSingleUserProtocolDebt(
      spoke2,
      reserveId,
      bob,
      expectedDrawnDebt,
      expectedPremiumDebt,
      string.concat(reserveName, label)
    );
  }
}
