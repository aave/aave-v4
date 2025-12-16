// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueInterestScenarioTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for *;
  using PercentageMath for uint256;
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
    uint40 startTime;
    uint256 wethIndex;
    uint256 usdxIndex;
    uint256 wbtcIndex;
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

  struct TestInfo {
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

  /// Second accrual after an action - which should update the user rp
  function test_accrueInterest_fuzz_RPBorrowAndSkipTime_twoActions(
    TestAmounts memory amounts,
    uint40 skipTime
  ) public {
    amounts = _bound(amounts);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME / 2).toUint40();

    // Ensure bob does not draw more than half his normalized supply value
    amounts = _ensureSufficientCollateral(spoke2, amounts);

    // 1 -> DAI, 2 -> WETH, 3 -> USDx, 4 -> WBTC
    TestAmount[] memory testAmounts = new TestAmount[](4);
    for (uint256 i = 0; i < 4; ++i) {
      if (i == 0) {
        testAmounts[i] = TestAmount({
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
      } else if (i == 1) {
        testAmounts[i] = TestAmount({
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
      } else if (i == 2) {
        testAmounts[i] = TestAmount({
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
      } else {
        testAmounts[i] = TestAmount({
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
      }
    }

    uint40 startTime = vm.getBlockTimestamp().toUint40();

    // Bob supplies amounts on spoke 2, then we deploy remainder of liquidity
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
    TestInfo[] memory values = new TestInfo[](4);
    for (uint256 i = 0; i < 4; ++i) {
      values[i].baseBorrowRate = hub1.getAssetDrawnRate(testAmounts[i].assetId).toUint96();
    }

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    uint256 drawnDebt;
    for (uint256 i = 0; i < 4; ++i) {
      drawnDebt = _calculateExpectedDrawnDebt(
        testAmounts[i].borrowAmount,
        values[i].baseBorrowRate,
        startTime
      );
      _assertSingleUserProtocolDebt(
        spoke2,
        testAmounts[i].reserveId,
        bob,
        drawnDebt,
        0,
        string.concat(testAmounts[i].name, ' before accrual')
      );
      _assertUserSupply(
        spoke2,
        testAmounts[i].reserveId,
        bob,
        testAmounts[i].supplyAmount,
        string.concat(testAmounts[i].name, ' before accrual')
      );
      _assertReserveSupply(
        spoke2,
        testAmounts[i].reserveId,
        MAX_SUPPLY_AMOUNT,
        string.concat(testAmounts[i].name, ' before accrual')
      );
      _assertSpokeSupply(
        spoke2,
        testAmounts[i].reserveId,
        MAX_SUPPLY_AMOUNT,
        string.concat(testAmounts[i].name, ' before accrual')
      );
      _assertAssetSupply(
        spoke2,
        testAmounts[i].reserveId,
        MAX_SUPPLY_AMOUNT,
        string.concat(testAmounts[i].name, ' before accrual')
      );
    }

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    ISpoke.UserPosition memory bobPosition;
    uint256 expectedPremiumDebt;
    uint256 interest;
    for (uint256 i = 0; i < 4; ++i) {
      bobPosition = spoke2.getUserPosition(testAmounts[i].reserveId, bob);
      drawnDebt = _calculateExpectedDrawnDebt(
        testAmounts[i].borrowAmount,
        values[i].baseBorrowRate,
        startTime
      );
      expectedPremiumDebt = _calculateExpectedPremiumDebt(
        testAmounts[i].borrowAmount,
        drawnDebt,
        bobRp
      );
      interest =
        (drawnDebt + expectedPremiumDebt) -
        testAmounts[i].borrowAmount -
        _calculateBurntInterest(hub1, testAmounts[i].assetId);
      _assertSingleUserProtocolDebt(
        spoke2,
        testAmounts[i].reserveId,
        bob,
        drawnDebt,
        expectedPremiumDebt,
        string.concat(testAmounts[i].name, ' after accrual')
      );
      _assertUserSupply(
        spoke2,
        testAmounts[i].reserveId,
        bob,
        testAmounts[i].supplyAmount + (interest * testAmounts[i].supplyAmount) / MAX_SUPPLY_AMOUNT,
        string.concat(testAmounts[i].name, ' after accrual')
      );
      _assertReserveSupply(
        spoke2,
        testAmounts[i].reserveId,
        MAX_SUPPLY_AMOUNT + interest,
        string.concat(testAmounts[i].name, ' after accrual')
      );
      _assertSpokeSupply(
        spoke2,
        testAmounts[i].reserveId,
        MAX_SUPPLY_AMOUNT + interest,
        string.concat(testAmounts[i].name, ' after accrual')
      );
      _assertAssetSupply(
        spoke2,
        testAmounts[i].reserveId,
        MAX_SUPPLY_AMOUNT + interest,
        string.concat(testAmounts[i].name, ' after accrual')
      );
    }

    // Only proceed with test if position is healthy
    if (_getUserHealthFactor(spoke2, bob) >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      // Supply more collateral to ensure bob can borrow more dai to trigger accrual
      deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT);
      Utils.supplyCollateral(spoke2, _usdzReserveId(spoke2), bob, MAX_SUPPLY_AMOUNT, bob);

      // Handle case that bob isn't already borrowing dai by borrowing 1 share
      bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
      if (bobPosition.drawnShares == 0) {
        Utils.borrow(
          spoke2,
          _daiReserveId(spoke2),
          bob,
          hub1.previewRestoreByShares(daiAssetId, 1),
          bob
        );
      }

      // Bob borrows more dai to trigger accrual
      Utils.borrow(spoke2, _daiReserveId(spoke2), bob, 1e18, bob);

      bobRp = _calculateExpectedUserRP(spoke2, bob);

      // Update amounts for second accrual checks
      for (uint256 i = 0; i < 4; ++i) {
        (testAmounts[i].borrowAmount, ) = spoke2.getUserDebt(testAmounts[i].reserveId, bob);
        values[i].baseBorrowRate = hub1.getAssetDrawnRate(testAmounts[i].assetId).toUint96();
        values[i].index = hub1.getAssetDrawnIndex(testAmounts[i].assetId).toUint120();
        values[i].timestamp = hub1.getAsset(testAmounts[i].assetId).lastUpdateTimestamp;
      }

      // Check debt values before accrual
      for (uint256 i = 0; i < 4; ++i) {
        bobPosition = spoke2.getUserPosition(testAmounts[i].reserveId, bob);
        expectedPremiumDebt = _calculatePremiumDebt(
          hub1,
          testAmounts[i].assetId,
          bobPosition.premiumShares,
          bobPosition.premiumOffsetRay
        );
        _assertSingleUserProtocolDebt(
          spoke2,
          testAmounts[i].reserveId,
          bob,
          testAmounts[i].borrowAmount,
          expectedPremiumDebt,
          string.concat(testAmounts[i].name, ' before second accrual')
        );
        values[i].baseShares = bobPosition.drawnShares;
      }

      // Store timestamp before next skip time
      startTime = vm.getBlockTimestamp().toUint40();
      skipTime = randomizer(0, MAX_SKIP_TIME / 2).toUint40();
      skip(skipTime);

      // Account for the dai we just borrowed
      testAmounts[0].originalBorrowAmount += 1e18;

      // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
      for (uint256 i = 0; i < 4; ++i) {
        if (testAmounts[i].originalBorrowAmount == 0) {
          continue;
        }
        values[i].index = _calculateExpectedDrawnIndex(
          values[i].timestamp == 1 ? testAmounts[i].originalIndex : values[i].index, // If reserve never updated, use original index
          values[i].baseBorrowRate,
          values[i].timestamp
        );
        bobPosition = spoke2.getUserPosition(testAmounts[i].reserveId, bob);
        drawnDebt = values[i].baseShares.rayMulUp(values[i].index);
        expectedPremiumDebt = _calculatePremiumDebt(
          hub1,
          testAmounts[i].assetId,
          bobPosition.premiumShares,
          bobPosition.premiumOffsetRay
        );
        interest =
          (drawnDebt + expectedPremiumDebt) -
          testAmounts[i].originalBorrowAmount -
          _calculateBurntInterest(hub1, testAmounts[i].assetId);
        _assertSingleUserProtocolDebt(
          spoke2,
          testAmounts[i].reserveId,
          bob,
          drawnDebt,
          expectedPremiumDebt,
          string.concat(testAmounts[i].name, ' after second accrual')
        );
        _assertUserSupply(
          spoke2,
          testAmounts[i].reserveId,
          bob,
          testAmounts[i].originalSupplyAmount +
            (interest * testAmounts[i].originalSupplyAmount) /
            MAX_SUPPLY_AMOUNT,
          string.concat(testAmounts[i].name, ' after second accrual')
        );
        _assertReserveSupply(
          spoke2,
          testAmounts[i].reserveId,
          MAX_SUPPLY_AMOUNT + interest,
          string.concat(testAmounts[i].name, ' after second accrual')
        );
        _assertSpokeSupply(
          spoke2,
          testAmounts[i].reserveId,
          MAX_SUPPLY_AMOUNT + interest,
          string.concat(testAmounts[i].name, ' after second accrual')
        );
        _assertAssetSupply(
          spoke2,
          testAmounts[i].reserveId,
          MAX_SUPPLY_AMOUNT + interest,
          string.concat(testAmounts[i].name, ' after second accrual')
        );
      }
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
