// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBaseTest.t.sol';

contract SpokeWithdrawTest is SpokeBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    super.setUp();

    // mock constant 10% IR
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded_zero_supplied() public {
    uint256 reserveId = 0;
    uint256 amount = 1;

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount, to: alice});
  }

  function test_withdraw_fuzz_revertsWith_supplied_amount_exceeded_zero_supplied(
    uint256 amount,
    uint256 reserveId
  ) public {
    reserveId = bound(amount, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount, to: alice});
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded() public {
    uint256 reserveId = spokeInfo[spoke1].weth.reserveId;
    uint256 amount = 100e18;

    // User spoke supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      to: alice
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount + 1, to: alice});
  }

  function test_withdraw_fuzz_revertsWith_supplied_amount_exceeded(
    uint256 amount,
    uint256 reserveId
  ) public {
    reserveId = bound(amount, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    // User spoke supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      to: alice
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount + 1, to: alice});
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded_with_debt() public {
    uint256 reserveId = spokeInfo[spoke1].weth.reserveId;
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;

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

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount - borrowAmount + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount - borrowAmount + 1, to: alice});
  }

  function test_withdraw_fuzz_revertsWith_supplied_amount_exceeded_with_debt(
    uint256 reserveId,
    uint256 supplyAmount,
    uint256 borrowAmount
  ) public {
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount); // ensure it is within LT

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

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount - borrowAmount + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: supplyAmount - borrowAmount + 1, to: alice});
  }

  function test_withdraw_same_block() public {
    uint256 amount = 100e18;
    uint256 reserveId = spokeInfo[spoke1].dai.reserveId;

    TestData[2] memory reserveData;
    TestData[2] memory bobData;
    TokenData[2] memory tokenData;

    uint256 expectedSupplyShares = hub.convertToSharesDown(daiAssetId, amount);

    // Bob supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: bob,
      amount: amount,
      to: bob
    });

    uint256 stage = 0;
    reserveData[stage] = _getReserveData(reserveId);
    bobData[stage] = _getUserData(reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    // reserve
    assertEq(reserveData[stage].suppliedAmount, amount, 'reserve suppliedAmount pre-withdraw');
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp pre-withdraw'
    );
    assertEq(
      reserveData[stage].data.suppliedShares,
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
    emit Withdrawn(reserveId, amount, bob);
    spoke1.withdraw(reserveId, amount, bob);
    vm.stopPrank();

    stage = 1;
    reserveData[stage] = _getReserveData(reserveId);
    bobData[stage] = _getUserData(reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    // reserve
    assertEq(reserveData[stage].suppliedAmount, 0, 'reserve suppliedAmount post-withdraw');
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-withdraw'
    );
    assertEq(reserveData[stage].data.suppliedShares, 0, 'bob suppliedShares post-withdraw');
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

  // multiple users, same asset. No debt
  function test_withdraw_fuzz_multi_user(
    uint256 amount,
    uint256 amount2,
    uint256 reserveId,
    uint256 skipTime
  ) public {
    reserveId = bound(amount, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT - 1);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT - amount);
    skipTime = bound(skipTime, 0, 10_000 days);

    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      to: alice
    });
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: bob,
      amount: amount2,
      to: bob
    });

    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: amount, to: alice});

    skip(skipTime);

    vm.prank(bob);
    spoke1.withdraw({reserveId: reserveId, amount: amount2, to: bob});

    TestData memory reserveData = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    TestData memory aliceData = _getUserData(spokeInfo[spoke1].dai.reserveId, alice);
    TestData memory bobData = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    TokenData memory tokenData = _getTokenBalances(address(tokenList.dai), address(spoke1));

    // reserve
    assertEq(reserveData.data.baseDebt, 0, 'reserveData base debt');
    assertEq(reserveData.data.outstandingPremium, 0, 'reserveData outstanding premium');
    assertEq(reserveData.data.suppliedShares, 0, 'reserveData supplied shares');
    assertEq(reserveData.data.lastUpdateTimestamp, 0, 'reserveData last update timestamp');

    // alice
    assertEq(aliceData.data.baseDebt, 0, 'aliceData base debt');
    assertEq(aliceData.data.outstandingPremium, 0, 'aliceData outstanding premium');
    assertEq(aliceData.data.suppliedShares, 0, 'aliceData supplied shares');
    assertEq(aliceData.data.lastUpdateTimestamp, 0, 'aliceData last update timestamp');

    // bob
    assertEq(bobData.data.baseDebt, 0, 'bobData base debt');
    assertEq(bobData.data.outstandingPremium, 0, 'bobData outstanding premium');
    assertEq(bobData.data.suppliedShares, 0, 'bobData supplied shares');
    assertEq(bobData.data.lastUpdateTimestamp, 0, 'bobData last update timestamp');

    // token
    assertEq(tokenData.spokeBalance, 0, 'tokenData spoke balance');
    assertEq(tokenData.hubBalance, 0, 'tokenData hub balance');
    assertEq(tokenList.dai.balanceOf(address(alice)), MAX_SUPPLY_AMOUNT, 'alice balance');
    assertEq(tokenList.dai.balanceOf(address(bob)), MAX_SUPPLY_AMOUNT, 'bob balance');
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
    uint256 trivialSupplyAmount;
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
      reserveId: _wethLiquidityPremium(),
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
    state.trivialSupplyAmount = 1e18;

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
    (state.aliceBaseDebt, state.aliceOutstandingPremium) = spoke1.getUserDebt(
      state.reserveId,
      alice
    );

    assertTrue(
      spoke1.getUserSuppliedAmount(state.reserveId, bob) > state.supplyAmount,
      'supplied amount with interest'
    );
    assertTrue(
      state.aliceOutstandingPremium == 0,
      'alice has no premium contribution to exchange rate'
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
    assertEq(
      reserveData[stage].data.baseDebt,
      state.borrowAmount.rayMul(reserveData[stage].cumulatedBaseInterest),
      'reserveData base debt'
    );
    assertEq(reserveData[stage].data.outstandingPremium, 0, 'reserveData outstanding premium');
    assertEq(
      reserveData[stage].data.suppliedShares,
      hub.convertToShares(
        daiAssetId,
        state.borrowAmount.rayMul(reserveData[stage].cumulatedBaseInterest)
      ),
      'reserveData supplied shares'
    );
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserveData last update timestamp'
    );

    // alice
    assertEq(
      aliceData[stage].data.baseDebt,
      state.borrowAmount.rayMul(reserveData[stage].cumulatedBaseInterest),
      'aliceData base debt'
    );
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
      MAX_SUPPLY_AMOUNT + state.borrowAmount,
      'alice balance'
    );
    assertEq(
      tokenList.dai.balanceOf(address(bob)),
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
    state.trivialSupplyAmount = 1e18;

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

    // number of test stages
    TestData[5] memory reserveData;
    TestData[5] memory aliceData;
    TestData[5] memory bobData;
    TokenData[5] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    // action on the borrowed reserve to trigger risk premium
    // TODO: shouldnt be needed after RP accrual is fixed
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: state.reserveId,
      user: alice,
      amount: state.trivialSupplyAmount,
      to: alice
    });

    stage = 1;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    state.trivialSupplyShares = hub.convertToShares(daiAssetId, state.trivialSupplyAmount);

    skip(365 days);

    stage = 2;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));
    reserveData[stage].cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      state.rate,
      uint40(reserveData[stage - 1].data.lastUpdateTimestamp)
    );

    state.withdrawAmount = hub.getAvailableLiquidity(daiAssetId);
    (state.aliceBaseDebt, state.aliceOutstandingPremium) = spoke1.getUserDebt(
      state.reserveId,
      alice
    );

    assertTrue(
      spoke1.getUserSuppliedAmount(state.reserveId, bob) > state.supplyAmount,
      'supplied amount with interest'
    );
    assertTrue(
      state.aliceOutstandingPremium > 0,
      'alice has premium contribution to exchange rate'
    );

    stage = 3;
    state.withdrawnShares = hub.convertToShares(daiAssetId, state.withdrawAmount);
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    reserveData[stage].cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      state.rate,
      uint40(reserveData[stage - 1].data.lastUpdateTimestamp)
    );

    stage = 4;
    reserveData[stage] = _getReserveData(state.reserveId);
    aliceData[stage] = _getUserData(state.reserveId, alice);
    bobData[stage] = _getUserData(state.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    reserveData[stage].cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      state.rate,
      uint40(reserveData[stage - 1].data.lastUpdateTimestamp)
    );
    uint256 expectedBaseDebt = state
      .borrowAmount
      .rayMul(reserveData[stage].cumulatedBaseInterest)
      .rayMul(reserveData[stage - 1].cumulatedBaseInterest);
    uint256 expectedPremium = (reserveData[stage].data.baseDebt -
      state.borrowAmount.rayMul(reserveData[stage - 1].cumulatedBaseInterest)).percentMul(
        reserveData[stage].data.riskPremium
      ) + reserveData[1].data.outstandingPremium;

    // reserve
    assertEq(reserveData[stage].data.baseDebt, expectedBaseDebt, 'reserveData base debt');
    assertEq(
      reserveData[stage].data.outstandingPremium,
      expectedPremium,
      'reserveData outstanding premium'
    );
    assertEq(
      reserveData[stage].data.suppliedShares,
      reserveData[1].data.suppliedShares - state.withdrawnShares,
      'reserveData supplied shares'
    );
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserveData last update timestamp'
    );

    // alice
    assertEq(aliceData[stage].data.baseDebt, expectedBaseDebt, 'aliceData base debt');
    assertEq(
      aliceData[stage].data.outstandingPremium,
      expectedPremium,
      'aliceData outstanding premium'
    );
    assertEq(
      aliceData[stage].data.suppliedShares,
      state.trivialSupplyShares,
      'aliceData supplied shares'
    );
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
      MAX_SUPPLY_AMOUNT + state.borrowAmount - state.trivialSupplyAmount,
      'alice balance'
    );
    assertEq(
      tokenList.dai.balanceOf(address(bob)),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );
  }
}
