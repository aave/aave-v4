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
  }

  struct Rates {
    uint96 daiBaseBorrowRate;
    uint96 wethBaseBorrowRate;
    uint96 usdxBaseBorrowRate;
    uint96 wbtcBaseBorrowRate;
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
    vm.skip(true, 'pending rft');
    amounts = _bound(amounts);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME / 2).toUint40();

    // Ensure bob does not draw more than half his normalized supply value
    amounts = _ensureSufficientCollateral(spoke2, amounts);
    TestAmounts memory originalAmounts = _copyAmounts(amounts); // deep copy original amounts

    uint40 startTime = vm.getBlockTimestamp().toUint40();

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
      _openSupplyPosition(
        spoke2,
        _daiReserveId(spoke2),
        MAX_SUPPLY_AMOUNT - amounts.daiSupplyAmount
      );
    }
    if (amounts.wethSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke2,
        _wethReserveId(spoke2),
        MAX_SUPPLY_AMOUNT - amounts.wethSupplyAmount
      );
    }
    if (amounts.usdxSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
        spoke2,
        _usdxReserveId(spoke2),
        MAX_SUPPLY_AMOUNT - amounts.usdxSupplyAmount
      );
    }
    if (amounts.wbtcSupplyAmount < MAX_SUPPLY_AMOUNT) {
      _openSupplyPosition(
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
    uint256 bobRp = _getUserRiskPremium(spoke2, bob);
    assertEq(bobRp, _calculateExpectedUserRP(spoke2, bob), 'user risk premium Before');

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
      spoke2,
      _daiReserveId(spoke2),
      bob,
      drawnDebt,
      0,
      'dai before accrual'
    );
    _assertUserSupply(
      spoke2,
      _daiReserveId(spoke2),
      bob,
      amounts.daiSupplyAmount,
      'dai before accrual'
    );
    _assertReserveSupply(spoke2, _daiReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'dai before accrual');
    _assertSpokeSupply(spoke2, _daiReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'dai before accrual');
    _assertAssetSupply(spoke2, _daiReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'dai before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wethBorrowAmount,
      rates.wethBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke2,
      _wethReserveId(spoke2),
      bob,
      drawnDebt,
      0,
      'weth before accrual'
    );
    _assertUserSupply(
      spoke2,
      _wethReserveId(spoke2),
      bob,
      amounts.wethSupplyAmount,
      'weth before accrual'
    );
    _assertReserveSupply(spoke2, _wethReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'weth before accrual');
    _assertSpokeSupply(spoke2, _wethReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'weth before accrual');
    _assertAssetSupply(spoke2, _wethReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'weth before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.usdxBorrowAmount,
      rates.usdxBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke2,
      _usdxReserveId(spoke2),
      bob,
      drawnDebt,
      0,
      'usdx before accrual'
    );
    _assertUserSupply(
      spoke2,
      _usdxReserveId(spoke2),
      bob,
      amounts.usdxSupplyAmount,
      'usdx before accrual'
    );
    _assertReserveSupply(spoke2, _usdxReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'usdx before accrual');
    _assertSpokeSupply(spoke2, _usdxReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'usdx before accrual');
    _assertAssetSupply(spoke2, _usdxReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'usdx before accrual');

    drawnDebt = _calculateExpectedDrawnDebt(
      amounts.wbtcBorrowAmount,
      rates.wbtcBaseBorrowRate,
      startTime
    );
    _assertSingleUserProtocolDebt(
      spoke2,
      _wbtcReserveId(spoke2),
      bob,
      drawnDebt,
      0,
      'wbtc before accrual'
    );
    _assertUserSupply(
      spoke2,
      _wbtcReserveId(spoke2),
      bob,
      amounts.wbtcSupplyAmount,
      'wbtc before accrual'
    );
    _assertReserveSupply(spoke2, _wbtcReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');
    _assertSpokeSupply(spoke2, _wbtcReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');
    _assertAssetSupply(spoke2, _wbtcReserveId(spoke2), MAX_SUPPLY_AMOUNT, 'wbtc before accrual');

    // Skip time to accrue interest
    skip(skipTime);

    // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
    ISpoke.UserPosition memory bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
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
      spoke2,
      _daiReserveId(spoke2),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'dai after accrual'
    );
    _assertUserSupply(
      spoke2,
      _daiReserveId(spoke2),
      bob,
      amounts.daiSupplyAmount + (interest * amounts.daiSupplyAmount) / MAX_SUPPLY_AMOUNT,
      'dai after accrual'
    );
    _assertReserveSupply(
      spoke2,
      _daiReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );
    _assertSpokeSupply(
      spoke2,
      _daiReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );
    _assertAssetSupply(
      spoke2,
      _daiReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'dai after accrual'
    );

    bobPosition = spoke2.getUserPosition(_wethReserveId(spoke2), bob);
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
      spoke2,
      _wethReserveId(spoke2),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'weth after accrual'
    );
    _assertUserSupply(
      spoke2,
      _wethReserveId(spoke2),
      bob,
      amounts.wethSupplyAmount + (interest * amounts.wethSupplyAmount) / MAX_SUPPLY_AMOUNT,
      'weth after accrual'
    );
    _assertReserveSupply(
      spoke2,
      _wethReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );
    _assertSpokeSupply(
      spoke2,
      _wethReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );
    _assertAssetSupply(
      spoke2,
      _wethReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'weth after accrual'
    );

    bobPosition = spoke2.getUserPosition(_usdxReserveId(spoke2), bob);
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
      spoke2,
      _usdxReserveId(spoke2),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'usdx after accrual'
    );
    _assertUserSupply(
      spoke2,
      _usdxReserveId(spoke2),
      bob,
      amounts.usdxSupplyAmount + (interest * amounts.usdxSupplyAmount) / MAX_SUPPLY_AMOUNT,
      'usdx after accrual'
    );
    _assertReserveSupply(
      spoke2,
      _usdxReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );
    _assertSpokeSupply(
      spoke2,
      _usdxReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );
    _assertAssetSupply(
      spoke2,
      _usdxReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'usdx after accrual'
    );

    bobPosition = spoke2.getUserPosition(_wbtcReserveId(spoke2), bob);
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
      spoke2,
      _wbtcReserveId(spoke2),
      bob,
      drawnDebt,
      expectedPremiumDebt,
      'wbtc after accrual'
    );
    _assertUserSupply(
      spoke2,
      _wbtcReserveId(spoke2),
      bob,
      amounts.wbtcSupplyAmount + (interest * amounts.wbtcSupplyAmount) / MAX_SUPPLY_AMOUNT,
      'wbtc after accrual'
    );
    _assertReserveSupply(
      spoke2,
      _wbtcReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );
    _assertSpokeSupply(
      spoke2,
      _wbtcReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );
    _assertAssetSupply(
      spoke2,
      _wbtcReserveId(spoke2),
      MAX_SUPPLY_AMOUNT + interest,
      'wbtc after accrual'
    );

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
      // Workaround for precision loss with RP calc: https://github.com/aave/aave-v4/issues/421
      // Construct mock call so we can see the same user rp calc as within the borrow function
      vm.mockCall(
        address(spoke2),
        abi.encodeCall(Spoke.getUserTotalDebt, (_daiReserveId(spoke2), bob)),
        abi.encode(spoke2.getUserTotalDebt(_daiReserveId(spoke2), bob) + 1e18) // Debt amount seen in the borrow function when calculating user rp
      );
      bobRp = _calculateExpectedUserRP(spoke2, bob);
      vm.clearMockedCalls();

      // Bob borrows more dai to trigger accrual
      Utils.borrow(spoke2, _daiReserveId(spoke2), bob, 1e18, bob);

      // Refresh debt values
      (amounts.daiBorrowAmount, ) = spoke2.getUserDebt(_daiReserveId(spoke2), bob);
      (amounts.wethBorrowAmount, ) = spoke2.getUserDebt(_wethReserveId(spoke2), bob);
      (amounts.usdxBorrowAmount, ) = spoke2.getUserDebt(_usdxReserveId(spoke2), bob);
      (amounts.wbtcBorrowAmount, ) = spoke2.getUserDebt(_wbtcReserveId(spoke2), bob);

      // Refresh base borrow rates
      rates.daiBaseBorrowRate = hub1.getAssetDrawnRate(daiAssetId).toUint96();
      rates.wethBaseBorrowRate = hub1.getAssetDrawnRate(wethAssetId).toUint96();
      rates.usdxBaseBorrowRate = hub1.getAssetDrawnRate(usdxAssetId).toUint96();
      rates.wbtcBaseBorrowRate = hub1.getAssetDrawnRate(wbtcAssetId).toUint96();

      BaseShares memory baseShares;

      // Check debt values before accrual
      bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
      expectedPremiumDebt = _calculatePremiumDebtRay(spoke2, _daiReserveId(spoke2), bob);
      _assertSingleUserProtocolDebt(
        spoke2,
        _daiReserveId(spoke2),
        bob,
        amounts.daiBorrowAmount,
        expectedPremiumDebt,
        'dai before second accrual'
      );
      baseShares.dai = bobPosition.drawnShares;

      bobPosition = spoke2.getUserPosition(_wethReserveId(spoke2), bob);
      expectedPremiumDebt = _calculatePremiumDebtRay(spoke2, _wethReserveId(spoke2), bob);
      _assertSingleUserProtocolDebt(
        spoke2,
        _wethReserveId(spoke2),
        bob,
        amounts.wethBorrowAmount,
        expectedPremiumDebt,
        'weth before second accrual'
      );
      baseShares.weth = bobPosition.drawnShares;

      bobPosition = spoke2.getUserPosition(_usdxReserveId(spoke2), bob);
      expectedPremiumDebt = _calculatePremiumDebtRay(spoke2, _usdxReserveId(spoke2), bob);
      _assertSingleUserProtocolDebt(
        spoke2,
        _usdxReserveId(spoke2),
        bob,
        amounts.usdxBorrowAmount,
        expectedPremiumDebt,
        'usdx before second accrual'
      );
      baseShares.usdx = bobPosition.drawnShares;

      bobPosition = spoke2.getUserPosition(_wbtcReserveId(spoke2), bob);
      expectedPremiumDebt = _calculatePremiumDebtRay(spoke2, _wbtcReserveId(spoke2), bob);
      _assertSingleUserProtocolDebt(
        spoke2,
        _wbtcReserveId(spoke2),
        bob,
        amounts.wbtcBorrowAmount,
        expectedPremiumDebt,
        'wbtc before second accrual'
      );
      baseShares.wbtc = bobPosition.drawnShares;

      // Store index before accrual, and use this for calculating expected drawn debt
      Indices memory indices;
      indices.daiIndex = hub1.getAssetDrawnIndex(daiAssetId);
      indices.wethIndex = hub1.getAssetDrawnIndex(wethAssetId);
      indices.usdxIndex = hub1.getAssetDrawnIndex(usdxAssetId);
      indices.wbtcIndex = hub1.getAssetDrawnIndex(wbtcAssetId);

      // Store timestamp before next skip time
      startTime = vm.getBlockTimestamp().toUint40();
      skipTime = randomizer(0, MAX_SKIP_TIME / 2).toUint40();
      skip(skipTime);

      // Check bob's drawn debt, premium debt, and supplied amounts for all assets at user, reserve, spoke, and asset level
      indices.daiIndex = _calculateExpectedDrawnIndex(
        indices.daiIndex,
        rates.daiBaseBorrowRate,
        startTime
      );
      bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
      drawnDebt = baseShares.dai.rayMulUp(indices.daiIndex);
      expectedPremiumDebt = _calculateExpectedPremiumDebt(
        amounts.daiBorrowAmount,
        drawnDebt,
        bobRp
      );
      interest =
        (drawnDebt + expectedPremiumDebt) -
        (originalAmounts.daiBorrowAmount + 1e18) -
        _calculateBurntInterest(hub1, daiAssetId); // subtract out the extra amount we borrowed
      _assertSingleUserProtocolDebt(
        spoke2,
        _daiReserveId(spoke2),
        bob,
        drawnDebt,
        expectedPremiumDebt,
        'dai after second accrual'
      );
      _assertUserSupply(
        spoke2,
        _daiReserveId(spoke2),
        bob,
        originalAmounts.daiSupplyAmount +
          (interest * originalAmounts.daiSupplyAmount) /
          MAX_SUPPLY_AMOUNT,
        'dai after second accrual'
      );
      _assertReserveSupply(
        spoke2,
        _daiReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'dai after second accrual'
      );
      _assertSpokeSupply(
        spoke2,
        _daiReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'dai after second accrual'
      );
      _assertAssetSupply(
        spoke2,
        _daiReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'dai after second accrual'
      );

      indices.wethIndex = _calculateExpectedDrawnIndex(
        indices.wethIndex,
        rates.wethBaseBorrowRate,
        startTime
      );
      bobPosition = spoke2.getUserPosition(_wethReserveId(spoke2), bob);
      assertEq(
        bobPosition.drawnShares,
        baseShares.weth,
        'weth base drawn shares after second accrual'
      );
      drawnDebt = baseShares.weth.rayMulUp(indices.wethIndex);
      expectedPremiumDebt = _calculateExpectedPremiumDebt(
        amounts.wethBorrowAmount,
        drawnDebt,
        bobRp
      );
      interest =
        (drawnDebt + expectedPremiumDebt) -
        originalAmounts.wethBorrowAmount -
        _calculateBurntInterest(hub1, wethAssetId);
      _assertSingleUserProtocolDebt(
        spoke2,
        _wethReserveId(spoke2),
        bob,
        drawnDebt,
        expectedPremiumDebt,
        'weth after second accrual'
      );
      _assertUserSupply(
        spoke2,
        _wethReserveId(spoke2),
        bob,
        originalAmounts.wethSupplyAmount +
          (interest * originalAmounts.wethSupplyAmount) /
          MAX_SUPPLY_AMOUNT,
        'weth after second accrual'
      );
      _assertReserveSupply(
        spoke2,
        _wethReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'weth after second accrual'
      );
      _assertSpokeSupply(
        spoke2,
        _wethReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'weth after second accrual'
      );
      _assertAssetSupply(
        spoke2,
        _wethReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'weth after second accrual'
      );

      indices.usdxIndex = _calculateExpectedDrawnIndex(
        indices.usdxIndex,
        rates.usdxBaseBorrowRate,
        startTime
      );
      bobPosition = spoke2.getUserPosition(_usdxReserveId(spoke2), bob);
      drawnDebt = baseShares.usdx.rayMulUp(indices.usdxIndex);
      expectedPremiumDebt = _calculateExpectedPremiumDebt(
        amounts.usdxBorrowAmount,
        drawnDebt,
        bobRp
      );
      interest =
        (drawnDebt + expectedPremiumDebt) -
        originalAmounts.usdxBorrowAmount -
        _calculateBurntInterest(hub1, usdxAssetId);
      _assertSingleUserProtocolDebt(
        spoke2,
        _usdxReserveId(spoke2),
        bob,
        drawnDebt,
        expectedPremiumDebt,
        'usdx after second accrual'
      );
      _assertUserSupply(
        spoke2,
        _usdxReserveId(spoke2),
        bob,
        originalAmounts.usdxSupplyAmount +
          (interest * originalAmounts.usdxSupplyAmount) /
          MAX_SUPPLY_AMOUNT,
        'usdx after second accrual'
      );
      _assertReserveSupply(
        spoke2,
        _usdxReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'usdx after second accrual'
      );
      _assertSpokeSupply(
        spoke2,
        _usdxReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'usdx after second accrual'
      );
      _assertAssetSupply(
        spoke2,
        _usdxReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'usdx after second accrual'
      );

      indices.wbtcIndex = _calculateExpectedDrawnIndex(
        indices.wbtcIndex,
        rates.wbtcBaseBorrowRate,
        startTime
      );
      bobPosition = spoke2.getUserPosition(_wbtcReserveId(spoke2), bob);
      drawnDebt = baseShares.wbtc.rayMulUp(indices.wbtcIndex);
      expectedPremiumDebt = _calculateExpectedPremiumDebt(
        amounts.wbtcBorrowAmount,
        drawnDebt,
        bobRp
      );
      interest =
        (drawnDebt + expectedPremiumDebt) -
        originalAmounts.wbtcBorrowAmount -
        _calculateBurntInterest(hub1, wbtcAssetId);
      _assertSingleUserProtocolDebt(
        spoke2,
        _wbtcReserveId(spoke2),
        bob,
        drawnDebt,
        expectedPremiumDebt,
        'wbtc after second accrual'
      );
      _assertUserSupply(
        spoke2,
        _wbtcReserveId(spoke2),
        bob,
        originalAmounts.wbtcSupplyAmount +
          (interest * originalAmounts.wbtcSupplyAmount) /
          MAX_SUPPLY_AMOUNT,
        'wbtc after second accrual'
      );
      _assertReserveSupply(
        spoke2,
        _wbtcReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'wbtc after second accrual'
      );
      _assertSpokeSupply(
        spoke2,
        _wbtcReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
        'wbtc after second accrual'
      );
      _assertAssetSupply(
        spoke2,
        _wbtcReserveId(spoke2),
        MAX_SUPPLY_AMOUNT + interest,
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

  /// @dev Helper to deep copy TestAmounts struct
  function _copyAmounts(TestAmounts memory amounts) internal pure returns (TestAmounts memory) {
    return
      TestAmounts({
        daiSupplyAmount: amounts.daiSupplyAmount,
        wethSupplyAmount: amounts.wethSupplyAmount,
        usdxSupplyAmount: amounts.usdxSupplyAmount,
        wbtcSupplyAmount: amounts.wbtcSupplyAmount,
        daiBorrowAmount: amounts.daiBorrowAmount,
        wethBorrowAmount: amounts.wethBorrowAmount,
        usdxBorrowAmount: amounts.usdxBorrowAmount,
        wbtcBorrowAmount: amounts.wbtcBorrowAmount
      });
  }
}
