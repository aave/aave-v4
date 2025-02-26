// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBaseTest.t.sol';

contract SpokeWithdrawTest is SpokeBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    super.setUp();

    // mock constant 10% IR by default
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded_zero_supplied() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 1;

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw(reserveId, amount, alice);
  }

  function test_withdraw_fuzz_revertsWith_supplied_amount_exceeded_zero_supplied(
    uint256 amount
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw(_daiReserveId(spoke1), amount, alice);
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded() public {
    uint256 amount = 100e18;

    // User spoke supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: alice,
      amount: amount,
      to: alice
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw(_daiReserveId(spoke1), amount + 1, alice);

    // skip time but no index increase with no borrow
    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw(_daiReserveId(spoke1), amount + 1, alice);
  }

  // user has both supplied shares and debt on a reserve
  function test_withdraw_revertsWith_supplied_amount_exceeded_with_debt() public {
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;

    // Alice supplies dai
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: alice,
      amount: supplyAmount,
      to: alice
    });

    // Alice borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    uint256 availableLiquidity = hub.getAvailableLiquidity(daiAssetId);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: _daiReserveId(spoke1), amount: availableLiquidity + 1, to: bob});

    skip(365 days);
    // index has now increased

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: _daiReserveId(spoke1), amount: availableLiquidity + 1, to: alice});
  }

  // user has both supplied shares and debt on a reserve
  function test_withdraw_fuzz_revertsWith_supplied_amount_exceeded_with_debt(
    uint256 reserveId,
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 rate
  ) public {
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2); // ensure it is within LT
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // User spoke supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: supplyAmount,
      to: alice
    });

    // User spoke borrow
    Utils.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    uint256 availableLiquidity = hub.getAvailableLiquidity(reserveId);
    vm.assume(availableLiquidity > 1);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: availableLiquidity + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: availableLiquidity + 1, to: alice});
  }

  function test_withdraw_same_block() public {
    uint256 amount = 100e18;

    TestData[2] memory daiData;
    TestData[2] memory bobData;
    TokenData[2] memory tokenData;

    uint256 expectedSupplyShares = hub.convertToSharesDown(daiAssetId, amount);

    // Bob supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: amount,
      to: bob
    });

    uint256 stage = 0;
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));
    bobData[stage] = _getUserData(_daiReserveId(spoke1), bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

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

    vm.startPrank(bob);
    vm.expectEmit(address(spoke1));
    emit Withdrawn(_daiReserveId(spoke1), amount, bob);
    spoke1.withdraw(_daiReserveId(spoke1), amount, bob);
    vm.stopPrank();

    stage = 1;
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));
    bobData[stage] = _getUserData(_daiReserveId(spoke1), bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

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
    uint256 aliceWithdrawAmount;
    uint256 bobWithdrawAmount;
  }

  struct MultiUserFuzzParams {
    uint256 aliceAmount;
    uint256 bobAmount;
    uint256 borrowAmount;
    uint256 reserveId;
    uint256 skipTime;
    uint256 rate;
  }

  // multiple users, same asset. No debt
  function test_withdraw_fuzz_all_liquidity_with_interest_multi_user(
    MultiUserFuzzParams memory params
  ) public {
    params.reserveId = bound(params.reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    params.aliceAmount = bound(params.aliceAmount, 1, MAX_SUPPLY_AMOUNT - 1);
    params.bobAmount = bound(params.bobAmount, 1, MAX_SUPPLY_AMOUNT - params.aliceAmount);
    params.skipTime = bound(params.skipTime, 0, 10_000 days);
    params.borrowAmount = bound(
      params.borrowAmount,
      1,
      (params.aliceAmount + params.bobAmount) / 2
    ); // some buffer on available borrowable liquidity
    params.rate = bound(params.rate, 1, MAX_BORROW_RATE).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(params.rate)
    );

    address asset = _getAsset(spoke1, params.reserveId);
    uint256 assetId = _getAssetId(spoke1, params.reserveId);

    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: params.reserveId,
      user: alice,
      amount: params.aliceAmount,
      to: alice
    });
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: params.reserveId,
      user: bob,
      amount: params.bobAmount,
      to: bob
    });

    // carol borrows in order to increase index
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: carol,
      amount: params.borrowAmount, // highest value asset so that it is enough collateral
      to: carol
    });
    Utils.borrow({
      spoke: spoke1,
      reserveId: params.reserveId,
      user: carol,
      amount: params.borrowAmount,
      onBehalfOf: carol
    });

    skip(365 days);

    // carol repays all with interest
    uint256 repayAmount = spoke1.getUserCumulativeDebt(params.reserveId, carol);
    deal(asset, carol, repayAmount);
    vm.startPrank(carol);
    spoke1.repay(params.reserveId, repayAmount);
    vm.stopPrank();

    TestData[3] memory reserveData;
    TestData[3] memory aliceData;
    TestData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = _getReserveData(params.reserveId);
    aliceData[stage] = _getUserData(params.reserveId, alice);
    bobData[stage] = _getUserData(params.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    vm.assume(
      aliceData[stage].suppliedAmount > params.aliceAmount &&
        hub.convertToShares(assetId, aliceData[stage].suppliedAmount) > 0
    );

    vm.prank(alice);
    spoke1.withdraw({
      reserveId: params.reserveId,
      amount: aliceData[stage].suppliedAmount,
      to: alice
    });

    skip(params.skipTime);

    stage = 1;
    reserveData[stage] = _getReserveData(params.reserveId);
    aliceData[stage] = _getUserData(params.reserveId, alice);
    bobData[stage] = _getUserData(params.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    vm.assume(
      bobData[stage].suppliedAmount > params.bobAmount &&
        hub.convertToShares(assetId, bobData[stage].suppliedAmount) > 0
    );

    vm.prank(bob);
    spoke1.withdraw({reserveId: params.reserveId, amount: bobData[stage].suppliedAmount, to: bob});

    stage = 2;
    reserveData[stage] = _getReserveData(params.reserveId);
    aliceData[stage] = _getUserData(params.reserveId, alice);
    bobData[stage] = _getUserData(params.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    // reserve
    assertEq(reserveData[stage].data.baseDebt, 0, 'reserveData base debt');
    assertEq(reserveData[stage].data.outstandingPremium, 0, 'reserveData outstanding premium');
    assertApproxEqAbs(
      reserveData[stage].data.suppliedShares,
      0,
      1e1,
      'reserveData supplied shares'
    ); // dust remains due to rounding
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserveData last update timestamp'
    );

    // alice
    assertEq(aliceData[stage].data.baseDebt, 0, 'aliceData base debt');
    assertEq(aliceData[stage].data.outstandingPremium, 0, 'aliceData outstanding premium');
    assertApproxEqAbs(aliceData[stage].data.suppliedShares, 0, 1, 'aliceData supplied shares'); // 1 share difference
    assertEq(
      aliceData[stage].data.lastUpdateTimestamp,
      reserveData[stage - 1].data.lastUpdateTimestamp,
      'aliceData last update timestamp'
    );

    // bob
    assertEq(bobData[stage].data.baseDebt, 0, 'bobData base debt');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'bobData outstanding premium');
    assertApproxEqAbs(bobData[stage].data.suppliedShares, 0, 1, 'bobData supplied shares'); // 1 share difference
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      reserveData[stage].data.lastUpdateTimestamp,
      'bobData last update timestamp'
    );

    // token
    assertEq(tokenData[stage].spokeBalance, 0, 'tokenData spoke balance');
    assertApproxEqAbs(tokenData[stage].hubBalance, 0, 1e1, 'tokenData hub balance'); // 1 amoutn difference for each user
    assertEq(
      IERC20(asset).balanceOf(address(alice)),
      MAX_SUPPLY_AMOUNT - params.aliceAmount + aliceData[0].suppliedAmount,
      'alice balance'
    );
    assertEq(
      IERC20(asset).balanceOf(address(bob)),
      MAX_SUPPLY_AMOUNT - params.bobAmount + bobData[1].suppliedAmount,
      'bob balance'
    );
  }

  struct State {
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
    Utils.updateLiquidityPremium({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      newLiquidityPremium: 0
    });

    State memory state;
    state.reserveId = spokeInfo[spoke1].dai.reserveId;
    state.collateralReserveId = spokeInfo[spoke1].weth.reserveId;
    state.suppliedCollateralAmount = 100e18;
    state.borrowAmount = 10e18;
    state.borrowReserveSupplyAmount = 20e18;
    state.timestamp = vm.getBlockTimestamp();
    state.rate = uint256(10_00).bpsToRay();

    (, state.supplyShares) = _increaseShareConversionIndex({
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
      rate: state.rate
    });

    (state.aliceBaseDebt, state.aliceOutstandingPremium) = spoke1.getUserDebt(
      state.reserveId,
      alice
    );
    assertTrue(
      state.aliceOutstandingPremium == 0,
      'alice has no premium contribution to exchange rate'
    );

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserCumulativeDebt(state.reserveId, alice);
    vm.prank(alice);
    spoke1.repay(state.reserveId, repayAmount);

    // number of test stages
    TestData[3] memory reserveData;
    TestData[3] memory aliceData;
    TestData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    state.withdrawAmount = hub.getAvailableLiquidity(daiAssetId);

    assertTrue(
      spoke1.getUserSuppliedAmount(state.reserveId, bob) > state.supplyAmount,
      'supplied amount with interest'
    );

    stage = 1;
    state.withdrawnShares = hub.convertToShares(daiAssetId, state.withdrawAmount);
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage = 2;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    reserveData[stage].cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      state.rate,
      uint40(state.timestamp)
    );

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
    assertEq(
      tokenList.dai.balanceOf(address(alice)),
      MAX_SUPPLY_AMOUNT + state.borrowAmount - repayAmount,
      'alice balance'
    );
    assertEq(
      tokenList.dai.balanceOf(address(bob)),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );
  }

  struct TestWithInterestFuzzParams {
    uint256 reserveId;
    uint256 borrowAmount;
    uint256 rate;
    uint256 borrowReserveSupplyAmount;
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

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(params.rate)
    );

    vm.assume(params.reserveId != _wbtcReserveId(spoke1));

    address asset = _getAsset(spoke1, params.reserveId);
    uint256 assetId = _getAssetId(spoke1, params.reserveId);

    // set weth LP to 0 for no premium contribution
    Utils.updateLiquidityPremium({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1), // use highest-valued asset
      newLiquidityPremium: 0
    });

    State memory state;
    state.reserveId = params.reserveId;
    state.collateralReserveId = spokeInfo[spoke1].wbtc.reserveId;
    state.suppliedCollateralAmount = MAX_SUPPLY_AMOUNT; // ensure enough collateral
    state.borrowReserveSupplyAmount = params.borrowReserveSupplyAmount;
    state.borrowAmount = params.borrowAmount;
    state.rate = params.rate;
    state.timestamp = vm.getBlockTimestamp();

    (, state.supplyShares) = _increaseShareConversionIndex({
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
      rate: state.rate
    });

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserCumulativeDebt(state.reserveId, alice);
    deal(asset, alice, repayAmount);

    vm.assume(repayAmount > state.borrowAmount);
    (, state.aliceOutstandingPremium) = spoke1.getUserDebt(state.reserveId, alice);
    assertTrue(
      state.aliceOutstandingPremium == 0,
      'alice has no premium contribution to exchange rate'
    );

    vm.startPrank(alice);
    IERC20(asset).approve(address(hub), repayAmount);
    spoke1.repay(state.reserveId, repayAmount);
    vm.stopPrank();

    // number of test stages
    TestData[3] memory reserveData;
    TestData[3] memory aliceData;
    TestData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    state.withdrawAmount = hub.getAvailableLiquidity(state.reserveId);

    assertTrue(
      spoke1.getUserSuppliedAmount(state.reserveId, bob) > state.supplyAmount,
      'supplied amount with interest'
    );

    stage = 1;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));
    state.withdrawnShares = hub.convertToShares(assetId, state.withdrawAmount);

    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage = 2;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

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
    assertEq(IERC20(asset).balanceOf(address(alice)), 0, 'alice balance');
    assertEq(
      IERC20(asset).balanceOf(address(bob)),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );
  }

  function test_withdraw_all_liquidity_with_interest_with_premium() public {
    State memory state;
    state.reserveId = spokeInfo[spoke1].dai.reserveId;
    state.collateralReserveId = spokeInfo[spoke1].usdx.reserveId;
    state.suppliedCollateralAmount = 100e18;
    state.borrowAmount = 10e18;
    state.borrowReserveSupplyAmount = 20e18;
    state.timestamp = vm.getBlockTimestamp();
    state.rate = uint256(10_00).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(state.rate)
    );

    // number of test stages
    TestData[3] memory daiData;
    TestData[3] memory aliceData;
    TestData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 timestamp = vm.getBlockTimestamp();

    (, state.supplyShares) = _increaseShareConversionIndex({
      collateral: TestReserve({
        reserveId: state.collateralReserveId,
        supplier: alice,
        borrower: address(0),
        supplyAmount: state.suppliedCollateralAmount,
        borrowAmount: 0
      }),
      borrow: TestReserve({
        reserveId: state.reserveId,
        supplier: bob,
        borrower: alice,
        supplyAmount: state.borrowReserveSupplyAmount,
        borrowAmount: state.borrowAmount
      }),
      rate: state.rate
    });

    (, state.aliceOutstandingPremium) = spoke1.getUserDebt(state.reserveId, alice);

    assertTrue(
      state.aliceOutstandingPremium > 0,
      'alice has premium contribution to exchange rate'
    );

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserCumulativeDebt(state.reserveId, alice);
    vm.prank(alice);
    spoke1.repay(state.reserveId, repayAmount);

    uint256 stage = 0;
    daiData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));
    daiData[stage].cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      state.rate,
      uint40(timestamp)
    );

    state.withdrawAmount = hub.getAvailableLiquidity(daiAssetId); // withdraw all liquidity

    assertTrue(
      spoke1.getUserSuppliedAmount(state.reserveId, bob) > state.supplyAmount,
      'supplied amount with interest'
    );

    stage = 1;
    state.withdrawnShares = hub.convertToShares(daiAssetId, state.withdrawAmount);
    daiData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    daiData[stage].cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      state.rate,
      uint40(daiData[stage - 1].data.lastUpdateTimestamp)
    );

    stage = 2;
    daiData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    daiData[stage].cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      state.rate,
      uint40(daiData[stage - 1].data.lastUpdateTimestamp)
    );

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
    assertEq(
      tokenList.dai.balanceOf(address(alice)),
      MAX_SUPPLY_AMOUNT + state.borrowAmount - repayAmount,
      'alice balance'
    );
    assertEq(
      tokenList.dai.balanceOf(address(bob)),
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

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(params.rate)
    );

    vm.assume(params.reserveId != _wbtcReserveId(spoke1)); // wbtc used as collateral

    address asset = _getAsset(spoke1, params.reserveId);
    uint256 assetId = _getAssetId(spoke1, params.reserveId);

    State memory state;
    state.reserveId = params.reserveId;
    state.collateralReserveId = spokeInfo[spoke1].wbtc.reserveId;
    state.suppliedCollateralAmount = MAX_SUPPLY_AMOUNT; // ensure enough collateral
    state.borrowReserveSupplyAmount = params.borrowReserveSupplyAmount;
    state.borrowAmount = params.borrowAmount;
    state.rate = params.rate;
    state.timestamp = vm.getBlockTimestamp();

    (, state.supplyShares) = _increaseShareConversionIndex({
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
      rate: state.rate
    });

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserCumulativeDebt(state.reserveId, alice);
    deal(asset, alice, repayAmount);

    vm.assume(repayAmount > state.borrowAmount); // interest

    vm.startPrank(alice);
    IERC20(asset).approve(address(hub), repayAmount);
    spoke1.repay(state.reserveId, repayAmount);
    vm.stopPrank();

    // number of test stages
    TestData[3] memory reserveData;
    TestData[3] memory aliceData;
    TestData[3] memory bobData;
    TokenData[3] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    state.withdrawAmount = hub.getAvailableLiquidity(state.reserveId);

    (, state.aliceOutstandingPremium) = spoke1.getUserDebt(state.reserveId, alice);

    assertTrue(
      spoke1.getUserSuppliedAmount(state.reserveId, bob) > state.supplyAmount,
      'supplied amount with interest'
    );
    assertTrue(
      state.aliceOutstandingPremium == 0,
      'alice has no premium contribution to exchange rate'
    );

    stage = 1;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));
    state.withdrawnShares = hub.convertToShares(assetId, state.withdrawAmount);

    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage = 2;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

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
    assertEq(IERC20(asset).balanceOf(address(alice)), 0, 'alice balance');
    assertEq(
      IERC20(asset).balanceOf(address(bob)),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );
  }

  function _getAsset(Spoke spoke, uint256 reserveId) internal returns (address) {
    return spoke.getReserve(reserveId).asset;
  }

  function _getAssetId(Spoke spoke, uint256 reserveId) internal returns (uint256) {
    return spoke.getReserve(reserveId).assetId;
  }
}
