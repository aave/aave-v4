// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeWithdrawScenarioTest is SpokeBase {
  using WadRayMath for uint256;

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

  function test_withdraw_fuzz_partial_full_with_interest(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 partialWithdrawAmount,
    uint40 elapsed
  ) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    partialWithdrawAmount = bound(partialWithdrawAmount, 1, supplyAmount - 1);

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
    uint256 interestAccrued = hub.getAssetSuppliedAmount(daiAssetId) - supplyAmount;

    // Give Bob enough dai to repay
    uint256 repayAmount = spoke1.getReserveTotalDebt(_daiReserveId(spoke1));
    deal(address(tokenList.dai), bob, repayAmount);

    Utils.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: type(uint256).max
    });

    uint256 totalSupplied = supplyAmount + interestAccrued;
    assertEq(
      totalSupplied,
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob),
      'total supplied'
    );

    // Withdraw partial supplied assets
    vm.startPrank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), partialWithdrawAmount, bob);

    uint256 expectedSupplied = totalSupplied - partialWithdrawAmount;
    assertEq(
      expectedSupplied,
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob),
      'expected supplied'
    );

    // Withdraw all supplied assets
    spoke1.withdraw(_daiReserveId(spoke1), type(uint256).max, bob);

    _checkSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
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
    params.rate = bound(params.rate, 1, MAX_BORROW_RATE).bpsToRay();

    MultiUserTestState memory state;

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(params.rate)
    );

    (state.assetId, state.asset) = getAssetByReserveId(spoke1, params.reserveId);

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
    Utils.supply({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: carol,
      amount: params.borrowAmount, // highest value asset so that it is enough collateral
      onBehalfOf: carol
    });
    setUsingAsCollateral(spoke1, carol, _wbtcReserveId(spoke1), true);
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
}
