// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawTest is SpokeBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function test_withdraw_revertsWith_InsufficientSupply_zero_supplied() public {
    uint256 reserveId = daiReserveId(spoke1);
    uint256 amount = 1;

    assertEq(spoke1.getUserSuppliedAmount(reserveId, alice), 0);

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, 0));
    spoke1.withdraw(reserveId, amount, alice);
  }

  function test_withdraw_fuzz_revertsWith_InsufficientSupply_zero_supplied(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    uint256 reserveId = daiReserveId(spoke1);

    assertEq(spoke1.getUserSuppliedAmount(reserveId, alice), 0);

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, 0));
    spoke1.withdraw(reserveId, amount, alice);
  }

  function test_withdraw_revertsWith_InsufficientSupply_with_supply() public {
    uint256 amount = 100e18;
    uint256 reserveId = daiReserveId(spoke1);

    // User spoke supply
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      onBehalfOf: alice
    });

    uint256 withdrawalLimit = getWithdrawalLimit(spoke1, reserveId, alice);
    assertGt(withdrawalLimit, 0);

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, withdrawalLimit));
    spoke1.withdraw(reserveId, withdrawalLimit + 1, alice);

    // skip time but no index increase with no borrow
    skip(365 days);
    // withdrawal limit remains constant
    assertEq(withdrawalLimit, getWithdrawalLimit(spoke1, reserveId, alice));

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, withdrawalLimit));
    spoke1.withdraw(reserveId, withdrawalLimit + 1, alice);
  }

  // user has both supplied shares and debt on a reserve
  function test_withdraw_revertsWith_InsufficientSupply_with_debt() public {
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;
    uint256 reserveId = daiReserveId(spoke1);

    // Alice supplies dai
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    // Alice borrows dai
    Utils.spokeBorrow({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, supplyAmount));
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount + 1, to: bob});

    // accrue interest
    skip(365 days);

    uint256 newWithdrawalLimit = getWithdrawalLimit(spoke1, reserveId, alice);
    // newWithdrawalLimit with accrued interest should be greater than supplyAmount
    assertGt(newWithdrawalLimit, supplyAmount);

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, newWithdrawalLimit));
    spoke1.withdraw({reserveId: reserveId, amount: newWithdrawalLimit + 1, to: alice});
  }

  // user has both supplied shares and debt on a reserve
  function test_withdraw_fuzz_revertsWith_InsufficientSupply_with_debt(
    uint256 reserveId,
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 rate,
    uint256 skipTime
  ) public {
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2); // ensure it is within LT
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay();
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // User spoke supply
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    // Alice borrows dai
    Utils.spokeBorrow({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, supplyAmount));
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount + 1, to: alice});

    // debt accrues
    skip(skipTime);

    uint256 newWithdrawalLimit = getWithdrawalLimit(spoke1, reserveId, alice);
    // newWithdrawalLimit with accrued interest should be greater than supplyAmount
    vm.assume(newWithdrawalLimit > supplyAmount);

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, newWithdrawalLimit));
    spoke1.withdraw({reserveId: reserveId, amount: newWithdrawalLimit + 1, to: alice});
  }

  function test_withdraw_same_block() public {
    uint256 amount = 100e18;

    TestData[2] memory daiData;
    TestUserData[2] memory bobData;
    TokenData[2] memory tokenData;

    uint256 expectedSupplyShares = hub.convertToShares(daiAssetId, amount);

    // Bob supply
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: daiReserveId(spoke1),
      user: bob,
      amount: amount,
      onBehalfOf: bob
    });

    uint256 stage = 0;
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));
    bobData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // reserve
    assertEq(daiData[stage].suppliedAmount, amount, 'reserve suppliedAmount pre-withdraw');
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp pre-withdraw'
    );
    assertEq(
      daiData[stage].data.suppliedShares,
      expectedSupplyShares,
      'bob suppliedShares pre-withdraw'
    );
    // bob
    assertEq(bobData[stage].suppliedAmount, amount, 'bob suppliedAmount pre-withdraw');
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'bob lastUpdateTimestamp pre-withdraw'
    );
    assertEq(
      bobData[stage].data.suppliedShares,
      expectedSupplyShares,
      'bob suppliedShares pre-withdraw'
    );
    // token
    assertEq(tokenData[stage].spokeBalance, 0, 'dai spokeBalance pre-withdraw');
    assertEq(tokenData[stage].hubBalance, amount, 'dai hubBalance pre-withdraw');
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - amount,
      'bob dai balance pre-withdraw'
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdrawn(daiReserveId(spoke1), bob, amount);
    vm.prank(bob);
    spoke1.withdraw(daiReserveId(spoke1), amount, bob);

    stage = 1;
    daiData[stage] = loadReserveInfo(spoke1, daiReserveId(spoke1));
    bobData[stage] = loadUserInfo(spoke1, daiReserveId(spoke1), bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // reserve
    assertEq(daiData[stage].suppliedAmount, 0, 'reserve suppliedAmount post-withdraw');
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-withdraw'
    );
    assertEq(daiData[stage].data.suppliedShares, 0, 'bob suppliedShares post-withdraw');
    // bob
    assertEq(bobData[stage].suppliedAmount, 0, 'bob suppliedAmount post-withdraw');
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'bob lastUpdateTimestamp post-withdraw'
    );
    assertEq(bobData[stage].data.suppliedShares, 0, 'bob suppliedShares post-withdraw');
    // token
    assertEq(tokenData[stage].spokeBalance, 0, 'dai spokeBalance post-withdraw');
    assertEq(tokenData[stage].hubBalance, 0, 'dai hubBalance post-withdraw');
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT, 'bob dai balance post-withdraw');
  }

  struct MultiUserTestState {
    IERC20 asset;
    uint256 assetId;
    uint256 stage;
    uint256 sharePrecision;
    uint256 repayAmount;
  }

  struct MultiUserFuzzParams {
    uint256 aliceAmount;
    uint256 bobAmount;
    uint256 borrowAmount;
    uint256 reserveId;
    uint256[2] skipTime;
    uint256 rate;
  }

  // multiple users, same asset
  function test_withdraw_fuzz_all_liquidity_with_interest_multi_user(
    MultiUserFuzzParams memory params
  ) public {
    params.reserveId = bound(params.reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    params.aliceAmount = bound(params.aliceAmount, 1, MAX_SUPPLY_AMOUNT - 1);
    params.bobAmount = bound(params.bobAmount, 1, MAX_SUPPLY_AMOUNT - params.aliceAmount);
    params.skipTime[0] = bound(params.skipTime[0], 0, 10_000 days);
    params.skipTime[1] = bound(params.skipTime[1], 0, 10_000 days);
    params.borrowAmount = bound(
      params.borrowAmount,
      1,
      (params.aliceAmount + params.bobAmount) / 2
    ); // some buffer on available borrowable liquidity
    params.rate = bound(params.rate, 1, MAX_BORROW_RATE).bpsToRay();

    MultiUserTestState memory state;

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(params.rate)
    );

    (state.assetId, state.asset) = getAssetInfo(spoke1, params.reserveId);

    // alice supplies reserve
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: params.reserveId,
      user: alice,
      amount: params.aliceAmount,
      onBehalfOf: alice
    });
    // bob supplies reserve
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: params.reserveId,
      user: bob,
      amount: params.bobAmount,
      onBehalfOf: bob
    });

    // carol borrows in order to increase index
    Utils.spokeSupply({
      spoke: spoke1,
      reserveId: wbtcReserveId(spoke1),
      user: carol,
      amount: params.borrowAmount, // highest value asset so that it is enough collateral
      onBehalfOf: carol
    });
    Utils.spokeBorrow({
      spoke: spoke1,
      reserveId: params.reserveId,
      user: carol,
      amount: params.borrowAmount,
      onBehalfOf: carol
    });

    // accrue interest
    skip(params.skipTime[0]);

    // carol repays all with interest
    state.repayAmount = spoke1.getUserCumulativeDebt(params.reserveId, carol);
    // deal in case carol's repayAmount exceeds default supplied amount due to interest
    deal(address(state.asset), carol, state.repayAmount);
    vm.prank(carol);
    spoke1.repay(params.reserveId, state.repayAmount);

    TestData[3] memory reserveData;
    TestUserData[3] memory aliceData;
    TestUserData[3] memory bobData;
    TokenData[3] memory tokenData;

    state.stage = 0;
    reserveData[state.stage] = loadReserveInfo(spoke1, params.reserveId);
    aliceData[state.stage] = loadUserInfo(spoke1, params.reserveId, alice);
    bobData[state.stage] = loadUserInfo(spoke1, params.reserveId, bob);
    tokenData[state.stage] = getTokenBalances(state.asset, address(spoke1));

    // make sure alice has a share to withdraw
    vm.assume(
      aliceData[state.stage].suppliedAmount > params.aliceAmount &&
        aliceData[state.stage].data.suppliedShares > 0
    );

    // withdraw all supplied
    vm.prank(alice);
    spoke1.withdraw({
      reserveId: params.reserveId,
      amount: aliceData[state.stage].suppliedAmount,
      to: alice
    });

    // skip time to accrue interest for bob
    skip(params.skipTime[1]);

    state.stage = 1;
    reserveData[state.stage] = loadReserveInfo(spoke1, params.reserveId);
    aliceData[state.stage] = loadUserInfo(spoke1, params.reserveId, alice);
    bobData[state.stage] = loadUserInfo(spoke1, params.reserveId, bob);
    tokenData[state.stage] = getTokenBalances(state.asset, address(spoke1));

    // make sure bob has a share to withdraw
    vm.assume(
      bobData[state.stage].suppliedAmount > params.bobAmount &&
        bobData[state.stage].data.suppliedShares > 0
    );

    // bob withdraws all supplied
    vm.prank(bob);
    spoke1.withdraw({
      reserveId: params.reserveId,
      amount: bobData[state.stage].suppliedAmount,
      to: bob
    });

    state.stage = 2;
    reserveData[state.stage] = loadReserveInfo(spoke1, params.reserveId);
    aliceData[state.stage] = loadUserInfo(spoke1, params.reserveId, alice);
    bobData[state.stage] = loadUserInfo(spoke1, params.reserveId, bob);
    tokenData[state.stage] = getTokenBalances(state.asset, address(spoke1));

    // reserve
    assertEq(reserveData[state.stage].data.baseDebt, 0, 'reserveData base debt');
    assertEq(
      reserveData[state.stage].data.outstandingPremium,
      0,
      'reserveData outstanding premium'
    );
    assertEq(reserveData[state.stage].data.suppliedShares, 0, 'reserveData supplied shares');
    assertEq(
      reserveData[state.stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserveData last update timestamp'
    );

    // alice
    assertEq(aliceData[state.stage].data.baseDebt, 0, 'aliceData base debt');
    assertEq(aliceData[state.stage].data.outstandingPremium, 0, 'aliceData outstanding premium');
    assertEq(aliceData[state.stage].data.suppliedShares, 0, 'aliceData supplied shares');
    assertEq(
      aliceData[state.stage].data.lastUpdateTimestamp,
      reserveData[state.stage - 1].data.lastUpdateTimestamp,
      'aliceData last update timestamp'
    );

    // bob
    assertEq(bobData[state.stage].data.baseDebt, 0, 'bobData base debt');
    assertEq(bobData[state.stage].data.outstandingPremium, 0, 'bobData outstanding premium');
    assertEq(bobData[state.stage].data.suppliedShares, 0, 'bobData supplied shares');
    assertEq(
      bobData[state.stage].data.lastUpdateTimestamp,
      reserveData[state.stage].data.lastUpdateTimestamp,
      'bobData last update timestamp'
    );

    // token
    assertEq(tokenData[state.stage].spokeBalance, 0, 'tokenData spoke balance');
    assertEq(tokenData[state.stage].hubBalance, 0, 'tokenData hub balance');
    assertEq(
      state.asset.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - params.aliceAmount + aliceData[0].suppliedAmount,
      'alice balance'
    );
    assertEq(
      state.asset.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - params.bobAmount + bobData[1].suppliedAmount,
      'bob balance'
    );
  }

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
    uint256 aliceOutstandingPremium;
    uint256 borrowReserveSupplyAmount;
  }

  function test_withdraw_all_liquidity_with_interest_no_premium() public {
    // set weth LP to 0 for no premium contribution
    updateLiquidityPremium({
      spoke: spoke1,
      reserveId: wethReserveId(spoke1),
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

    (state.aliceBaseDebt, state.aliceOutstandingPremium) = spoke1.getUserDebt(
      state.reserveId,
      alice
    );
    assertEq(
      state.aliceOutstandingPremium,
      0,
      'alice has no premium contribution to exchange rate'
    );

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserCumulativeDebt(state.reserveId, alice);
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
    state.withdrawnShares = hub.convertToShares(daiAssetId, state.withdrawAmount);
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

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
    assertEq(reserveData[stage].data.baseDebt, 0, 'reserveData base debt');
    assertEq(reserveData[stage].data.outstandingPremium, 0, 'reserveData outstanding premium');
    assertEq(reserveData[stage].data.suppliedShares, 0, 'reserveData supplied shares');
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserveData last update timestamp'
    );

    // alice
    assertEq(aliceData[stage].data.baseDebt, 0, 'aliceData base debt');
    assertEq(aliceData[stage].data.outstandingPremium, 0, 'aliceData outstanding premium');
    assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');
    assertEq(
      aliceData[stage].data.lastUpdateTimestamp,
      aliceData[0].data.lastUpdateTimestamp,
      'aliceData last update timestamp'
    );

    // bob
    assertEq(bobData[stage].data.baseDebt, 0, 'bobData base debt');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'bobData outstanding premium');
    assertEq(bobData[stage].data.suppliedShares, 0, 'bobData supplied shares');
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'bobData last update timestamp'
    );

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
  }

  struct TestWithInterestFuzzParams {
    uint256 reserveId;
    uint256 borrowAmount;
    uint256 rate;
    uint256 borrowReserveSupplyAmount;
    uint256 skipTime;
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
    vm.assume(params.reserveId != wbtcReserveId(spoke1));

    (uint256 assetId, IERC20 asset) = getAssetInfo(spoke1, params.reserveId);

    // set weth LP to 0 for no premium contribution
    updateLiquidityPremium({
      spoke: spoke1,
      reserveId: wbtcReserveId(spoke1), // use highest-valued asset
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

    uint256 repayAmount = spoke1.getUserCumulativeDebt(state.reserveId, alice);
    // deal because repayAmount may exceed default supplied amount due to interest
    deal(address(asset), alice, repayAmount);

    vm.assume(repayAmount > state.borrowAmount);
    (, state.aliceOutstandingPremium) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(
      state.aliceOutstandingPremium,
      0,
      'alice has no premium contribution to exchange rate'
    );

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
    state.withdrawnShares = hub.convertToShares(assetId, state.withdrawAmount);

    // bob withdraws all
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage = 2;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(asset, address(spoke1));

    // reserve
    assertEq(reserveData[stage].data.baseDebt, 0, 'reserveData base debt');
    assertEq(reserveData[stage].data.outstandingPremium, 0, 'reserveData outstanding premium');
    assertEq(reserveData[stage].data.suppliedShares, 0, 'reserveData supplied shares');
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserveData last update timestamp'
    );

    // alice
    assertEq(aliceData[stage].data.baseDebt, 0, 'aliceData base debt');
    assertEq(aliceData[stage].data.outstandingPremium, 0, 'aliceData outstanding premium');
    assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');
    assertEq(
      aliceData[stage].data.lastUpdateTimestamp,
      aliceData[0].data.lastUpdateTimestamp,
      'aliceData last update timestamp'
    );

    // bob
    assertEq(bobData[stage].data.baseDebt, 0, 'bobData base debt');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'bobData outstanding premium');
    assertEq(
      bobData[stage].data.suppliedShares,
      state.supplyShares - state.withdrawnShares,
      'bobData supplied shares'
    );
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'bobData last update timestamp'
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

    (, state.aliceOutstandingPremium) = spoke1.getUserDebt(state.reserveId, alice);

    assertGt(state.aliceOutstandingPremium, 0, 'alice has premium contribution to exchange rate');

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserCumulativeDebt(state.reserveId, alice);
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
    state.withdrawnShares = hub.convertToShares(daiAssetId, state.withdrawAmount);
    daiData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // debt is fully repaid, so bob can withdraw all supplied
    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage = 2;
    daiData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserveData base debt');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserveData outstanding premium');
    assertEq(
      daiData[stage].data.suppliedShares,
      daiData[1].data.suppliedShares - state.withdrawnShares,
      'reserveData supplied shares'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'daiData last update timestamp'
    );

    // alice
    assertEq(aliceData[stage].data.baseDebt, 0, 'aliceData base debt');
    assertEq(aliceData[stage].data.outstandingPremium, 0, 'aliceData outstanding premium');
    assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');
    assertEq(
      aliceData[stage].data.lastUpdateTimestamp,
      aliceData[stage - 1].data.lastUpdateTimestamp,
      'aliceData last update timestamp'
    );

    // bob
    assertEq(bobData[stage].data.baseDebt, 0, 'bobData base debt');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'bobData outstanding premium');
    assertEq(bobData[stage].data.suppliedShares, 0, 'bobData supplied shares');
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'bobData last update timestamp'
    );

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

    vm.assume(params.reserveId != wbtcReserveId(spoke1)); // wbtc used as collateral

    (uint256 assetId, IERC20 asset) = getAssetInfo(spoke1, params.reserveId);

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
    uint256 repayAmount = spoke1.getUserCumulativeDebt(state.reserveId, alice);
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

    (, state.aliceOutstandingPremium) = spoke1.getUserDebt(state.reserveId, alice);

    assertGt(
      spoke1.getUserSuppliedAmount(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );
    assertEq(
      state.aliceOutstandingPremium,
      0,
      'alice has no premium contribution to exchange rate'
    );

    stage = 1;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(asset, address(spoke1));
    state.withdrawnShares = hub.convertToShares(assetId, state.withdrawAmount);

    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage = 2;
    reserveData[stage] = loadReserveInfo(spoke1, state.reserveId);
    aliceData[stage] = loadUserInfo(spoke1, state.reserveId, alice);
    bobData[stage] = loadUserInfo(spoke1, state.reserveId, bob);
    tokenData[stage] = getTokenBalances(asset, address(spoke1));

    // reserve
    assertEq(reserveData[stage].data.baseDebt, 0, 'reserveData base debt');
    assertEq(reserveData[stage].data.outstandingPremium, 0, 'reserveData outstanding premium');
    assertEq(reserveData[stage].data.suppliedShares, 0, 'reserveData supplied shares');
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserveData last update timestamp'
    );

    // alice
    assertEq(aliceData[stage].data.baseDebt, 0, 'aliceData base debt');
    assertEq(aliceData[stage].data.outstandingPremium, 0, 'aliceData outstanding premium');
    assertEq(aliceData[stage].data.suppliedShares, 0, 'aliceData supplied shares');
    assertEq(
      aliceData[stage].data.lastUpdateTimestamp,
      aliceData[0].data.lastUpdateTimestamp,
      'aliceData last update timestamp'
    );

    // bob
    assertEq(bobData[stage].data.baseDebt, 0, 'bobData base debt');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'bobData outstanding premium');
    assertEq(
      bobData[stage].data.suppliedShares,
      state.supplyShares - state.withdrawnShares,
      'bobData supplied shares'
    );
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'bobData last update timestamp'
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
  }
}
