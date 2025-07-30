// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawTest is SpokeBase {
  struct TestState {
    uint256 reserveId;
    uint256 collateralReserveId;
    uint256 suppliedCollateralAmount;
    uint256 suppliedCollateralShares;
    uint256 borrowAmount;
    uint256 timestamp;
    uint256 rate;
    uint256 withdrawAmount;
    uint256 withdrawnShares;
    uint256 trivialSupplyShares;
    uint256 supplyAmount;
    uint256 supplyShares;
    uint256 aliceBaseDebt;
    uint256 alicePremiumDebt;
    uint256 borrowReserveSupplyAmount;
  }

  struct TestWithInterestFuzzParams {
    uint256 reserveId;
    uint256 borrowAmount;
    uint256 rate;
    uint256 borrowReserveSupplyAmount;
    uint256 skipTime;
  }

  function test_withdraw_same_block() public {
    uint256 amount = 100e18;

    TestData[2] memory daiData;
    TestUserData[2] memory bobData;
    TokenData[2] memory tokenData;

    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, amount);

    // Bob supplies DAI
    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    uint256 stage = 0;
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));
    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    // Reserve assertions before withdrawal
    assertEq(daiData[stage].suppliedAmount, amount, 'reserve suppliedAmount pre-withdraw');
    assertEq(
      daiData[stage].data.suppliedShares,
      expectedSupplyShares,
      'reserve suppliedShares pre-withdraw'
    );

    // Bob assertions before withdrawal
    assertEq(bobData[stage].suppliedAmount, amount, 'bob suppliedAmount pre-withdraw');
    assertEq(
      bobData[stage].data.suppliedShares,
      expectedSupplyShares,
      'bob suppliedShares pre-withdraw'
    );

    // Token assertions before withdrawal
    assertEq(tokenData[stage].spokeBalance, 0, 'dai spokeBalance pre-withdraw');
    assertEq(tokenData[stage].hubBalance, amount, 'dai hubBalance pre-withdraw');
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - amount,
      'bob dai balance pre-withdraw'
    );

    // Bob withdraws immediately in the same block
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(_daiReserveId(spoke1), bob, bob, amount);
    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), amount, bob);

    stage = 1;
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // Reserve assertions after withdrawal
    assertEq(daiData[stage].suppliedAmount, 0, 'reserve suppliedAmount post-withdraw');
    assertEq(daiData[stage].data.suppliedShares, 0, 'reserve suppliedShares post-withdraw');

    // Bob assertions after withdrawal
    assertEq(bobData[stage].suppliedAmount, 0, 'bob suppliedAmount post-withdraw');
    assertEq(bobData[stage].data.suppliedShares, 0, 'bob suppliedShares post-withdraw');

    // Token assertions after withdrawal
    assertEq(tokenData[stage].spokeBalance, 0, 'dai spokeBalance post-withdraw');
    assertEq(tokenData[stage].hubBalance, 0, 'dai hubBalance post-withdraw');
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT, 'bob dai balance post-withdraw');

    // Check supply rate monotonically increases after withdrawal
    _checkSupplyRateIncreasing(supplyExRate, getSupplyExRate(daiAssetId), true, 'after withdraw');
  }

  function test_withdraw_all_liquidity() public {
    uint256 supplyAmount = 5000e18;
    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _checkSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    // Withdraw all supplied assets
    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), type(uint256).max, bob);

    _checkSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(supplyExRate, getSupplyExRate(daiAssetId), true, 'after withdraw');
  }

  function test_withdraw_fuzz_suppliedAmount(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _checkSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    // Withdraw all supplied assets
    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), type(uint256).max, bob);

    _checkSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(supplyExRate, getSupplyExRate(daiAssetId), true, 'after withdraw');
  }

  function test_withdraw_fuzz_all_with_interest(uint256 supplyAmount, uint256 borrowAmount) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _checkSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Wait a year to accrue interest
    skip(365 days);

    // Ensure interest has accrued
    vm.assume(hub.getAssetSuppliedAmount(daiAssetId) > supplyAmount);

    // Give Bob enough dai to repay
    uint256 repayAmount = spoke1.getReserveTotalDebt(_daiReserveId(spoke1));
    deal(address(tokenList.dai), bob, repayAmount);

    Utils.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: type(uint256).max,
      onBehalfOf: bob
    });

    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    // bob withdraws all
    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), type(uint256).max, bob);

    // treasury spoke withdraw fees
    withdrawLiquidityFees(daiAssetId, type(uint256).max);

    _checkSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(supplyExRate, getSupplyExRate(daiAssetId), true, 'after withdraw');
  }

  function test_withdraw_fuzz_all_elapsed_with_interest(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _checkSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Wait some time to accrue interest
    skip(elapsed);

    // Ensure interest has accrued
    vm.assume(hub.getAssetSuppliedAmount(daiAssetId) > supplyAmount);

    // Give Bob enough dai to repay
    uint256 repayAmount = spoke1.getReserveTotalDebt(_daiReserveId(spoke1));
    deal(address(tokenList.dai), bob, repayAmount);

    Utils.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: type(uint256).max,
      onBehalfOf: bob
    });

    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), type(uint256).max, bob);

    // treasury spoke withdraw fees
    withdrawLiquidityFees(daiAssetId, type(uint256).max);

    _checkSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(supplyExRate, getSupplyExRate(daiAssetId), true, 'after withdraw');
  }

  function test_withdraw_all_liquidity_with_interest_no_premium() public {
    // set weth collateral risk to 0 for no premium contribution
    updateCollateralRisk({spoke: spoke1, reserveId: _wethReserveId(spoke1), newCollateralRisk: 0});

    TestState memory state;
    state.reserveId = _daiReserveId(spoke1);

    (
      ,
      ,
      state.borrowAmount,
      state.supplyShares,
      state.borrowReserveSupplyAmount
    ) = _increaseReserveIndex(spoke1, state.reserveId);

    (state.aliceBaseDebt, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(state.alicePremiumDebt, 0, 'alice has no premium contribution to exchange rate');

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserTotalDebt(state.reserveId, alice);
    Utils.repay(spoke1, state.reserveId, alice, repayAmount, alice);

    // number of test stages
    TestData[3] memory reserveData;
    TestUserData[3] memory aliceData;
    TestUserData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    state.withdrawAmount = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1));

    assertGt(
      spoke1.getUserSuppliedAmount(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );

    stage = 1;
    state.withdrawnShares = hub.previewRemoveByAssets(daiAssetId, state.withdrawAmount);
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));
    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    // withdraw all available liquidity
    // bc debt is fully repaid, bob can withdraw all supplied
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, onBehalfOf: bob});
    // treasury spoke withdraw fees
    withdrawLiquidityFees(daiAssetId, type(uint256).max);

    stage = 2;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // reserve
    (uint256 reserveBaseDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(state.reserveId);
    assertEq(reserveBaseDebt, 0, 'reserveData base debt');
    assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
    assertEq(reserveData[stage].data.suppliedShares, 0, 'reserveData supplied shares');

    // alice
    (uint256 userBaseDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(userBaseDebt, 0, 'aliceData base debt');
    assertEq(userPremiumDebt, 0, 'aliceData premium debt');
    assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');

    // bob
    (userBaseDebt, userPremiumDebt) = spoke1.getUserDebt(state.reserveId, bob);
    assertEq(userBaseDebt, 0, 'bobData base debt');
    assertEq(userPremiumDebt, 0, 'bobData premium debt');
    assertEq(bobData[stage].data.suppliedShares, 0, 'bobData supplied shares');

    // token
    assertEq(tokenData[stage].spokeBalance, 0, 'tokenData spoke balance');
    assertEq(tokenData[stage].hubBalance, 0, 'tokenData hub balance');
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT + state.borrowAmount - repayAmount,
      'alice balance'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );

    // Check supply rate monotonically increasing after withdraw
    _checkSupplyRateIncreasing(supplyExRate, getSupplyExRate(daiAssetId), true, 'after withdraw');
  }

  function test_withdraw_fuzz_all_liquidity_with_interest_no_premium(
    TestWithInterestFuzzParams memory params
  ) public {
    params.reserveId = bound(params.reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    params.borrowReserveSupplyAmount = bound(
      params.borrowReserveSupplyAmount,
      2,
      MAX_SUPPLY_AMOUNT
    );
    params.borrowAmount = bound(params.borrowAmount, 1, params.borrowReserveSupplyAmount / 2);
    params.rate = bound(params.rate, 1, MAX_BORROW_RATE);
    params.skipTime = bound(params.skipTime, 0, MAX_SKIP_TIME);

    _mockInterestRateBps(params.rate);

    // don't borrow the collateral asset
    vm.assume(params.reserveId != _wbtcReserveId(spoke1));

    (uint256 assetId, IERC20 underlying) = getAssetByReserveId(spoke1, params.reserveId);

    // set weth collateral risk to 0 for no premium contribution
    updateCollateralRisk({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1), // use highest-valued asset
      newCollateralRisk: 0
    });

    TestState memory state;
    state.reserveId = params.reserveId;
    state.collateralReserveId = _wbtcReserveId(spoke1);
    state.suppliedCollateralAmount = MAX_SUPPLY_AMOUNT; // ensure enough collateral
    state.borrowReserveSupplyAmount = params.borrowReserveSupplyAmount;
    state.borrowAmount = params.borrowAmount;
    state.rate = params.rate;
    state.timestamp = vm.getBlockTimestamp();

    (, state.supplyShares) = _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: TestReserve({
        reserveId: state.collateralReserveId,
        supplier: alice,
        supplyAmount: state.suppliedCollateralAmount,
        borrower: address(0),
        borrowAmount: 0
      }),
      borrow: TestReserve({
        reserveId: state.reserveId,
        borrowAmount: state.borrowAmount,
        supplyAmount: state.borrowReserveSupplyAmount,
        supplier: bob,
        borrower: alice
      }),
      rate: state.rate,
      isMockRate: true,
      skipTime: params.skipTime
    });

    uint256 repayAmount = spoke1.getUserTotalDebt(state.reserveId, alice);
    // deal because repayAmount may exceed default supplied amount due to interest
    deal(address(underlying), alice, repayAmount);

    vm.assume(repayAmount > state.borrowAmount);
    (, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(state.alicePremiumDebt, 0, 'alice has no premium contribution to exchange rate');

    // alice repays all with interest
    Utils.repay(spoke1, state.reserveId, alice, repayAmount, alice);

    // number of test stages
    TestData[3] memory reserveData;
    TestUserData[3] memory aliceData;
    TestUserData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));
    state.withdrawAmount = hub.getSpokeSuppliedAmount(state.reserveId, address(spoke1));

    // bob's supplied amount has grown due to index increase
    assertGt(
      spoke1.getUserSuppliedAmount(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );

    stage = 1;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));
    state.withdrawnShares = hub.previewRemoveByAssets(assetId, state.withdrawAmount);
    uint256 supplyExRateBefore = getSupplyExRate(assetId);

    // bob withdraws all
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, onBehalfOf: bob});

    // treasury spoke withdraw fees
    withdrawLiquidityFees(assetId, type(uint256).max);

    stage = 2;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));

    // reserve
    (uint256 reserveBaseDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(state.reserveId);
    assertEq(reserveBaseDebt, 0, 'reserveData base debt');
    assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
    assertEq(reserveData[stage].data.suppliedShares, 0, 'reserveData supplied shares');

    // alice
    (uint256 userBaseDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(userBaseDebt, 0, 'aliceData base debt');
    assertEq(userPremiumDebt, 0, 'aliceData premium debt');
    assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');

    // bob
    (userBaseDebt, userPremiumDebt) = spoke1.getUserDebt(state.reserveId, bob);
    assertEq(userBaseDebt, 0, 'bobData base debt');
    assertEq(userPremiumDebt, 0, 'bobData premium debt');
    assertEq(
      bobData[stage].data.suppliedShares,
      state.supplyShares - state.withdrawnShares,
      'bobData supplied shares'
    );

    // token
    assertEq(tokenData[stage].spokeBalance, 0, 'tokenData spoke balance');
    assertEq(tokenData[stage].hubBalance, 0, 'tokenData hub balance');
    assertEq(underlying.balanceOf(alice), 0, 'alice balance');
    assertEq(
      underlying.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );

    // Check supply rate monotonically increasing after withdraw
    uint256 supplyExRateAfter = getSupplyExRate(assetId); // caching to avoid stack too deep
    _checkSupplyRateIncreasing(supplyExRateBefore, supplyExRateAfter, true, 'after withdraw');
  }

  function test_withdraw_all_liquidity_with_interest_with_premium() public {
    TestState memory state;
    state.reserveId = _daiReserveId(spoke1);

    // number of test stages
    TestData[3] memory reserveData;
    TestUserData[3] memory aliceData;
    TestUserData[3] memory bobData;
    TokenData[3] memory tokenData;

    (
      ,
      ,
      state.borrowAmount,
      state.supplyShares,
      state.borrowReserveSupplyAmount
    ) = _increaseReserveIndex(spoke1, state.reserveId);

    (, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);

    assertGt(state.alicePremiumDebt, 0, 'alice has premium contribution to exchange rate');

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserTotalDebt(state.reserveId, alice);
    Utils.repay(spoke1, state.reserveId, alice, repayAmount, alice);

    uint256 stage = 0;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    state.withdrawAmount = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)); // withdraw all liquidity

    assertGt(
      spoke1.getUserSuppliedAmount(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );

    stage = 1;
    state.withdrawnShares = hub.previewRemoveByAssets(daiAssetId, state.withdrawAmount);
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));
    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    // debt is fully repaid, so bob can withdraw all supplied
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, onBehalfOf: bob});
    // treasury spoke withdraw fees
    withdrawLiquidityFees(daiAssetId, type(uint256).max);

    stage = 2;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // reserve
    (uint256 reserveBaseDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(state.reserveId);
    assertEq(reserveBaseDebt, 0, 'reserveData base debt');
    assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
    assertEq(
      reserveData[stage].data.suppliedShares,
      reserveData[1].data.suppliedShares - state.withdrawnShares,
      'reserveData supplied shares'
    );

    // alice
    (uint256 userBaseDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(userBaseDebt, 0, 'aliceData base debt');
    assertEq(userPremiumDebt, 0, 'aliceData premium debt');
    assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');

    // bob
    (userBaseDebt, userPremiumDebt) = spoke1.getUserDebt(state.reserveId, bob);
    assertEq(userBaseDebt, 0, 'bobData base debt');
    assertEq(userPremiumDebt, 0, 'bobData premium debt');
    assertEq(bobData[stage].data.suppliedShares, 0, 'bobData supplied shares');

    // token
    assertEq(tokenData[stage].spokeBalance, 0, 'tokenData spoke balance');
    assertEq(tokenData[stage].hubBalance, 0, 'tokenData hub balance');
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT + state.borrowAmount - repayAmount,
      'alice balance'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );

    // Check supply rate monotonically increasing after withdraw
    _checkSupplyRateIncreasing(supplyExRate, getSupplyExRate(daiAssetId), true, 'after withdraw');
  }

  function test_withdraw_fuzz_all_liquidity_with_interest_with_premium(
    TestWithInterestFuzzParams memory params
  ) public {
    params.reserveId = bound(params.reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    params.borrowReserveSupplyAmount = bound(
      params.borrowReserveSupplyAmount,
      2,
      MAX_SUPPLY_AMOUNT
    );
    params.borrowAmount = bound(params.borrowAmount, 1, params.borrowReserveSupplyAmount / 2);
    params.rate = bound(params.rate, 1, MAX_BORROW_RATE);
    params.skipTime = bound(params.skipTime, 0, MAX_SKIP_TIME);

    _mockInterestRateBps(params.rate);

    vm.assume(params.reserveId != _wbtcReserveId(spoke1)); // wbtc used as collateral

    (uint256 assetId, IERC20 underlying) = getAssetByReserveId(spoke1, params.reserveId);

    TestState memory state;
    state.reserveId = params.reserveId;
    state.collateralReserveId = _wbtcReserveId(spoke1);
    state.suppliedCollateralAmount = MAX_SUPPLY_AMOUNT; // ensure enough collateral
    state.borrowReserveSupplyAmount = params.borrowReserveSupplyAmount;
    state.borrowAmount = params.borrowAmount;
    state.rate = params.rate;
    state.timestamp = vm.getBlockTimestamp();

    (, state.supplyShares) = _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: TestReserve({
        reserveId: state.collateralReserveId,
        supplier: alice,
        supplyAmount: state.suppliedCollateralAmount,
        borrower: address(0),
        borrowAmount: 0
      }),
      borrow: TestReserve({
        reserveId: state.reserveId,
        borrowAmount: state.borrowAmount,
        supplyAmount: state.borrowReserveSupplyAmount,
        supplier: bob,
        borrower: alice
      }),
      rate: state.rate,
      isMockRate: true,
      skipTime: params.skipTime
    });

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserTotalDebt(state.reserveId, alice);
    deal(address(underlying), alice, repayAmount);

    // ensure interest has accrued
    vm.assume(repayAmount > state.borrowAmount);

    Utils.repay(spoke1, state.reserveId, alice, repayAmount, alice);

    // number of test stages
    TestData[3] memory reserveData;
    TestUserData[3] memory aliceData;
    TestUserData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));
    state.withdrawAmount = hub.getSpokeSuppliedAmount(state.reserveId, address(spoke1));

    (, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);

    assertGt(
      spoke1.getUserSuppliedAmount(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );
    assertEq(state.alicePremiumDebt, 0, 'alice has no premium contribution to exchange rate');

    stage = 1;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));
    state.withdrawnShares = hub.previewRemoveByAssets(assetId, state.withdrawAmount);
    uint256 supplyExRateBefore = getSupplyExRate(assetId);

    // bob withdraws all
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, onBehalfOf: bob});

    // treasury spoke withdraw fees
    withdrawLiquidityFees(assetId, type(uint256).max);

    stage = 2;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(underlying, address(spoke1));

    // reserve
    (uint256 reserveBaseDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(state.reserveId);
    assertEq(reserveBaseDebt, 0, 'reserveData base debt');
    assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
    assertEq(reserveData[stage].data.suppliedShares, 0, 'reserveData supplied shares');

    // alice
    (uint256 userBaseDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(userBaseDebt, 0, 'aliceData base debt');
    assertEq(userPremiumDebt, 0, 'aliceData premium debt');
    assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');

    // bob
    (userBaseDebt, userPremiumDebt) = spoke1.getUserDebt(state.reserveId, bob);
    assertEq(userBaseDebt, 0, 'bobData base debt');
    assertEq(userPremiumDebt, 0, 'bobData premium debt');
    assertEq(
      bobData[stage].data.suppliedShares,
      state.supplyShares - state.withdrawnShares,
      'bobData supplied shares'
    );

    // token
    assertEq(tokenData[stage].spokeBalance, 0, 'tokenData spoke balance');
    assertEq(tokenData[stage].hubBalance, 0, 'tokenData hub balance');
    assertEq(underlying.balanceOf(alice), 0, 'alice balance');
    assertEq(
      underlying.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );

    // Check supply rate monotonically increasing after withdraw
    uint256 supplyExRateAfter = getSupplyExRate(assetId); // caching to avoid stack too deep
    _checkSupplyRateIncreasing(supplyExRateBefore, supplyExRateAfter, true, 'after withdraw');
  }

  /// withdraw an asset with existing debt, with no interest accrual the two ex rates
  /// can increase due to rounding, with interest accrual should strictly increase
  function test_fuzz_withdraw_effect_on_ex_rates(uint256 amount, uint256 delay) public {
    delay = bound(delay, 1, MAX_SKIP_TIME);
    amount = bound(amount, 2, MAX_SUPPLY_AMOUNT / 2);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      amount
    );
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, amount, bob);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob); // bob collateral
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amount / 2, bob); // introduce debt
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, amount, alice); // alice supply

    uint256 supplyExchangeRatio = hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT);
    uint256 debtExchangeRatio = hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT);

    Utils.withdraw(spoke1, _daiReserveId(spoke1), alice, amount / 2, alice);

    assertGe(hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGe(hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    skip(delay); // with interest accrual, both ex rates should strictly

    assertGt(hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGt(hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    supplyExchangeRatio = hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT);
    debtExchangeRatio = hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT);

    Utils.withdraw(spoke1, _daiReserveId(spoke1), alice, amount / 2, alice);

    assertGe(hub.convertToSuppliedAssets(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGe(hub.convertToDrawnAssets(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);
  }
}
