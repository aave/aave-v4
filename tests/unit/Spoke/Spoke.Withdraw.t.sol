// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawTest is SpokeBase {
  using WadRayMath for uint256;

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
      user: bob,
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
    emit ISpoke.Withdraw(_daiReserveId(spoke1), bob, amount, bob);
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
      user: bob,
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
      user: bob,
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

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    setUsingAsCollateral(spoke1, bob, _daiReserveId(spoke1), true);

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
      user: bob,
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
      user: bob,
      amount: type(uint256).max
    });

    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), type(uint256).max, bob);

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

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    setUsingAsCollateral(spoke1, bob, _daiReserveId(spoke1), true);

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
      user: bob,
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
      user: bob,
      amount: type(uint256).max
    });

    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), type(uint256).max, bob);

    _checkSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(supplyExRate, getSupplyExRate(daiAssetId), true, 'after withdraw');
  }

  function test_withdraw_all_liquidity_with_interest_no_premium() public {
    // set weth LP to 0 for no premium contribution
    updateLiquidityPremium({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      newLiquidityPremium: 0
    });

    TestState memory state;
    state.reserveId = spokeInfo[spoke1].dai.reserveId;

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
    vm.prank(alice);
    spoke1.repay(state.reserveId, repayAmount);

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

    state.withdrawAmount = hub.getAvailableLiquidity(daiAssetId);

    assertGt(
      spoke1.getUserSuppliedAmount(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );

    stage = 1;
    state.withdrawnShares = hub.convertToSuppliedShares(daiAssetId, state.withdrawAmount);
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));
    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    // withdraw all available liquidity
    // bc debt is fully repaid, bob can withdraw all supplied
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

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
    params.rate = bound(params.rate, 1, MAX_BORROW_RATE).bpsToRay();
    params.skipTime = bound(params.skipTime, 0, MAX_SKIP_TIME);

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(params.rate)
    );

    // don't borrow the collateral asset
    vm.assume(params.reserveId != _wbtcReserveId(spoke1));

    (uint256 assetId, IERC20 asset) = getAssetByReserveId(spoke1, params.reserveId);

    // set weth LP to 0 for no premium contribution
    updateLiquidityPremium({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1), // use highest-valued asset
      newLiquidityPremium: 0
    });

    TestState memory state;
    state.reserveId = params.reserveId;
    state.collateralReserveId = spokeInfo[spoke1].wbtc.reserveId;
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
    deal(address(asset), alice, repayAmount);

    vm.assume(repayAmount > state.borrowAmount);
    (, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(state.alicePremiumDebt, 0, 'alice has no premium contribution to exchange rate');

    // alice repays all with interest
    vm.prank(alice);
    spoke1.repay(state.reserveId, repayAmount);

    // number of test stages
    TestData[3] memory reserveData;
    TestUserData[3] memory aliceData;
    TestUserData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(asset, address(spoke1));
    state.withdrawAmount = hub.getAvailableLiquidity(state.reserveId);

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
    tokenData[stage] = getTokenBalances(asset, address(spoke1));
    state.withdrawnShares = hub.convertToSuppliedShares(assetId, state.withdrawAmount);
    uint256 supplyExRateBefore = getSupplyExRate(assetId);

    // bob withdraws all
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage = 2;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(asset, address(spoke1));

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
    assertEq(asset.balanceOf(alice), 0, 'alice balance');
    assertEq(
      asset.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );

    // Check supply rate monotonically increasing after withdraw
    uint256 supplyExRateAfter = getSupplyExRate(assetId); // caching to avoid stack too deep
    _checkSupplyRateIncreasing(supplyExRateBefore, supplyExRateAfter, true, 'after withdraw');
  }

  function test_withdraw_all_liquidity_with_interest_with_premium() public {
    TestState memory state;
    state.reserveId = spokeInfo[spoke1].dai.reserveId;

    // number of test stages
    TestData[3] memory daiData;
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
    vm.prank(alice);
    spoke1.repay(state.reserveId, repayAmount);

    uint256 stage = 0;
    daiData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    state.withdrawAmount = hub.getAvailableLiquidity(daiAssetId); // withdraw all liquidity

    assertGt(
      spoke1.getUserSuppliedAmount(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );

    stage = 1;
    state.withdrawnShares = hub.convertToSuppliedShares(daiAssetId, state.withdrawAmount);
    daiData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));
    uint256 supplyExRate = getSupplyExRate(daiAssetId);

    // debt is fully repaid, so bob can withdraw all supplied
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage = 2;
    daiData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // reserve
    (uint256 reserveBaseDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(state.reserveId);
    assertEq(reserveBaseDebt, 0, 'reserveData base debt');
    assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
    assertEq(
      daiData[stage].data.suppliedShares,
      daiData[1].data.suppliedShares - state.withdrawnShares,
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
    params.rate = bound(params.rate, 1, MAX_BORROW_RATE).bpsToRay();
    params.skipTime = bound(params.skipTime, 0, MAX_SKIP_TIME);

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(params.rate)
    );

    vm.assume(params.reserveId != _wbtcReserveId(spoke1)); // wbtc used as collateral

    (uint256 assetId, IERC20 asset) = getAssetByReserveId(spoke1, params.reserveId);

    TestState memory state;
    state.reserveId = params.reserveId;
    state.collateralReserveId = spokeInfo[spoke1].wbtc.reserveId;
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
    deal(address(asset), alice, repayAmount);

    // ensure interest has accrued
    vm.assume(repayAmount > state.borrowAmount);

    vm.prank(alice);
    spoke1.repay(state.reserveId, repayAmount);

    // number of test stages
    TestData[3] memory reserveData;
    TestUserData[3] memory aliceData;
    TestUserData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(asset, address(spoke1));

    state.withdrawAmount = hub.getAvailableLiquidity(state.reserveId);

    (, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);

    assertGt(
      spoke1.getUserSuppliedAmount(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );
    assertEq(state.alicePremiumDebt, 0, 'alice has no premium contribution to exchange rate');

    //     stage = 1;
    //     reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    //     aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    //     bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    //     tokenData[stage] = getTokenBalances(asset, address(spoke1));
    //     state.withdrawnShares = hub.convertToShares(assetId, state.withdrawAmount);

    //     vm.prank(bob);
    //     spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    //     stage = 2;
    //     reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    //     aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    //     bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    //     tokenData[stage] = getTokenBalances(asset, address(spoke1));

    //     // reserve
    //     assertEq(reserveData[stage].data.baseDebt, 0, 'reserveData base debt');
    //     assertEq(reserveData[stage].data.outstandingPremium, 0, 'reserveData outstanding premium');
    //     assertEq(reserveData[stage].data.suppliedShares, 0, 'reserveData supplied shares');
    //     assertEq(
    //       reserveData[stage].data.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'reserveData last update timestamp'
    //     );

    //     // alice
    //     assertEq(aliceData[stage].data.baseDebt, 0, 'aliceData base debt');
    //     assertEq(aliceData[stage].data.outstandingPremium, 0, 'aliceData outstanding premium');
    //     assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');
    //     assertEq(
    //       aliceData[stage].data.lastUpdateTimestamp,
    //       aliceData[0].data.lastUpdateTimestamp,
    //       'aliceData last update timestamp'
    //     );

    //     // bob
    //     assertEq(bobData[stage].data.baseDebt, 0, 'bobData base debt');
    //     assertEq(bobData[stage].data.outstandingPremium, 0, 'bobData outstanding premium');
    //     assertEq(
    //       bobData[stage].data.suppliedShares,
    //       state.supplyShares - state.withdrawnShares,
    //       'bobData supplied shares'
    //     );
    //     assertEq(
    //       bobData[stage].data.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'bobData last update timestamp'
    //     );

    //     // token
    //     assertEq(tokenData[stage].spokeBalance, 0, 'tokenData spoke balance');
    //     assertEq(tokenData[stage].hubBalance, 0, 'tokenData hub balance');
    //     assertEq(asset.balanceOf(alice), 0, 'alice balance');
    //     assertEq(
    //       asset.balanceOf(bob),
    //       MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
    //       'bob balance'
    //     );
  }

  /// @dev cannot withdraw an amount if resulting withdrawal would result in HF < threshold
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_singleBorrow() public {
    vm.skip(true, 'pending refactor');

    //     uint256 collAmount = 1e18; // $2k in weth
    //     uint256 collReserveId = _wethReserveId(spoke1);
    //     uint256 debtReserveId = _daiReserveId(spoke1);

    //     uint256 maxDebtAmount = _calcMaxDebtAmount({
    //       spoke: spoke1,
    //       collReserveId: collReserveId,
    //       debtReserveId: debtReserveId,
    //       collAmount: collAmount
    //     });

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: collReserveId,
    //       user: alice,
    //       amount: collAmount,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, collReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: bob,
    //       amount: maxDebtAmount,
    //       onBehalfOf: bob
    //     });

    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: alice,
    //       amount: maxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     assertEq(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any amount will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: collReserveId, amount: 1, to: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if resulting withdrawal would result in HF < threshold
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_singleBorrow(
    uint256 debtAmount
  ) public {
    vm.skip(true, 'pending refactor');

    //     debtAmount = bound(debtAmount, 1, MAX_SUPPLY_AMOUNT); // to stay within uint256 bounds for _calcMaxDebtAmount
    //     uint256 collReserveId = _wethReserveId(spoke1);
    //     uint256 debtReserveId = _daiReserveId(spoke1);

    //     uint256 collAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: collReserveId,
    //       debtReserveId: debtReserveId,
    //       debtAmount: debtAmount
    //     });

    //     vm.assume(collAmount < MAX_SUPPLY_AMOUNT && collAmount > 1);

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: collReserveId,
    //       user: alice,
    //       amount: collAmount,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, collReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: bob,
    //       amount: debtAmount,
    //       onBehalfOf: bob
    //     });

    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: alice,
    //       amount: debtAmount,
    //       onBehalfOf: alice
    //     });

    //     assertGe(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing coll will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: collReserveId, amount: collAmount, to: alice}); // todo: resolve precision, should be 1?
  }

  /// @dev cannot withdraw an amount if HF < threshold due to price drop
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_price_drop() public {
    vm.skip(true, 'pending refactor');

    //     uint256 collAmount = 1e18;
    //     uint256 collReserveId = _wethReserveId(spoke1);
    //     uint256 debtReserveId = _daiReserveId(spoke1);

    //     uint256 maxDebtAmount = _calcMaxDebtAmount({
    //       spoke: spoke1,
    //       collReserveId: collReserveId,
    //       debtReserveId: debtReserveId,
    //       collAmount: collAmount
    //     });

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: collReserveId,
    //       user: alice,
    //       amount: collAmount,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, collReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: bob,
    //       amount: maxDebtAmount,
    //       onBehalfOf: bob
    //     });

    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: alice,
    //       amount: maxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // alice is above HF threshold right after borrowing
    //     assertGe(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // collateral price drop by half so that alice is undercollateralized
    //     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
    //     oracle.setAssetPrice(wethAssetId, newPrice);
    //     assertLt(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any amount will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: collReserveId, amount: 1, to: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if resulting withdrawal would result in HF < threshold
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_price_drop(
    uint256 collAmount,
    uint256 newPrice
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 currPrice = oracle.getAssetPrice(wethAssetId);
    //     newPrice = bound(newPrice, 0, currPrice - 1);
    //     collAmount = bound(collAmount, 1, MAX_SUPPLY_AMOUNT / 2); // to stay within uint256 bounds for _calcMaxDebtAmount
    //     uint256 collReserveId = _wethReserveId(spoke1);
    //     uint256 debtReserveId = _daiReserveId(spoke1);

    //     uint256 maxDebtAmount = _calcMaxDebtAmount({
    //       spoke: spoke1,
    //       collReserveId: collReserveId,
    //       debtReserveId: debtReserveId,
    //       collAmount: collAmount
    //     });

    //     vm.assume(maxDebtAmount < MAX_SUPPLY_AMOUNT && maxDebtAmount > 1);

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: collReserveId,
    //       user: alice,
    //       amount: collAmount,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, collReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: bob,
    //       amount: maxDebtAmount,
    //       onBehalfOf: bob
    //     });

    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: alice,
    //       amount: maxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // alice is above HF threshold right after borrowing
    //     assertGe(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // collateral price drop so that alice is undercollateralized
    //     oracle.setAssetPrice(wethAssetId, newPrice);
    //     vm.assume(spoke1.getHealthFactor(alice) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any amount will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: collReserveId, amount: 1, to: alice});
  }

  /// @dev cannot withdraw an amount if HF < threshold due to interest
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_interest_increase() public {
    vm.skip(true, 'pending refactor');

    //     uint256 collAmount = 50e18;
    //     uint256 collReserveId = _wethReserveId(spoke1);
    //     uint256 debtReserveId = _daiReserveId(spoke1);

    //     uint256 maxDebtAmount = _calcMaxDebtAmount({
    //       spoke: spoke1,
    //       collReserveId: collReserveId,
    //       debtReserveId: debtReserveId,
    //       collAmount: collAmount
    //     });

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: collReserveId,
    //       user: alice,
    //       amount: collAmount,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, collReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: bob,
    //       amount: maxDebtAmount,
    //       onBehalfOf: bob
    //     });

    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: alice,
    //       amount: maxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // alice is above HF threshold right after borrowing
    //     assertGe(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // accrue interest so that alice is undercollateralized
    //     skip(365 days);
    //     assertLt(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any amount will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: collReserveId, amount: 1, to: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < threshold due to interest
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_interest_increase(
    uint256 collAmount,
    uint256 skipTime
  ) public {
    vm.skip(true, 'pending refactor');

    //     collAmount = bound(collAmount, 1, MAX_SUPPLY_AMOUNT);
    //     skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    //     uint256 collReserveId = _wethReserveId(spoke1);
    //     uint256 debtReserveId = _daiReserveId(spoke1);

    //     uint256 maxDebtAmount = _calcMaxDebtAmount({
    //       spoke: spoke1,
    //       collReserveId: collReserveId,
    //       debtReserveId: debtReserveId,
    //       collAmount: collAmount
    //     });

    //     vm.assume(maxDebtAmount < MAX_SUPPLY_AMOUNT && maxDebtAmount > 1);

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: collReserveId,
    //       user: alice,
    //       amount: collAmount,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, collReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: bob,
    //       amount: maxDebtAmount,
    //       onBehalfOf: bob
    //     });

    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: debtReserveId,
    //       user: alice,
    //       amount: maxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // alice is above HF threshold right after borrowing
    //     assertGe(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // accrue interest so that alice is undercollateralized
    //     skip(skipTime);
    //     vm.assume(spoke1.getHealthFactor(alice) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any amount will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: collReserveId, amount: 1, to: alice});
  }

  /// @dev cannot withdraw an amount to bring HF < 1, if multiple debts for same coll
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_debts() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiDebtAmount = 1000e18;
    //     uint256 usdxDebtAmount = 2000e6;

    //     // weth collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     // dai/usdx debt
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmountDai = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: daiReserveId,
    //       debtAmount: daiDebtAmount
    //     });

    //     uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmount
    //     });

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: wethReserveId,
    //       user: alice,
    //       amount: wethCollAmountDai + wethCollAmountUsdx,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, wethReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: bob,
    //       amount: daiDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: alice,
    //       amount: daiDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // Bob supplies usdx
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: bob,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows usdx
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: alice,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     assertApproxEqAbs(
    //       spoke1.getHealthFactor(alice),
    //       spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
    //       1
    //     );

    //     // withdrawing any non trivial amount of dai will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 3, to: alice}); // todo: resolve precision. Should be 1
  }

  /// @dev fuzz - cannot withdraw an amount to bring HF < 1, if multiple debts for same coll
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts(
    uint256 daiDebtAmount,
    uint256 usdxDebtAmount
  ) public {
    vm.skip(true, 'pending refactor');

    //     daiDebtAmount = bound(daiDebtAmount, 1, MAX_SUPPLY_AMOUNT);
    //     usdxDebtAmount = bound(usdxDebtAmount, 1, MAX_SUPPLY_AMOUNT);

    //     // weth collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     // dai/usdx debt
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmountDai = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: daiReserveId,
    //       debtAmount: daiDebtAmount
    //     });

    //     uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmount
    //     });

    //     vm.assume(
    //       wethCollAmountDai + wethCollAmountUsdx < MAX_SUPPLY_AMOUNT &&
    //         wethCollAmountDai + wethCollAmountUsdx > 0
    //     );

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: wethReserveId,
    //       user: alice,
    //       amount: wethCollAmountDai + wethCollAmountUsdx,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, wethReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: bob,
    //       amount: daiDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: alice,
    //       amount: daiDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // Bob supplies usdx
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: bob,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows usdx
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: alice,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     assertGe(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any non trivial amount of dai will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({
    //       reserveId: wethReserveId,
    //       amount: wethCollAmountDai + wethCollAmountUsdx,
    //       to: alice
    //     }); // todo: resolve precision. Should be 1
  }

  /// @dev cannot withdraw an amount if HF < 1 due to price drop, if multiple debts for same coll
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_debts_price_drop() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiDebtAmount = 1000e18;
    //     uint256 usdxDebtAmount = 2000e6;

    //     // weth collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     // dai/usdx debt
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmountDai = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: daiReserveId,
    //       debtAmount: daiDebtAmount
    //     });

    //     uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmount
    //     });

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: wethReserveId,
    //       user: alice,
    //       amount: wethCollAmountDai + wethCollAmountUsdx,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, wethReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: bob,
    //       amount: daiDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: alice,
    //       amount: daiDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // Bob supplies usdx
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: bob,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows usdx
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: alice,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     assertApproxEqAbs(
    //       spoke1.getHealthFactor(alice),
    //       spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
    //       1
    //     );

    //     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
    //     oracle.setAssetPrice(wethAssetId, newPrice);

    //     assertLt(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any non trivial amount of dai will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < 1 due to price drop, if multiple debts for same coll
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts_price_drop(
    uint256 daiDebtAmount,
    uint256 usdxDebtAmount,
    uint256 newPrice
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 currPrice = oracle.getAssetPrice(wethAssetId);
    //     newPrice = bound(newPrice, 0, currPrice - 1);

    //     daiDebtAmount = bound(daiDebtAmount, 1, MAX_SUPPLY_AMOUNT);
    //     usdxDebtAmount = bound(usdxDebtAmount, 1, MAX_SUPPLY_AMOUNT);

    //     // weth collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     // dai/usdx debt
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmountDai = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: daiReserveId,
    //       debtAmount: daiDebtAmount
    //     });

    //     uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmount
    //     });

    //     vm.assume(
    //       wethCollAmountDai + wethCollAmountUsdx < MAX_SUPPLY_AMOUNT &&
    //         wethCollAmountDai + wethCollAmountUsdx > 0
    //     );

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: wethReserveId,
    //       user: alice,
    //       amount: wethCollAmountDai + wethCollAmountUsdx,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, wethReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: bob,
    //       amount: daiDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: alice,
    //       amount: daiDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // Bob supplies usdx
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: bob,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows usdx
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: alice,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     assertGe(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // collateral price drop so that alice is undercollateralized
    //     oracle.setAssetPrice(wethAssetId, newPrice);
    //     vm.assume(spoke1.getHealthFactor(alice) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any non trivial amount of dai will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: alice});
  }

  /// @dev cannot withdraw an amount if HF < 1 due to interest, if multiple debts for same coll
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest()
    public
  {
    vm.skip(true, 'pending refactor');

    //     uint256 daiDebtAmount = 1000e18;
    //     uint256 usdxDebtAmount = 2000e6;

    //     // weth collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     // dai/usdx debt
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmountDai = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: daiReserveId,
    //       debtAmount: daiDebtAmount
    //     });

    //     uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmount
    //     });

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: wethReserveId,
    //       user: alice,
    //       amount: wethCollAmountDai + wethCollAmountUsdx,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, wethReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: bob,
    //       amount: daiDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: alice,
    //       amount: daiDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // Bob supplies usdx
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: bob,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows usdx
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: alice,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     assertApproxEqAbs(
    //       spoke1.getHealthFactor(alice),
    //       spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
    //       1
    //     );

    //     // skip time to accrue interest
    //     skip(365 days);

    //     assertLt(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // cannot withdraw any amount of dai (HF already < threshold)
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: alice});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < 1 due to interest, if multiple debts for same coll
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_debts_with_interest(
    uint256 daiDebtAmount,
    uint256 usdxDebtAmount,
    uint256 skipTime
  ) public {
    vm.skip(true, 'pending refactor');

    //     skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    //     daiDebtAmount = bound(daiDebtAmount, 1, MAX_SUPPLY_AMOUNT);
    //     usdxDebtAmount = bound(usdxDebtAmount, 1, MAX_SUPPLY_AMOUNT);

    //     // weth collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     // dai/usdx debt
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmountDai = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: daiReserveId,
    //       debtAmount: daiDebtAmount
    //     });

    //     uint256 wethCollAmountUsdx = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmount
    //     });

    //     vm.assume(
    //       wethCollAmountDai + wethCollAmountUsdx < MAX_SUPPLY_AMOUNT &&
    //         wethCollAmountDai + wethCollAmountUsdx > 0
    //     );

    //     // Alice supplies weth as collateral
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: wethReserveId,
    //       user: alice,
    //       amount: wethCollAmountDai + wethCollAmountUsdx,
    //       onBehalfOf: alice
    //     });
    //     setUsingAsCollateral(spoke1, alice, wethReserveId, true);

    //     // Bob supplies dai
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: bob,
    //       amount: daiDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows dai
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: daiReserveId,
    //       user: alice,
    //       amount: daiDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     // Bob supplies usdx
    //     Utils.supply({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: bob,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: bob
    //     });
    //     // Alice borrows usdx
    //     Utils.borrow({
    //       spoke: spoke1,
    //       reserveId: usdxReserveId,
    //       user: alice,
    //       amount: usdxDebtAmount,
    //       onBehalfOf: alice
    //     });

    //     assertGe(spoke1.getHealthFactor(alice), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // debt accrual so that alice is undercollateralized
    //     skip(skipTime);
    //     vm.assume(spoke1.getHealthFactor(alice) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing any amount of dai will result in HF < threshold
    //     vm.prank(alice);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: alice});
  }

  /// @dev cannot withdraw an amount to bring HF < 1, if multiple colls for same debt
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_colls() public {
    vm.skip(true, 'pending refactor');

    //     // weth/dai collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     // usdx debt
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 usdxDebtAmountWeth = 3000e6;
    //     uint256 usdxDebtAmountDai = 5000e6;

    //     uint256 wethCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountWeth
    //     });
    //     uint256 daiCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: daiReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountDai
    //     });

    //     // Bob supply weth collateral
    //     Utils.supply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    //     // Bob supply dai collateral
    //     Utils.supply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    //     // Alice supply usdx
    //     Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    //     // Bob draw max allowed usdx debt
    //     vm.prank(bob);
    //     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    //     // valid HF
    //     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing weth will result in HF < threshold
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: wethCollAmount, to: bob}); // todo: resolve precision, should be 1

    //     // withdrawing dai will result in HF < threshold
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: daiReserveId, amount: daiCollAmount, to: bob}); // todo: resolve precision, should be 1
  }

  /// @dev cannot withdraw an amount to bring HF < 1, if multiple colls for same debt
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    vm.skip(true, 'pending refactor');

    //     usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT);
    //     usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT);

    //     // weth/dai collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     // usdx debt
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountWeth
    //     });
    //     uint256 daiCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: daiReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountDai
    //     });

    //     vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    //     vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    //     // Bob supply weth collateral
    //     Utils.supply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    //     // Bob supply dai collateral
    //     Utils.supply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    //     // Alice supply usdx
    //     Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    //     // Bob draw max allowed usdx debt
    //     vm.prank(bob);
    //     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    //     // valid HF
    //     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing some nontrivial amount of weth will result in HF < threshold
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: wethCollAmount, to: bob}); // todo: resolve precision, should be 1

    //     // withdrawing some nontrivial amount of dai will result in HF < threshold
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: daiReserveId, amount: daiCollAmount, to: bob}); // todo: resolve precision, should be 1
  }

  /// @dev cannot withdraw an amount if HF < 1 due to interest, if multiple colls for same debt
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest()
    public
  {
    vm.skip(true, 'pending refactor');

    //     // weth/dai collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     // usdx debt
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 usdxDebtAmountWeth = 3000e6;
    //     uint256 usdxDebtAmountDai = 5000e6;

    //     uint256 wethCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountWeth
    //     });
    //     uint256 daiCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: daiReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountDai
    //     });

    //     // Bob supply weth collateral
    //     Utils.supply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    //     // Bob supply dai collateral
    //     Utils.supply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    //     // Alice supply usdx
    //     Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    //     // Bob draw max allowed usdx debt
    //     vm.prank(bob);
    //     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    //     // valid HF
    //     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // skip time to accrue debt
    //     skip(365 days);
    //     // invalid HF
    //     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // withdrawing weth will result in HF < threshold
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: bob});

    //     // withdrawing dai will result in HF < threshold
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: daiReserveId, amount: 1, to: bob});
  }

  /// @dev cannot withdraw an amount if HF < 1 due to interest, if multiple colls for same debt
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_with_interest(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai
  ) public {
    vm.skip(true, 'pending refactor');

    //     usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT);
    //     usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT);

    //     // weth/dai collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     // usdx debt
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountWeth
    //     });
    //     uint256 daiCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: daiReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountDai
    //     });

    //     vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    //     vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    //     // Bob supply weth collateral
    //     Utils.supply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    //     // Bob supply dai collateral
    //     Utils.supply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    //     // Alice supply usdx
    //     Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    //     // Bob draw max allowed usdx debt
    //     vm.prank(bob);
    //     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    //     // valid HF
    //     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // skip time to accrue debt
    //     skip(365 days);
    //     // invalid HF
    //     vm.assume(spoke1.getHealthFactor(bob) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // cannot withdraw any amount of weth (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: bob});

    //     // cannot withdraw any amount of dai (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: daiReserveId, amount: 1, to: bob});
  }

  /// @dev cannot withdraw an amount if HF < 1 due to price drop, if multiple colls for same debt
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_weth()
    public
  {
    vm.skip(true, 'pending refactor');

    //     // weth/dai collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     // usdx debt
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 usdxDebtAmountWeth = 3000e6;
    //     uint256 usdxDebtAmountDai = 5000e6;

    //     uint256 wethCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountWeth
    //     });
    //     uint256 daiCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: daiReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountDai
    //     });

    //     // Bob supply weth collateral
    //     Utils.supply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    //     // Bob supply dai collateral
    //     Utils.supply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    //     // Alice supply usdx
    //     Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    //     // Bob draw max allowed usdx debt
    //     vm.prank(bob);
    //     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    //     // valid HF
    //     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // collateral price drop by half so that bob is undercollateralized
    //     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(wethAssetId), 50_00); // 50% price drop
    //     oracle.setAssetPrice(wethAssetId, newPrice);
    //     // invalid HF
    //     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // cannot withdraw any amount of weth (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: bob});

    //     // cannot withdraw any amount of dai (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: daiReserveId, amount: 1, to: bob});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < 1 due to price drop, if multiple colls for same debt
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_weth(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai,
    uint256 newPrice
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 currPrice = oracle.getAssetPrice(wethAssetId);
    //     newPrice = bound(newPrice, 0, currPrice - 1);
    //     usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT);
    //     usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT);

    //     // weth/dai collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     // usdx debt
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountWeth
    //     });
    //     uint256 daiCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: daiReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountDai
    //     });

    //     vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    //     vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    //     // Bob supply weth collateral
    //     Utils.supply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    //     // Bob supply dai collateral
    //     Utils.supply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    //     // Alice supply usdx
    //     Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    //     // Bob draw max allowed usdx debt
    //     vm.prank(bob);
    //     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    //     // valid HF
    //     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // collateral price drop by half so that bob is undercollateralized
    //     oracle.setAssetPrice(wethAssetId, newPrice);
    //     // invalid HF
    //     vm.assume(spoke1.getHealthFactor(bob) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // cannot withdraw any amount of weth (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: bob});

    //     // cannot withdraw any amount of dai (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: daiReserveId, amount: 1, to: bob});
  }

  /// @dev cannot withdraw an amount if HF < 1 due to price drop, if multiple colls for same debt
  function test_withdraw_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_dai()
    public
  {
    vm.skip(true, 'pending refactor');

    //     // weth/dai collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     // usdx debt
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 usdxDebtAmountWeth = 3000e6;
    //     uint256 usdxDebtAmountDai = 5000e6;

    //     uint256 wethCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountWeth
    //     });
    //     uint256 daiCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: daiReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountDai
    //     });

    //     // Bob supply weth collateral
    //     Utils.supply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    //     // Bob supply dai collateral
    //     Utils.supply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    //     // Alice supply usdx
    //     Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    //     // Bob draw max allowed usdx debt
    //     vm.prank(bob);
    //     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    //     // valid HF
    //     assertEq(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // collateral price drop by half so that bob is undercollateralized
    //     uint256 newPrice = calcNewPrice(oracle.getAssetPrice(daiReserveId), 50_00); // 50% price drop
    //     oracle.setAssetPrice(daiReserveId, newPrice);
    //     // invalid HF
    //     assertLt(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // cannot withdraw any amount of weth (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: bob});

    //     // cannot withdraw any amount of dai (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: daiReserveId, amount: 1, to: bob});
  }

  /// @dev fuzz - cannot withdraw an amount if HF < 1 due to price drop, if multiple colls for same debt
  function test_withdraw_fuzz_revertsWith_HealthFactorBelowThreshold_multiple_colls_price_drop_dai(
    uint256 usdxDebtAmountWeth,
    uint256 usdxDebtAmountDai,
    uint256 newPrice
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 currPrice = oracle.getAssetPrice(daiAssetId);
    //     newPrice = bound(newPrice, 0, currPrice - 1);
    //     usdxDebtAmountWeth = bound(usdxDebtAmountWeth, 1, MAX_SUPPLY_AMOUNT);
    //     usdxDebtAmountDai = bound(usdxDebtAmountDai, 1, MAX_SUPPLY_AMOUNT);

    //     // weth/dai collateral
    //     uint256 wethReserveId = _wethReserveId(spoke1);
    //     uint256 daiReserveId = _daiReserveId(spoke1);
    //     // usdx debt
    //     uint256 usdxReserveId = _usdxReserveId(spoke1);

    //     uint256 wethCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: wethReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountWeth
    //     });
    //     uint256 daiCollAmount = _calcMinimumCollAmount({
    //       spoke: spoke1,
    //       collReserveId: daiReserveId,
    //       debtReserveId: usdxReserveId,
    //       debtAmount: usdxDebtAmountDai
    //     });

    //     vm.assume(wethCollAmount < MAX_SUPPLY_AMOUNT && wethCollAmount > 0);
    //     vm.assume(daiCollAmount < MAX_SUPPLY_AMOUNT && daiCollAmount > 0);

    //     // Bob supply weth collateral
    //     Utils.supply(spoke1, wethReserveId, bob, wethCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, wethReserveId, true);

    //     // Bob supply dai collateral
    //     Utils.supply(spoke1, daiReserveId, bob, daiCollAmount, bob);
    //     setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    //     // Alice supply usdx
    //     Utils.supply(spoke1, usdxReserveId, alice, usdxDebtAmountWeth + usdxDebtAmountDai, alice); // supply enough buffer for multiple borrows

    //     // Bob draw max allowed usdx debt
    //     vm.prank(bob);
    //     spoke1.borrow(usdxReserveId, (usdxDebtAmountWeth + usdxDebtAmountDai), bob);

    //     // valid HF
    //     assertGe(spoke1.getHealthFactor(bob), spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // collateral price drop by half so that bob is undercollateralized
    //     oracle.setAssetPrice(daiAssetId, newPrice);
    //     // invalid HF
    //     vm.assume(spoke1.getHealthFactor(bob) < spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD());

    //     // cannot withdraw any amount of weth (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: wethReserveId, amount: 1, to: bob});

    //     // cannot withdraw any amount of dai (HF already < threshold)
    //     vm.prank(bob);
    //     vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    //     spoke1.withdraw({reserveId: daiReserveId, amount: 1, to: bob});
  }
}
