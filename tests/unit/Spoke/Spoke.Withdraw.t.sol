// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBaseTest.t.sol';

contract SpokeWithdrawTest is SpokeBaseTest {
  using WadRayMath for uint256;

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
    uint256 amount = 100e18;
    uint256 borrowAmount = 50e18;

    // User spoke supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
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
    spoke1.withdraw({reserveId: reserveId, amount: amount - borrowAmount + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount - borrowAmount + 1, to: alice});
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
    assertEq(reserveData.baseDebt, 0, 'reserveData base debt');
    assertEq(reserveData.outstandingPremium, 0, 'reserveData outstanding premium');
    assertEq(reserveData.suppliedShares, 0, 'reserveData supplied shares');
    assertEq(reserveData.lastUpdateTimestamp, 0, 'reserveData last update timestamp');

    // alice
    assertEq(aliceData.baseDebt, 0, 'aliceData base debt');
    assertEq(aliceData.outstandingPremium, 0, 'aliceData outstanding premium');
    assertEq(aliceData.suppliedShares, 0, 'aliceData supplied shares');
    assertEq(aliceData.lastUpdateTimestamp, 0, 'aliceData last update timestamp');

    // bob
    assertEq(bobData.baseDebt, 0, 'bobData base debt');
    assertEq(bobData.outstandingPremium, 0, 'bobData outstanding premium');
    assertEq(bobData.suppliedShares, 0, 'bobData supplied shares');
    assertEq(bobData.lastUpdateTimestamp, 0, 'bobData last update timestamp');

    // token
    assertEq(tokenData.spokeBalance, 0, 'tokenData spoke balance');
    assertEq(tokenData.hubBalance, 0, 'tokenData hub balance');
    assertEq(tokenList.dai.balanceOf(address(alice)), MAX_SUPPLY_AMOUNT, 'alice balance');
    assertEq(tokenList.dai.balanceOf(address(bob)), MAX_SUPPLY_AMOUNT, 'bob balance');
  }

  struct State {
    uint256 reserveId;
    uint256 suppliedCollateralAmount;
    uint256 borrowAmount;
    uint256 timestamp;
    uint256 rate;
    uint256 withdrawAmount;
    uint256 withdrawnShares;
    uint256 trivialSupplyAmount;
    uint256 cumulatedBaseInterest;
    uint256 supplyAmount;
    uint256 supplyShares;
  }

  function test_withdraw_all_liquidity_with_interest() public {
    State memory state = State({
      reserveId: spokeInfo[spoke1].dai.reserveId,
      suppliedCollateralAmount: 100e18,
      borrowAmount: 10e18,
      timestamp: vm.getBlockTimestamp(),
      rate: uint256(10_00).bpsToRay(),
      cumulatedBaseInterest: 0,
      withdrawnShares: 0,
      trivialSupplyAmount: 1e18,
      withdrawAmount: 0,
      supplyAmount: 0,
      supplyShares: 0
    });

    (state.supplyAmount, state.supplyShares) = _increaseShareConversionIndex({
      collateral: CollateralReserve({
        reserveId: spokeInfo[spoke1].weth.reserveId,
        amount: state.suppliedCollateralAmount
      }),
      borrow: BorrowReserve({
        reserveId: state.reserveId,
        amount: state.borrowAmount,
        supplier: bob
      }),
      borrower: alice,
      rate: state.rate
    });

    TestData[4] memory reserveData;
    TestData[4] memory aliceData;
    TestData[4] memory bobData;
    TokenData[4] memory tokenData;

    uint256 stage = 0;
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    aliceData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, alice);
    bobData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
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

    stage++;
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    aliceData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, alice);
    bobData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    state.withdrawAmount = hub.getAvailableLiquidity(daiAssetId);

    assertTrue(
      spoke1.getUserSuppliedAmount(state.reserveId, bob) > state.supplyAmount,
      'supplied amount with interest'
    );

    stage++;
    state.withdrawnShares = hub.convertToShares(daiAssetId, state.withdrawAmount);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    aliceData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, alice);
    bobData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    vm.prank(bob);
    spoke1.withdraw({reserveId: state.reserveId, amount: state.withdrawAmount, to: bob});

    stage++;
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    aliceData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, alice);
    bobData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    state.cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      state.rate,
      uint40(state.timestamp)
    );

    // reserve
    assertEq(
      reserveData[stage].baseDebt,
      state.borrowAmount.rayMul(state.cumulatedBaseInterest),
      'reserveData base debt'
    );
    assertEq(reserveData[stage].outstandingPremium, 0, 'reserveData outstanding premium');
    assertEq(
      reserveData[stage].suppliedShares,
      hub.convertToShares(daiAssetId, state.borrowAmount.rayMul(state.cumulatedBaseInterest)),
      'reserveData supplied shares'
    );
    assertEq(
      reserveData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserveData last update timestamp'
    );

    // alice
    assertEq(
      aliceData[stage].baseDebt,
      state.borrowAmount.rayMul(state.cumulatedBaseInterest),
      'aliceData base debt'
    );
    assertEq(aliceData[stage].outstandingPremium, 0, 'aliceData outstanding premium');
    assertEq(
      aliceData[stage].suppliedShares,
      hub.convertToShares(daiAssetId, state.trivialSupplyAmount),
      'aliceData supplied shares'
    );
    assertEq(
      aliceData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'aliceData last update timestamp'
    );

    // bob
    assertEq(bobData[stage].baseDebt, 0, 'bobData base debt');
    assertEq(bobData[stage].outstandingPremium, 0, 'bobData outstanding premium');
    assertEq(
      bobData[stage].suppliedShares,
      state.supplyShares - state.withdrawnShares,
      'bobData supplied shares'
    );
    assertEq(
      bobData[stage].lastUpdateTimestamp,
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
      MAX_SUPPLY_AMOUNT - state.supplyAmount + state.withdrawAmount,
      'bob balance'
    );
  }

  // TODO: test_withdraw_all_liquidity_with_interest, with premium
}
