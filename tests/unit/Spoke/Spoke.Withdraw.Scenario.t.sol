// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawScenarioTest is SpokeBase {
  struct MultiUserTestState {
    IERC20 underlying;
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

  function test_withdraw_fuzz_partial_full_with_interest(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 partialWithdrawAmount,
    uint40 elapsed
  ) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    partialWithdrawAmount = bound(partialWithdrawAmount, 1, supplyAmount - 1);

    Utils.supplyCollateral({
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

    uint256 treasuryFees = hub.getSpokeSuppliedAmount(daiAssetId, address(treasurySpoke));
    uint256 interestAccrued = hub.getAssetSuppliedAmount(daiAssetId) - treasuryFees - supplyAmount;

    uint256 totalSupplied = interestAccrued + supplyAmount;
    assertApproxEqAbs(
      totalSupplied,
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob),
      1,
      'total supplied'
    );

    // Fetch supply exchange rate before partial withdraw
    uint256 supplyExRateBefore = getSupplyExRate(daiAssetId);

    // Withdraw partial supplied assets
    Utils.withdraw(spoke1, _daiReserveId(spoke1), bob, partialWithdrawAmount, bob);

    treasuryFees = hub.getSpokeSuppliedAmount(daiAssetId, address(treasurySpoke));
    interestAccrued =
      hub.getAssetSuppliedAmount(daiAssetId) -
      treasuryFees -
      (supplyAmount - partialWithdrawAmount);

    totalSupplied = interestAccrued + supplyAmount - partialWithdrawAmount;
    assertApproxEqAbs(
      totalSupplied,
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob),
      1,
      'expected supplied'
    );

    // Check supply rate monotonically increasing after partial withdraw
    _checkSupplyRateIncreasing(
      supplyExRateBefore,
      getSupplyExRate(daiAssetId),
      false,
      'after partial withdraw'
    );

    // Fetch supply exchange rate before withdraw
    supplyExRateBefore = getSupplyExRate(daiAssetId);

    // Withdraw all supplied assets
    Utils.withdraw(spoke1, _daiReserveId(spoke1), bob, type(uint256).max, bob);

    // treasury spoke withdraw fees
    withdrawLiquidityFees(daiAssetId, type(uint256).max);

    _checkSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');

    // Check supply rate monotonically increasing after withdraw
    _checkSupplyRateIncreasing(
      supplyExRateBefore,
      getSupplyExRate(daiAssetId),
      true,
      'after withdraw'
    );
  }

  // multiple users, same asset
  function test_withdraw_fuzz_all_liquidity_with_interest_multi_user(
    MultiUserFuzzParams memory params
  ) public {
    params.reserveId = bound(params.reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    params.aliceAmount = bound(params.aliceAmount, 1, MAX_SUPPLY_AMOUNT - 1);
    params.bobAmount = bound(params.bobAmount, 1, MAX_SUPPLY_AMOUNT - params.aliceAmount);
    params.skipTime[0] = bound(params.skipTime[0], 0, MAX_SKIP_TIME);
    params.skipTime[1] = bound(params.skipTime[1], 0, MAX_SKIP_TIME);
    params.borrowAmount = bound(
      params.borrowAmount,
      1,
      (params.aliceAmount + params.bobAmount) / 2
    ); // some buffer on available borrowable liquidity
    params.rate = bound(params.rate, 1, MAX_BORROW_RATE);
    _mockInterestRateBps(params.rate);

    MultiUserTestState memory state;
    (state.assetId, state.underlying) = getAssetByReserveId(spoke1, params.reserveId);

    // alice supplies reserve
    Utils.supply({
      spoke: spoke1,
      reserveId: params.reserveId,
      user: alice,
      amount: params.aliceAmount,
      onBehalfOf: alice
    });
    // bob supplies reserve
    Utils.supply({
      spoke: spoke1,
      reserveId: params.reserveId,
      user: bob,
      amount: params.bobAmount,
      onBehalfOf: bob
    });

    // carol borrows in order to increase index
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: carol,
      amount: params.borrowAmount, // highest value asset so that it is enough collateral
      onBehalfOf: carol
    });
    Utils.borrow({
      spoke: spoke1,
      reserveId: params.reserveId,
      user: carol,
      amount: params.borrowAmount,
      onBehalfOf: carol
    });

    // accrue interest
    skip(params.skipTime[0]);

    // carol repays all with interest
    state.repayAmount = spoke1.getUserTotalDebt(params.reserveId, carol);
    // deal in case carol's repayAmount exceeds default supplied amount due to interest
    deal(address(state.underlying), carol, state.repayAmount);
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
    tokenData[state.stage] = getTokenBalances(state.underlying, address(spoke1));
    uint256 supplyExRate = getSupplyExRate(state.assetId);

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

    _checkSupplyRateIncreasing(
      supplyExRate,
      getSupplyExRate(state.assetId),
      false,
      'after alice withdraw'
    );

    // skip time to accrue interest for bob
    skip(params.skipTime[1]);

    state.stage = 1;
    reserveData[state.stage] = loadReserveInfo(spoke1, params.reserveId);
    aliceData[state.stage] = loadUserInfo(spoke1, params.reserveId, alice);
    bobData[state.stage] = loadUserInfo(spoke1, params.reserveId, bob);
    tokenData[state.stage] = getTokenBalances(state.underlying, address(spoke1));
    supplyExRate = getSupplyExRate(state.assetId);

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

    _checkSupplyRateIncreasing(
      supplyExRate,
      getSupplyExRate(state.assetId),
      true,
      'after bob withdraw'
    );

    // treasury spoke withdraw fees
    withdrawLiquidityFees(state.assetId, type(uint256).max);

    state.stage = 2;
    reserveData[state.stage] = loadReserveInfo(spoke1, params.reserveId);
    aliceData[state.stage] = loadUserInfo(spoke1, params.reserveId, alice);
    bobData[state.stage] = loadUserInfo(spoke1, params.reserveId, bob);
    tokenData[state.stage] = getTokenBalances(state.underlying, address(spoke1));

    // reserve
    (uint256 reserveBaseDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(params.reserveId);
    assertEq(reserveBaseDebt, 0, 'reserveData base debt');
    assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
    assertEq(reserveData[state.stage].data.suppliedShares, 0, 'reserveData supplied shares');

    // alice
    (uint256 userBaseDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(params.reserveId, alice);
    assertEq(userBaseDebt, 0, 'aliceData base debt');
    assertEq(userPremiumDebt, 0, 'aliceData premium debt');
    assertEq(aliceData[state.stage].data.suppliedShares, 0, 'aliceData supplied shares');

    // bob
    (userBaseDebt, userPremiumDebt) = spoke1.getUserDebt(params.reserveId, bob);
    assertEq(userBaseDebt, 0, 'bobData base debt');
    assertEq(userPremiumDebt, 0, 'bobData premium debt');
    assertEq(bobData[state.stage].data.suppliedShares, 0, 'bobData supplied shares');

    // token
    assertEq(tokenData[state.stage].spokeBalance, 0, 'tokenData spoke balance');
    assertEq(tokenData[state.stage].hubBalance, 0, 'tokenData hub balance');
    assertEq(
      state.underlying.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - params.aliceAmount + aliceData[0].suppliedAmount,
      'alice balance'
    );
    assertEq(
      state.underlying.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - params.bobAmount + bobData[1].suppliedAmount,
      'bob balance'
    );
  }

  /// Let protocol have some funds initially. User deposits, immediately withdraws, check delta on share amounts
  function test_withdraw_round_trip_deposit_withdraw(
    uint256 reserveId,
    uint256 protocolStartingBalance,
    address caller,
    uint256 assets
  ) public {
    _assumeValidSupplier(caller);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    protocolStartingBalance = bound(protocolStartingBalance, 1, MAX_SUPPLY_AMOUNT - 1); // Allow some buffer from supply cap
    assets = bound(assets, 1, MAX_SUPPLY_AMOUNT - protocolStartingBalance);

    // Set up initial state of the vault by having derl supply some starting balance
    Utils.supply({
      spoke: spoke1,
      reserveId: reserveId,
      user: derl,
      amount: protocolStartingBalance,
      onBehalfOf: derl
    });

    DataTypes.Reserve memory reserve = spoke1.getReserve(reserveId);

    // Deal caller the balance to deposit, and approve hub
    deal(reserve.underlying, caller, assets);
    vm.prank(caller);
    IERC20(reserve.underlying).approve(address(hub), assets);

    // Supply and confirm share amount from event emission
    uint256 shares1 = hub.convertToSuppliedShares(reserve.assetId, assets);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(reserveId, caller, shares1);
    vm.prank(caller);
    spoke1.supply(reserveId, assets);

    // Withdraw and confirm share amount from event emission
    uint256 shares2 = hub.convertToSuppliedShares(reserve.assetId, assets);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(reserveId, caller, shares2, caller);
    vm.prank(caller);
    spoke1.withdraw(reserveId, assets, caller);

    assertEq(shares2, shares1, 'supplied and withdrawn shares');
  }

  /// Let protocol have some funds initially. Assume user has a nonzero balance to withdraw.
  /// User withdraws, then immediately deposits. Check delta on share amounts.
  function test_withdraw_round_trip_withdraw_deposit(
    uint256 reserveId,
    uint256 protocolStartingBalance,
    uint256 callerStartingBalance,
    address caller,
    uint256 assets
  ) public {
    _assumeValidSupplier(caller);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    protocolStartingBalance = bound(protocolStartingBalance, 1, MAX_SUPPLY_AMOUNT - 1); // Allow some buffer from supply cap
    assets = bound(assets, 1, MAX_SUPPLY_AMOUNT - protocolStartingBalance);
    // Caller starting balance must be at least the amount they will withdraw during test
    callerStartingBalance = bound(
      callerStartingBalance,
      assets,
      MAX_SUPPLY_AMOUNT - protocolStartingBalance
    );

    // Set up initial state of the vault by having derl supply some starting balance
    Utils.supply({
      spoke: spoke1,
      reserveId: reserveId,
      user: derl,
      amount: protocolStartingBalance,
      onBehalfOf: derl
    });

    DataTypes.Reserve memory reserve = spoke1.getReserve(reserveId);

    // Deal caller the balance they will supply, and approve hub
    deal(reserve.underlying, caller, callerStartingBalance);
    vm.prank(caller);
    IERC20(reserve.underlying).approve(address(hub), type(uint256).max);

    // Set up initial state of caller by supplying their starting balance
    Utils.supply({
      spoke: spoke1,
      reserveId: reserveId,
      user: caller,
      amount: callerStartingBalance,
      onBehalfOf: caller
    });

    // Withdraw and confirm share amount from event emission
    uint256 shares1 = hub.convertToSuppliedShares(reserve.assetId, assets);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(reserveId, caller, shares1, caller);
    vm.prank(caller);
    spoke1.withdraw(reserveId, assets, caller);

    // Supply and confirm share amount from event emission
    uint256 shares2 = hub.convertToSuppliedShares(reserve.assetId, assets);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(reserveId, caller, shares2);
    vm.prank(caller);
    spoke1.supply(reserveId, assets);

    assertEq(shares2, shares1, 'supplied and withdrawn shares');
  }
}
