// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.AccrueInterest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';

contract SpokeAccrueInterestScenarioTest is SpokeAccrueInterestTest {
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMath for uint256;

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
}
