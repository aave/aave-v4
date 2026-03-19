// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeWithdrawTest is Base {
  using SafeCast for uint256;

  struct WithdrawLocal {
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
    uint256 aliceDrawnDebt;
    uint256 alicePremiumDebt;
    uint256 borrowReserveSupplyAmount;
    uint256 addExRate;
    uint256 expectedFeeAmount;
  }

  struct TestWithInterestFuzzParams {
    uint256 reserveId;
    uint256 borrowAmount;
    uint256 rate;
    uint256 borrowReserveSupplyAmount;
    uint256 skipTime;
  }

  function test_withdraw_revertsWith_ReentrancyGuardReentrantCall_hubRemove() public {
    uint256 amount = 100e18;
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount * 10,
      onBehalfOf: bob
    });

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke1),
      ISpoke.withdraw.selector
    );

    vm.mockFunction(
      address(_hub(spoke1, _daiReserveId(spoke1))),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.remove.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), amount, bob);
  }

  function test_withdraw_revertsWith_ReentrancyGuardReentrantCall_hubRefreshPremium() public {
    uint256 amount = 100e18;
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount * 10,
      onBehalfOf: bob
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke1),
      ISpoke.withdraw.selector
    );

    vm.mockFunction(
      address(_hub(spoke1, _daiReserveId(spoke1))),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.refreshPremium.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(bob);
    spoke1.withdraw(_daiReserveId(spoke1), amount, bob);
  }

  function test_withdraw_same_block() public {
    uint256 amount = 100e18;

    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, amount);

    // Bob supplies DAI
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    uint256 addExRate = _getAddExRate(hub1, daiAssetId);

    // Token assertions before withdrawal
    TokenBalances memory tokenDataBefore = _getTokenBalances(
      tokenList.dai,
      address(spoke1),
      address(hub1)
    );
    assertEq(tokenDataBefore.spokeBalance, 0, 'dai spokeBalance pre-withdraw');
    assertEq(tokenDataBefore.hubBalance, amount, 'dai hubBalance pre-withdraw');
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - amount,
      'bob dai balance pre-withdraw'
    );

    // Bob withdraws immediately in the same block
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(_daiReserveId(spoke1), bob, bob, expectedSupplyShares, amount);
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: amount,
        onBehalfOf: bob
      })
    );

    TokenBalances memory tokenDataAfter = _getTokenBalances(
      tokenList.dai,
      address(spoke1),
      address(hub1)
    );

    // Reserve assertions before withdrawal
    assertEq(r.reserveBefore.totalSuppliedAmount, amount, 'reserve addedAmount pre-withdraw');
    assertEq(
      r.reserveBefore.totalSuppliedShares,
      expectedSupplyShares,
      'reserve suppliedShares pre-withdraw'
    );

    // Bob assertions before withdrawal
    assertEq(r.ownerBefore.suppliedAmount, amount, 'bob suppliedAmount pre-withdraw');
    assertEq(r.ownerBefore.suppliedShares, expectedSupplyShares, 'bob suppliedShares pre-withdraw');

    assertEq(r.amount, amount);
    assertEq(r.shares, expectedSupplyShares);

    // Reserve assertions after withdrawal
    assertEq(r.reserveAfter.totalSuppliedAmount, 0, 'reserve addedAmount post-withdraw');
    assertEq(r.reserveAfter.totalSuppliedShares, 0, 'reserve addedShares post-withdraw');

    // Bob assertions after withdrawal
    assertEq(r.ownerAfter.suppliedAmount, 0, 'bob suppliedAmount post-withdraw');
    assertEq(r.ownerAfter.suppliedShares, 0, 'bob suppliedShares post-withdraw');

    // Token assertions after withdrawal
    assertEq(tokenDataAfter.spokeBalance, 0, 'dai spokeBalance post-withdraw');
    assertEq(tokenDataAfter.hubBalance, 0, 'dai hubBalance post-withdraw');
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT, 'bob dai balance post-withdraw');

    // Check supply rate monotonically increases after withdrawal
    _checkSupplyRateIncreasing(addExRate, _getAddExRate(hub1, daiAssetId), 'after withdraw');

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');
  }

  function test_withdraw_all_liquidity() public {
    uint256 supplyAmount = 5000e18;
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _assertSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    uint256 addExRate = _getAddExRate(hub1, daiAssetId);

    // Withdraw all supplied assets
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: UINT256_MAX,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, supplyAmount);
    assertEq(r.shares, r.ownerBefore.suppliedShares);

    _assertSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(addExRate, _getAddExRate(hub1, daiAssetId), 'after withdraw');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');
  }

  function test_withdraw_fuzz_suppliedAmount(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT_DAI);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _assertSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    uint256 addExRate = _getAddExRate(hub1, daiAssetId);

    // Withdraw all supplied assets
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: UINT256_MAX,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, supplyAmount);
    assertEq(r.shares, r.ownerBefore.suppliedShares);

    _assertSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(addExRate, _getAddExRate(hub1, daiAssetId), 'after withdraw');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');
  }

  function test_withdraw_fuzz_all_greater_than_supplied(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _assertSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    uint256 addExRate = _getAddExRate(hub1, daiAssetId);

    // Withdraw all supplied assets
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: supplyAmount + 1,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, supplyAmount);
    assertEq(r.shares, r.ownerBefore.suppliedShares);

    _assertSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(addExRate, _getAddExRate(hub1, daiAssetId), 'after withdraw');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');
  }

  function test_withdraw_fuzz_all_with_interest(uint256 supplyAmount, uint256 borrowAmount) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT_DAI);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _assertSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    // Bob borrows dai
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Wait a year to accrue interest
    skip(365 days);

    uint256 expectedFeeAmount = _calcUnrealizedFees(hub1, daiAssetId);

    // Ensure interest has accrued
    vm.assume(hub1.getAddedAssets(daiAssetId) > supplyAmount);

    // Give Bob enough dai to repay
    uint256 repayAmount = spoke1.getReserveTotalDebt(_daiReserveId(spoke1));
    deal(address(tokenList.dai), bob, repayAmount);

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    assertEq(hub1.getAsset(daiAssetId).realizedFees, expectedFeeAmount, 'realized fees');

    uint256 addExRate = _getAddExRate(hub1, daiAssetId);

    // bob withdraws all
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: UINT256_MAX,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, r.ownerBefore.suppliedAmount);
    assertEq(r.shares, r.ownerBefore.suppliedShares);

    _assertSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(addExRate, _getAddExRate(hub1, daiAssetId), 'after withdraw');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');
  }

  function test_withdraw_fuzz_all_elapsed_with_interest(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint40 elapsed
  ) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);
    elapsed = bound(elapsed, 0, MAX_SKIP_TIME).toUint40();

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });

    _assertSuppliedAmounts(
      daiAssetId,
      _daiReserveId(spoke1),
      spoke1,
      bob,
      supplyAmount,
      'after supply'
    );

    // Bob borrows dai
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Wait some time to accrue interest
    skip(elapsed);

    // Ensure interest has accrued
    vm.assume(hub1.getAddedAssets(daiAssetId) > supplyAmount);

    // Give Bob enough dai to repay
    uint256 repayAmount = spoke1.getReserveTotalDebt(_daiReserveId(spoke1));
    deal(address(tokenList.dai), bob, repayAmount);

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    uint256 addExRate = _getAddExRate(hub1, daiAssetId);

    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: UINT256_MAX,
        onBehalfOf: bob
      })
    );

    assertEq(r.amount, r.ownerBefore.suppliedAmount);
    assertEq(r.shares, r.ownerBefore.suppliedShares);

    _assertSuppliedAmounts(daiAssetId, _daiReserveId(spoke1), spoke1, bob, 0, 'after withdraw');
    _checkSupplyRateIncreasing(addExRate, _getAddExRate(hub1, daiAssetId), 'after withdraw');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');
  }

  function test_withdraw_all_liquidity_with_interest_no_premium() public {
    // set weth collateral risk to 0 for no premium contribution
    _updateCollateralRisk({spoke: spoke1, reserveId: _wethReserveId(spoke1), newCollateralRisk: 0});

    WithdrawLocal memory state;
    state.reserveId = _daiReserveId(spoke1);

    (
      ,
      ,
      state.borrowAmount,
      state.supplyShares,
      state.borrowReserveSupplyAmount
    ) = _increaseReserveIndex(spoke1, state.reserveId, _wethReserveId(spoke1), alice, bob);

    state.expectedFeeAmount = _calcUnrealizedFees(hub1, daiAssetId);

    (state.aliceDrawnDebt, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(state.alicePremiumDebt, 0, 'alice has no premium contribution to exchange rate');

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserTotalDebt(state.reserveId, alice);
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: state.reserveId,
      caller: alice,
      amount: repayAmount,
      onBehalfOf: alice
    });

    state.withdrawAmount = hub1.getSpokeAddedAssets(daiAssetId, address(spoke1));

    assertGt(
      spoke1.getUserSuppliedAssets(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );

    state.withdrawnShares = hub1.previewRemoveByAssets(daiAssetId, state.withdrawAmount);
    state.addExRate = _getAddExRate(hub1, daiAssetId);

    // withdraw all available liquidity
    // bc debt is fully repaid, bob can withdraw all supplied
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: state.reserveId,
        user: bob,
        amount: state.withdrawAmount,
        onBehalfOf: bob
      })
    );

    assertEq(hub1.getAsset(daiAssetId).realizedFees, state.expectedFeeAmount, 'realized fees');

    TokenBalances memory tokenDataAfter = _getTokenBalances(
      tokenList.dai,
      address(spoke1),
      address(hub1)
    );

    assertEq(r.amount, state.withdrawAmount);
    assertEq(r.shares, state.withdrawnShares);

    // reserve
    (uint256 reserveDrawnDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(state.reserveId);
    assertEq(reserveDrawnDebt, 0, 'reserveData drawn debt');
    assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
    assertEq(r.reserveAfter.totalSuppliedShares, 0, 'reserveData added shares');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');

    // alice
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(userDrawnDebt, 0, 'aliceData drawn debt');
    assertEq(userPremiumDebt, 0, 'aliceData premium debt');
    assertEq(
      spoke1.getUserPosition(state.reserveId, alice).suppliedShares,
      0,
      'aliceData supplied shares'
    );

    // bob
    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(state.reserveId, bob);
    assertEq(userDrawnDebt, 0, 'bobData drawn debt');
    assertEq(userPremiumDebt, 0, 'bobData premium debt');
    assertEq(r.ownerAfter.suppliedShares, 0, 'bobData supplied shares');

    // token
    assertEq(tokenDataAfter.spokeBalance, 0, 'tokenData spoke balance');
    assertEq(
      tokenDataAfter.hubBalance,
      _calculateBurntInterest(hub1, daiAssetId) + hub1.getAsset(daiAssetId).realizedFees,
      'tokenData hub balance'
    );
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
    _checkSupplyRateIncreasing(state.addExRate, _getAddExRate(hub1, daiAssetId), 'after withdraw');
  }

  function test_withdraw_fuzz_all_liquidity_with_interest_no_premium(
    TestWithInterestFuzzParams memory params
  ) public {
    params.reserveId = bound(params.reserveId, 0, spoke1.getReserveCount() - 1);
    params.borrowReserveSupplyAmount = bound(
      params.borrowReserveSupplyAmount,
      2,
      _calculateMaxSupplyAmount(spoke1, params.reserveId)
    );
    params.borrowAmount = bound(params.borrowAmount, 1, params.borrowReserveSupplyAmount / 2);
    params.rate = bound(params.rate, 1, MAX_ALLOWED_DRAWN_RATE);
    params.skipTime = bound(params.skipTime, 0, MAX_SKIP_TIME);

    _mockDrawnRateBps({irStrategy: address(irStrategy), drawnRateBps: params.rate});

    // don't borrow the collateral asset
    vm.assume(params.reserveId != _wbtcReserveId(spoke1));

    (uint256 assetId, IERC20 underlying) = _getAssetByReserveId(spoke1, params.reserveId);

    // set weth collateral risk to 0 for no premium contribution
    _updateCollateralRisk({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1), // use highest-valued asset
      newCollateralRisk: 0
    });

    WithdrawLocal memory state;
    state.reserveId = params.reserveId;
    state.collateralReserveId = _wbtcReserveId(spoke1);
    state.suppliedCollateralAmount = _calculateMaxSupplyAmount(spoke1, state.collateralReserveId); // ensure enough collateral
    state.borrowReserveSupplyAmount = params.borrowReserveSupplyAmount;
    state.borrowAmount = params.borrowAmount;
    state.rate = params.rate;
    state.timestamp = vm.getBlockTimestamp();

    (, state.supplyShares) = _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: ReserveSetupParams({
        reserveId: state.collateralReserveId,
        supplier: alice,
        supplyAmount: state.suppliedCollateralAmount,
        borrower: address(0),
        borrowAmount: 0
      }),
      borrow: ReserveSetupParams({
        reserveId: state.reserveId,
        borrowAmount: state.borrowAmount,
        supplyAmount: state.borrowReserveSupplyAmount,
        supplier: bob,
        borrower: alice
      }),
      rate: state.rate,
      isMockRate: true,
      skipTime: params.skipTime,
      irStrategy: address(irStrategy)
    });

    state.expectedFeeAmount = _calcUnrealizedFees(hub1, wbtcAssetId);

    uint256 repayAmount = spoke1.getUserTotalDebt(state.reserveId, alice);
    // deal because repayAmount may exceed default supplied amount due to interest
    deal(address(underlying), alice, repayAmount);

    vm.assume(repayAmount > state.borrowAmount);
    (, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(state.alicePremiumDebt, 0, 'alice has no premium contribution to exchange rate');

    // alice repays all with interest
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: state.reserveId,
      caller: alice,
      amount: repayAmount,
      onBehalfOf: alice
    });

    assertEq(hub1.getAsset(wbtcAssetId).realizedFees, state.expectedFeeAmount, 'realized fees');

    state.withdrawAmount = hub1.getSpokeAddedAssets(assetId, address(spoke1));

    // bob's supplied amount has grown due to index increase
    assertGt(
      spoke1.getUserSuppliedAssets(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );

    state.withdrawnShares = hub1.previewRemoveByAssets(assetId, state.withdrawAmount);
    uint256 addExRateBefore = _getAddExRate(hub1, assetId);

    // bob withdraws all
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: state.reserveId,
        user: bob,
        amount: state.withdrawAmount,
        onBehalfOf: bob
      })
    );

    TokenBalances memory tokenDataAfter = _getTokenBalances(
      underlying,
      address(spoke1),
      address(hub1)
    );

    assertEq(r.shares, state.withdrawnShares);
    assertEq(r.amount, state.withdrawAmount);

    // reserve
    {
      (uint256 reserveDrawnDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(
        state.reserveId
      );
      assertEq(reserveDrawnDebt, 0, 'reserveData drawn debt');
      assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
      assertEq(r.reserveAfter.totalSuppliedShares, 0, 'reserveData added shares');
    }

    // alice
    {
      (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
      assertEq(userDrawnDebt, 0, 'aliceData drawn debt');
      assertEq(userPremiumDebt, 0, 'aliceData premium debt');
      assertEq(
        spoke1.getUserPosition(state.reserveId, alice).suppliedShares,
        0,
        'aliceData supplied shares'
      );

      // bob
      (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(state.reserveId, bob);
      assertEq(userDrawnDebt, 0, 'bobData drawn debt');
      assertEq(userPremiumDebt, 0, 'bobData premium debt');
      assertEq(
        r.ownerAfter.suppliedShares,
        state.supplyShares - r.shares,
        'bobData supplied shares'
      );
    }

    // token
    assertEq(tokenDataAfter.spokeBalance, 0, 'tokenData spoke balance');
    assertEq(
      tokenDataAfter.hubBalance,
      _calculateBurntInterest(hub1, assetId) + hub1.getAsset(assetId).realizedFees,
      'tokenData hub balance'
    );
    assertEq(underlying.balanceOf(alice), 0, 'alice balance');
    assertEq(
      underlying.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');

    // Check supply rate monotonically increasing after withdraw
    uint256 addExRateAfter = _getAddExRate(hub1, assetId); // caching to avoid stack too deep
    _checkSupplyRateIncreasing(addExRateBefore, addExRateAfter, 'after withdraw');
  }

  function test_withdraw_all_liquidity_with_interest_with_premium() public {
    WithdrawLocal memory state;
    state.reserveId = _daiReserveId(spoke1);

    (
      ,
      ,
      state.borrowAmount,
      state.supplyShares,
      state.borrowReserveSupplyAmount
    ) = _increaseReserveIndex(spoke1, state.reserveId, _wethReserveId(spoke1), alice, bob);

    state.expectedFeeAmount = _calcUnrealizedFees(hub1, daiAssetId);

    (, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);

    assertGt(state.alicePremiumDebt, 0, 'alice has premium contribution to exchange rate');

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserTotalDebt(state.reserveId, alice);
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: state.reserveId,
      caller: alice,
      amount: repayAmount,
      onBehalfOf: alice
    });

    assertEq(hub1.getAsset(daiAssetId).realizedFees, state.expectedFeeAmount, 'realized fees');

    state.withdrawAmount = hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)); // withdraw all liquidity

    assertGt(
      spoke1.getUserSuppliedAssets(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );

    state.withdrawnShares = hub1.previewRemoveByAssets(daiAssetId, state.withdrawAmount);
    state.addExRate = _getAddExRate(hub1, daiAssetId);

    // debt is fully repaid, so bob can withdraw all supplied
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: state.reserveId,
        user: bob,
        amount: state.withdrawAmount,
        onBehalfOf: bob
      })
    );

    TokenBalances memory tokenDataAfter = _getTokenBalances(
      tokenList.dai,
      address(spoke1),
      address(hub1)
    );

    assertEq(r.shares, state.withdrawnShares);
    assertEq(r.amount, state.withdrawAmount);

    // reserve
    (uint256 reserveDrawnDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(state.reserveId);
    assertEq(reserveDrawnDebt, 0, 'reserveData drawn debt');
    assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
    assertEq(
      r.reserveAfter.totalSuppliedShares,
      r.reserveBefore.totalSuppliedShares - r.shares,
      'reserveData added shares'
    );

    // alice
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
    assertEq(userDrawnDebt, 0, 'aliceData drawn debt');
    assertEq(userPremiumDebt, 0, 'aliceData premium debt');
    assertEq(
      spoke1.getUserPosition(state.reserveId, alice).suppliedShares,
      0,
      'aliceData supplied shares'
    );

    // bob
    (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(state.reserveId, bob);
    assertEq(userDrawnDebt, 0, 'bobData drawn debt');
    assertEq(userPremiumDebt, 0, 'bobData premium debt');
    assertEq(r.ownerAfter.suppliedShares, 0, 'bobData supplied shares');

    // token
    assertEq(tokenDataAfter.spokeBalance, 0, 'tokenData spoke balance');
    assertEq(
      tokenDataAfter.hubBalance,
      _calculateBurntInterest(hub1, daiAssetId) + hub1.getAsset(daiAssetId).realizedFees,
      'tokenData hub balance'
    );
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

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');

    // Check supply rate monotonically increasing after withdraw
    _checkSupplyRateIncreasing(state.addExRate, _getAddExRate(hub1, daiAssetId), 'after withdraw');
  }

  function test_withdraw_fuzz_all_liquidity_with_interest_with_premium(
    TestWithInterestFuzzParams memory params
  ) public {
    params.reserveId = bound(params.reserveId, 0, spoke1.getReserveCount() - 1);
    params.borrowReserveSupplyAmount = bound(
      params.borrowReserveSupplyAmount,
      2,
      _calculateMaxSupplyAmount(spoke1, params.reserveId)
    );
    params.borrowAmount = bound(params.borrowAmount, 1, params.borrowReserveSupplyAmount / 2);
    params.rate = bound(params.rate, 1, MAX_ALLOWED_DRAWN_RATE);
    params.skipTime = bound(params.skipTime, 0, MAX_SKIP_TIME);

    _mockDrawnRateBps({irStrategy: address(irStrategy), drawnRateBps: params.rate});

    vm.assume(params.reserveId != _wbtcReserveId(spoke1)); // wbtc used as collateral

    (uint256 assetId, IERC20 underlying) = _getAssetByReserveId(spoke1, params.reserveId);

    WithdrawLocal memory state;
    state.reserveId = params.reserveId;
    state.collateralReserveId = _wbtcReserveId(spoke1);
    state.suppliedCollateralAmount = _calculateMaxSupplyAmount(spoke1, state.collateralReserveId); // ensure enough collateral
    state.borrowReserveSupplyAmount = params.borrowReserveSupplyAmount;
    state.borrowAmount = params.borrowAmount;
    state.rate = params.rate;
    state.timestamp = vm.getBlockTimestamp();

    (, state.supplyShares) = _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: ReserveSetupParams({
        reserveId: state.collateralReserveId,
        supplier: alice,
        supplyAmount: state.suppliedCollateralAmount,
        borrower: address(0),
        borrowAmount: 0
      }),
      borrow: ReserveSetupParams({
        reserveId: state.reserveId,
        borrowAmount: state.borrowAmount,
        supplyAmount: state.borrowReserveSupplyAmount,
        supplier: bob,
        borrower: alice
      }),
      rate: state.rate,
      isMockRate: true,
      skipTime: params.skipTime,
      irStrategy: address(irStrategy)
    });

    state.expectedFeeAmount = _calcUnrealizedFees(hub1, assetId);

    // repay all debt with interest
    uint256 repayAmount = spoke1.getUserTotalDebt(state.reserveId, alice);
    deal(address(underlying), alice, repayAmount);

    // ensure interest has accrued
    vm.assume(repayAmount > state.borrowAmount);

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: state.reserveId,
      caller: alice,
      amount: repayAmount,
      onBehalfOf: alice
    });

    assertEq(hub1.getAsset(assetId).realizedFees, state.expectedFeeAmount, 'realized fees');

    state.withdrawAmount = hub1.getSpokeAddedAssets(assetId, address(spoke1));

    (, state.alicePremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);

    assertGt(
      spoke1.getUserSuppliedAssets(state.reserveId, bob),
      state.supplyAmount,
      'supplied amount with interest'
    );
    assertEq(state.alicePremiumDebt, 0, 'alice has no premium contribution to exchange rate');

    state.withdrawnShares = hub1.previewRemoveByAssets(assetId, state.withdrawAmount);
    uint256 addExRateBefore = _getAddExRate(hub1, assetId);

    // bob withdraws all
    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: state.reserveId,
        user: bob,
        amount: state.withdrawAmount,
        onBehalfOf: bob
      })
    );

    TokenBalances memory tokenDataAfter = _getTokenBalances(
      underlying,
      address(spoke1),
      address(hub1)
    );

    assertEq(r.shares, state.withdrawnShares);
    assertEq(r.amount, state.withdrawAmount);

    // reserve
    {
      (uint256 reserveDrawnDebt, uint256 reservePremiumDebt) = spoke1.getReserveDebt(
        state.reserveId
      );
      assertEq(reserveDrawnDebt, 0, 'reserveData drawn debt');
      assertEq(reservePremiumDebt, 0, 'reserveData premium debt');
      assertEq(r.reserveAfter.totalSuppliedShares, 0, 'reserveData added shares');
    }

    // alice
    {
      (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(state.reserveId, alice);
      assertEq(userDrawnDebt, 0, 'aliceData drawn debt');
      assertEq(userPremiumDebt, 0, 'aliceData premium debt');
      assertEq(
        spoke1.getUserPosition(state.reserveId, alice).suppliedShares,
        0,
        'aliceData supplied shares'
      );

      // bob
      (userDrawnDebt, userPremiumDebt) = spoke1.getUserDebt(state.reserveId, bob);
      assertEq(userDrawnDebt, 0, 'bobData drawn debt');
      assertEq(userPremiumDebt, 0, 'bobData premium debt');
      assertEq(
        r.ownerAfter.suppliedShares,
        state.supplyShares - r.shares,
        'bobData supplied shares'
      );
    }

    // token
    assertEq(tokenDataAfter.spokeBalance, 0, 'tokenData spoke balance');
    assertEq(
      tokenDataAfter.hubBalance,
      _calculateBurntInterest(hub1, assetId) + hub1.getAsset(assetId).realizedFees,
      'tokenData hub balance'
    );
    assertEq(underlying.balanceOf(alice), 0, 'alice balance');
    assertEq(
      underlying.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - state.borrowReserveSupplyAmount + state.withdrawAmount,
      'bob balance'
    );

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');

    // Check supply rate monotonically increasing after withdraw
    uint256 addExRateAfter = _getAddExRate(hub1, assetId); // caching to avoid stack too deep
    _checkSupplyRateIncreasing(addExRateBefore, addExRateAfter, 'after withdraw');
  }

  /// withdraw an asset with existing debt, with no interest accrual the two ex rates
  /// can increase due to rounding, with interest accrual should strictly increase
  function test_fuzz_withdraw_effect_on_ex_rates(uint256 amount, uint256 delay) public {
    delay = bound(delay, 1, MAX_SKIP_TIME);
    amount = bound(amount, 2, MAX_SUPPLY_AMOUNT_DAI / 2);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      amount
    );
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    }); // bob collateral
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount / 2,
      onBehalfOf: bob
    }); // introduce debt
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    }); // alice supply

    uint256 supplyExchangeRatio = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    uint256 debtExchangeRatio = hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT);

    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: amount / 2,
      onBehalfOf: alice
    });

    assertGe(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGe(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    skip(delay); // with interest accrual, both ex rates should strictly

    assertGt(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGt(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    supplyExchangeRatio = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    debtExchangeRatio = hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT);

    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: amount / 2,
      onBehalfOf: alice
    });

    assertGe(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGe(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);
  }

  /// @dev Withdraw exceeding supplied amount withdraws everything
  function test_withdraw_max_greater_than_supplied() public {
    uint256 amount = 100e18;
    uint256 reserveId = _daiReserveId(spoke1);

    // User spoke supply
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    uint256 withdrawable = _getTotalWithdrawable(spoke1, reserveId, alice);
    assertGt(withdrawable, 0);

    uint256 addExRateBefore = _getAddExRate(hub1, daiAssetId);

    // skip time but no index increase with no borrow
    skip(365 days);
    // withdrawable remains constant
    assertEq(withdrawable, _getTotalWithdrawable(spoke1, reserveId, alice));

    CheckedWithdrawResult memory r = _checkedWithdraw(
      CheckedWithdrawParams({
        spoke: spoke1,
        reserveId: reserveId,
        user: alice,
        amount: withdrawable + 1,
        onBehalfOf: alice
      })
    );

    assertEq(r.shares, r.ownerBefore.suppliedShares);
    assertEq(r.amount, withdrawable);

    assertEq(_getTotalWithdrawable(spoke1, reserveId, alice), 0);
    _assertSuppliedAmounts(daiAssetId, reserveId, spoke1, alice, 0, 'after withdraw');

    // Check supply rate monotonically increasing after withdraw
    _checkSupplyRateIncreasing(addExRateBefore, _getAddExRate(hub1, daiAssetId), 'after withdraw');

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.withdraw');
  }
}
