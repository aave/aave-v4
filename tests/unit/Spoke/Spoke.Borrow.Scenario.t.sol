// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowScenarioTest is SpokeBase {
  using WadRayMath for uint256;
  using SafeCast for uint256;

  /// fuzz - 2 users borrowing 2 assets from 1 spoke
  function test_borrow_fuzz_single_spoke_multi_reserves_multi_user(
    uint256 daiBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 daiBorrowAmount2,
    uint256 usdxBorrowAmount2
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 4);
    usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 4);
    daiBorrowAmount2 = bound(daiBorrowAmount2, 0, MAX_SUPPLY_AMOUNT / 4);
    usdxBorrowAmount2 = bound(usdxBorrowAmount2, 0, MAX_SUPPLY_AMOUNT / 4);

    BorrowTestData memory state;

    state.daiReserveId = _daiReserveId(spoke1);
    state.usdxReserveId = _usdxReserveId(spoke1);
    state.wethReserveId = _wethReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // should be 0 because no realized premium yet
    state.daiAlice.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.daiReserveId,
      alice
    );
    state.usdxAlice.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.usdxReserveId,
      alice
    );
    state.daiBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.daiReserveId,
      bob
    );
    state.usdxBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.usdxReserveId,
      bob
    );

    state.wethAlice.supplyAmount = state.wbtcAlice.supplyAmount = state.wethBob.supplyAmount = state
      .wbtcBob
      .supplyAmount = MAX_SUPPLY_AMOUNT / 2;

    // Alice supply collateral through spoke1
    Utils.supplyCollateral(spoke1, state.wethReserveId, alice, state.wethAlice.supplyAmount, alice);
    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.wbtcAlice.supplyAmount, alice);
    // Bob supply collateral through spoke1
    Utils.supplyCollateral(spoke1, state.wethReserveId, bob, state.wethBob.supplyAmount, bob);
    Utils.supplyCollateral(spoke1, state.wbtcReserveId, bob, state.wbtcBob.supplyAmount, bob);

    // supply enough available liquidity, at least >= 1
    _openSupplyPosition(spoke1, state.daiReserveId, daiBorrowAmount + daiBorrowAmount2 + 1);
    _openSupplyPosition(spoke1, state.usdxReserveId, usdxBorrowAmount + usdxBorrowAmount2 + 1);

    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedRealizedPremiumRay: state.daiAlice.userPosBefore.realizedPremiumRay,
      label: 'alice dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.usdxReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.usdxAlice.supplyAmount,
      expectedRealizedPremiumRay: state.usdxAlice.userPosBefore.realizedPremiumRay,
      label: 'alice usdx data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.daiBob.supplyAmount,
      expectedRealizedPremiumRay: state.daiBob.userPosBefore.realizedPremiumRay,
      label: 'bob dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.usdxReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.usdxBob.supplyAmount,
      expectedRealizedPremiumRay: state.usdxBob.userPosBefore.realizedPremiumRay,
      label: 'bob usdx data before'
    });

    // Alice borrow all reserves
    if (daiBorrowAmount > 0) {
      assertGt(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      Utils.borrow(spoke1, state.daiReserveId, alice, daiBorrowAmount, alice);
    }
    if (usdxBorrowAmount > 0) {
      assertGt(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      Utils.borrow(spoke1, state.usdxReserveId, alice, usdxBorrowAmount, alice);
    }
    // Bob borrow all reserves
    if (daiBorrowAmount2 > 0) {
      assertGt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      Utils.borrow(spoke1, state.daiReserveId, bob, daiBorrowAmount2, bob);
    }
    if (usdxBorrowAmount2 > 0) {
      assertGt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      Utils.borrow(spoke1, state.usdxReserveId, bob, usdxBorrowAmount2, bob);
    }

    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: daiBorrowAmount,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedRealizedPremiumRay: state.daiAlice.userPosBefore.realizedPremiumRay,
      label: 'alice dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.usdxReserveId,
      user: alice,
      debtAmount: usdxBorrowAmount,
      suppliedAmount: state.usdxAlice.supplyAmount,
      expectedRealizedPremiumRay: state.usdxAlice.userPosBefore.realizedPremiumRay,
      label: 'alice usdx data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: daiBorrowAmount2,
      suppliedAmount: state.daiBob.supplyAmount,
      expectedRealizedPremiumRay: state.daiBob.userPosBefore.realizedPremiumRay,
      label: 'bob dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.usdxReserveId,
      user: bob,
      debtAmount: usdxBorrowAmount2,
      suppliedAmount: state.usdxBob.supplyAmount,
      expectedRealizedPremiumRay: state.usdxBob.userPosBefore.realizedPremiumRay,
      label: 'bob usdx data after'
    });

    address[] memory users = new address[](2);
    users[0] = alice;
    users[1] = bob;

    _assertUsersAndReserveDebt(spoke1, state.daiReserveId, users, 'dai total after');
    _assertUsersAndReserveDebt(spoke1, state.usdxReserveId, users, 'usdx total after');
  }

  /// fuzz - 1 user borrowing 4 assets from 1 spoke
  function test_borrow_fuzz_single_spoke_multi_reserves(
    uint256 daiBorrowAmount,
    uint256 wethBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 wbtcBorrowAmount
  ) public {
    BorrowTestData memory state;

    state.daiReserveId = _daiReserveId(spoke2);
    state.wethReserveId = _wethReserveId(spoke2);
    state.usdxReserveId = _usdxReserveId(spoke2);
    state.wbtcReserveId = _wbtcReserveId(spoke2);

    daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    wethBorrowAmount = bound(wethBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);

    // should be 0 because no realized premium yet
    state.daiBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.daiReserveId,
      bob
    );
    state.wethBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.wethReserveId,
      bob
    );
    state.usdxBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.usdxReserveId,
      bob
    );
    state.wbtcBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.wbtcReserveId,
      bob
    );

    state.daiBob.supplyAmount = state.wethBob.supplyAmount = state.usdxBob.supplyAmount = state
      .wbtcBob
      .supplyAmount = MAX_SUPPLY_AMOUNT;

    // Bob supply all reserves as collateral
    Utils.supplyCollateral(spoke2, state.daiReserveId, bob, state.daiBob.supplyAmount, bob);
    Utils.supplyCollateral(spoke2, state.wethReserveId, bob, state.wethBob.supplyAmount, bob);
    Utils.supplyCollateral(spoke2, state.usdxReserveId, bob, state.usdxBob.supplyAmount, bob);
    Utils.supplyCollateral(spoke2, state.wbtcReserveId, bob, state.wbtcBob.supplyAmount, bob);

    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.daiBob.supplyAmount,
      expectedRealizedPremiumRay: state.daiBob.userPosBefore.realizedPremiumRay,
      label: 'bob dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedRealizedPremiumRay: state.wethBob.userPosBefore.realizedPremiumRay,
      label: 'bob weth data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: state.usdxReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.usdxBob.supplyAmount,
      expectedRealizedPremiumRay: state.usdxBob.userPosBefore.realizedPremiumRay,
      label: 'bob usdx data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: state.wbtcReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wbtcBob.supplyAmount,
      expectedRealizedPremiumRay: state.wbtcBob.userPosBefore.realizedPremiumRay,
      label: 'bob wbtc data before'
    });

    // Bob borrow all reserves
    if (daiBorrowAmount > 0) {
      assertGt(_getUserHealthFactor(spoke2, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      Utils.borrow(spoke2, state.daiReserveId, bob, daiBorrowAmount, bob);
    }
    if (wethBorrowAmount > 0) {
      assertGt(_getUserHealthFactor(spoke2, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      Utils.borrow(spoke2, state.wethReserveId, bob, wethBorrowAmount, bob);
    }
    if (usdxBorrowAmount > 0) {
      assertGt(_getUserHealthFactor(spoke2, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      Utils.borrow(spoke2, state.usdxReserveId, bob, usdxBorrowAmount, bob);
    }
    if (wbtcBorrowAmount > 0) {
      assertGt(_getUserHealthFactor(spoke2, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      Utils.borrow(spoke2, state.wbtcReserveId, bob, wbtcBorrowAmount, bob);
    }

    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: daiBorrowAmount,
      suppliedAmount: state.daiBob.supplyAmount,
      expectedRealizedPremiumRay: state.daiBob.userPosBefore.realizedPremiumRay,
      label: 'bob dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: wethBorrowAmount,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedRealizedPremiumRay: state.wethBob.userPosBefore.realizedPremiumRay,
      label: 'bob weth data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: state.usdxReserveId,
      user: bob,
      debtAmount: usdxBorrowAmount,
      suppliedAmount: state.usdxBob.supplyAmount,
      expectedRealizedPremiumRay: state.usdxBob.userPosBefore.realizedPremiumRay,
      label: 'bob usdx data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: state.wbtcReserveId,
      user: bob,
      debtAmount: wbtcBorrowAmount,
      suppliedAmount: state.wbtcBob.supplyAmount,
      expectedRealizedPremiumRay: state.wbtcBob.userPosBefore.realizedPremiumRay,
      label: 'bob wbtc data after'
    });

    address[] memory user = new address[](1);
    user[0] = bob;

    _assertUsersAndReserveDebt(spoke2, state.daiReserveId, user, 'bob dai after');
    _assertUsersAndReserveDebt(spoke2, state.wethReserveId, user, 'bob weth after');
    _assertUsersAndReserveDebt(spoke2, state.usdxReserveId, user, 'bob usdx after');
    _assertUsersAndReserveDebt(spoke2, state.wbtcReserveId, user, 'bob wbtc after');
  }

  /// 1 user borrowing 2 assets across 2 different spokes
  function test_borrow_fuzz_multi_spoke_multi_reserves(
    uint256 daiBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 daiBorrowAmount2,
    uint256 usdxBorrowAmount2,
    uint256 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 4);
    usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 4);
    daiBorrowAmount2 = bound(daiBorrowAmount2, 0, MAX_SUPPLY_AMOUNT / 4);
    usdxBorrowAmount2 = bound(usdxBorrowAmount2, 0, MAX_SUPPLY_AMOUNT / 4);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME);

    BorrowTestData[2] memory states; // 2 spokes involved

    states[0].daiReserveId = _daiReserveId(spoke1);
    states[0].usdxReserveId = _usdxReserveId(spoke1);
    states[1].daiReserveId = _daiReserveId(spoke2);
    states[1].usdxReserveId = _usdxReserveId(spoke2);

    // should be 0 because no realized premium yet
    states[0].daiBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      states[0].daiReserveId,
      bob
    );
    states[0].usdxBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      states[0].usdxReserveId,
      bob
    );
    states[1].daiBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke2,
      states[1].daiReserveId,
      bob
    );
    states[1].usdxBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke2,
      states[1].usdxReserveId,
      bob
    );

    uint256 supplyAmount = MAX_SUPPLY_AMOUNT / 2;

    // Bob supply collateralthrough spoke1
    Utils.supplyCollateral(spoke1, states[0].daiReserveId, bob, supplyAmount, bob);
    Utils.supplyCollateral(spoke1, states[0].usdxReserveId, bob, supplyAmount, bob);
    // Bob supply collateral through spoke1
    Utils.supplyCollateral(spoke2, states[1].daiReserveId, bob, supplyAmount, bob);
    Utils.supplyCollateral(spoke2, states[1].usdxReserveId, bob, supplyAmount, bob);

    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: states[0].daiReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: supplyAmount,
      expectedRealizedPremiumRay: states[0].daiBob.userPosBefore.realizedPremiumRay,
      label: 'spoke1 bob dai before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: states[0].usdxReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: supplyAmount,
      expectedRealizedPremiumRay: states[0].usdxBob.userPosBefore.realizedPremiumRay,
      label: 'spoke1 bob usdx before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: states[1].daiReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: supplyAmount,
      expectedRealizedPremiumRay: states[1].daiBob.userPosBefore.realizedPremiumRay,
      label: 'spoke2 bob dai before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: states[1].usdxReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: supplyAmount,
      expectedRealizedPremiumRay: states[1].usdxBob.userPosBefore.realizedPremiumRay,
      label: 'spoke2 bob usdx before'
    });

    // Bob borrow all reserves
    if (daiBorrowAmount > 0) {
      assertGt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      vm.prank(bob);
      spoke1.borrow(states[0].daiReserveId, daiBorrowAmount, bob);
    }
    if (usdxBorrowAmount > 0) {
      assertGt(_getUserHealthFactor(spoke1, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      vm.prank(bob);
      spoke1.borrow(states[0].usdxReserveId, usdxBorrowAmount, bob);
    }
    if (daiBorrowAmount2 > 0) {
      assertGt(_getUserHealthFactor(spoke2, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      vm.prank(bob);
      spoke2.borrow(states[1].daiReserveId, daiBorrowAmount2, bob);
    }
    if (usdxBorrowAmount2 > 0) {
      assertGt(_getUserHealthFactor(spoke2, bob), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      vm.prank(bob);
      spoke2.borrow(states[1].usdxReserveId, usdxBorrowAmount2, bob);
    }

    // spoke1
    // dai
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: states[0].daiReserveId,
      user: bob,
      debtAmount: daiBorrowAmount,
      suppliedAmount: supplyAmount,
      expectedRealizedPremiumRay: states[0].daiBob.userPosBefore.realizedPremiumRay,
      label: 'spoke1 bob dai after'
    });
    // usdx
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: states[0].usdxReserveId,
      user: bob,
      debtAmount: usdxBorrowAmount,
      suppliedAmount: supplyAmount,
      expectedRealizedPremiumRay: states[0].usdxBob.userPosBefore.realizedPremiumRay,
      label: 'spoke1 bob usdx after'
    });

    // spoke2
    // dai
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: states[1].daiReserveId,
      user: bob,
      debtAmount: daiBorrowAmount2,
      suppliedAmount: supplyAmount,
      expectedRealizedPremiumRay: states[1].daiBob.userPosBefore.realizedPremiumRay,
      label: 'spoke2 bob dai after'
    });
    // usdx
    _assertUserPositionAndDebt({
      spoke: spoke2,
      reserveId: states[1].usdxReserveId,
      user: bob,
      debtAmount: usdxBorrowAmount2,
      suppliedAmount: supplyAmount,
      expectedRealizedPremiumRay: states[1].usdxBob.userPosBefore.realizedPremiumRay,
      label: 'spoke2 bob usdx after'
    });

    address[] memory users = new address[](1);
    users[0] = bob;

    // user accounting should match reserve accounting
    _assertUsersAndReserveDebt(spoke1, states[0].daiReserveId, users, 'spoke1 bob dai after');
    _assertUsersAndReserveDebt(spoke1, states[0].usdxReserveId, users, 'spoke1 bob usdx after');
    _assertUsersAndReserveDebt(spoke2, states[1].daiReserveId, users, 'spoke2 bob dai after');
    _assertUsersAndReserveDebt(spoke2, states[1].usdxReserveId, users, 'spoke2 bob usdx after');
  }

  function test_borrow_skip_borrow() public {
    test_borrow_fuzz_skip_borrow(10e18, 20e18, 365 days);
  }

  function test_borrow_fuzz_skip_borrow(
    uint256 borrowAmount1,
    uint256 borrowAmount2,
    uint256 skipTime
  ) public {
    borrowAmount1 = bound(borrowAmount1, 1, MAX_SUPPLY_AMOUNT_DAI / 4);
    borrowAmount2 = bound(borrowAmount2, 1, MAX_SUPPLY_AMOUNT_DAI / 4);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME);

    BorrowTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wethBob.supplyAmount = MAX_SUPPLY_AMOUNT;
    state.daiBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.daiReserveId,
      bob
    );

    address[] memory users = new address[](1);
    users[0] = bob;

    _openSupplyPosition(spoke1, state.daiReserveId, MAX_SUPPLY_AMOUNT_DAI);

    // Bob supply weth as collateral
    Utils.supplyCollateral(spoke1, state.wethReserveId, bob, state.wethBob.supplyAmount, bob);

    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, borrowAmount1);

    // Bob borrow dai
    TestReturnValues memory returnValues;
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.borrow(
      state.daiReserveId,
      borrowAmount1,
      bob
    );

    // assertions
    assertEq(returnValues.shares, expectedShares);
    assertEq(returnValues.amount, borrowAmount1);
    _assertUsersAndReserveDebt(spoke1, state.daiReserveId, users, 'spoke1 bob dai after');
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: borrowAmount1,
      suppliedAmount: 0,
      expectedRealizedPremiumRay: state.daiBob.userPosBefore.realizedPremiumRay,
      label: 'bob dai data after borrow1'
    });

    state.daiBob.userPosBefore = spoke1.getUserPosition(state.daiReserveId, bob);
    uint40 lastTimestamp = vm.getBlockTimestamp().toUint40();
    (uint256 drawnDebt, ) = spoke1.getUserDebt(state.daiReserveId, bob);

    skip(skipTime);

    uint256 cumulatedInterest = MathUtils.calculateLinearInterest(
      hub1.getAsset(daiAssetId).drawnRate,
      lastTimestamp
    );
    uint256 expectedDrawnDebt = cumulatedInterest.rayMulUp(borrowAmount1) + borrowAmount2;

    // calculate expected realized premium prior to action
    state.daiBob.userPosBefore.realizedPremiumRay = _calculateExpectedRealizedPremiumRay(
      spoke1,
      state.daiReserveId,
      bob
    );
    _assertRealizedPremiumCalcMatchesNaive(
      spoke1,
      state.daiReserveId,
      drawnDebt,
      state.daiBob.userPosBefore,
      lastTimestamp
    );

    uint256 expectedShares2 = hub1.previewRestoreByAssets(daiAssetId, borrowAmount2);

    // Bob borrow more dai
    TestReturnValues memory returnValues2;
    vm.prank(bob);
    (returnValues2.shares, returnValues2.amount) = spoke1.borrow(
      state.daiReserveId,
      borrowAmount2,
      bob
    );

    (drawnDebt, ) = spoke1.getUserDebt(state.daiReserveId, bob);
    // check that accrued drawn debt matches expected
    assertApproxEqAbs(drawnDebt, expectedDrawnDebt, 3, 'drawn debt after borrow2');

    // assertions for 2nd borrow
    assertApproxEqAbs(returnValues2.shares, expectedShares2, 1);
    assertEq(returnValues2.amount, borrowAmount2);
    _assertUsersAndReserveDebt(spoke1, state.daiReserveId, users, 'spoke1 bob dai after');
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: drawnDebt,
      suppliedAmount: state.daiBob.supplyAmount,
      expectedRealizedPremiumRay: state.daiBob.userPosBefore.realizedPremiumRay,
      label: 'bob dai data after'
    });
  }

  function test_userAccountData_does_not_include_zero_cf_collateral() public {
    uint256 coll1ReserveId = _daiReserveId(spoke1);
    uint256 coll1Amount = 1000e18;
    uint256 coll2ReserveId = _wethReserveId(spoke1);
    uint256 coll2Amount = 1e18;
    uint256 debtReserveId = _usdxReserveId(spoke1);
    uint256 debtBorrowAmount = 500e6;

    _updateCollateralFactor(spoke1, coll1ReserveId, 0);
    assertEq(_getCollateralFactor(spoke1, coll1ReserveId), 0); // initially
    assertNotEq(_getCollateralFactor(spoke1, coll2ReserveId), 0);

    uint256 coll2Value = _getValue(spoke1, coll2ReserveId, coll2Amount);

    Utils.supplyCollateral(spoke1, coll1ReserveId, alice, coll1Amount, alice);
    Utils.supplyCollateral(spoke1, coll2ReserveId, alice, coll2Amount, alice);
    _openSupplyPosition(spoke1, debtReserveId, debtBorrowAmount);
    Utils.borrow(spoke1, debtReserveId, alice, debtBorrowAmount, alice);

    ISpoke.UserAccountData memory userAccountData = spoke1.getUserAccountData(alice);
    assertEq(_calculateExpectedUserRP(spoke1, alice), userAccountData.riskPremium);
    assertEq(coll2Value, userAccountData.totalCollateralValue); // coll1 is not included
  }
}
