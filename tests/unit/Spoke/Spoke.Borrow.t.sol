// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowTest is SpokeBase {
  function test_borrow() public {
    BorrowTestData memory state;

    state.daiReserveId = _daiReserveId(spoke1);
    state.wethReserveId = _wethReserveId(spoke1);

    state.daiAlice.supplyAmount = 100e18;
    state.wethBob.supplyAmount = 10e18;
    state.daiBob.borrowAmount = state.daiAlice.supplyAmount;

    // should be 0 because no realized premium yet
    state.daiBob.premiumDebtRayBefore = _calculatePremiumDebtRay(spoke1, state.daiReserveId, bob);
    state.wethBob.premiumDebtRayBefore = _calculatePremiumDebtRay(spoke1, state.wethReserveId, bob);
    state.daiAlice.premiumDebtRayBefore = _calculatePremiumDebtRay(
      spoke1,
      state.daiReserveId,
      alice
    );
    state.wethAlice.premiumDebtRayBefore = _calculatePremiumDebtRay(
      spoke1,
      state.wethReserveId,
      alice
    );

    // Bob supply weth collateral
    Utils.supplyCollateral(spoke1, state.wethReserveId, bob, state.wethBob.supplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, state.daiReserveId, alice, state.daiAlice.supplyAmount, alice);

    state.daiBob.userBalanceBefore = tokenList.dai.balanceOf(bob);
    state.wethBob.userBalanceBefore = tokenList.weth.balanceOf(bob);
    state.daiAlice.userBalanceBefore = tokenList.dai.balanceOf(alice);
    state.wethAlice.userBalanceBefore = tokenList.weth.balanceOf(alice);

    // token balance
    assertEq(state.daiBob.userBalanceBefore, MAX_SUPPLY_AMOUNT);
    assertEq(state.wethBob.userBalanceBefore, MAX_SUPPLY_AMOUNT - state.wethBob.supplyAmount);
    assertEq(state.daiAlice.userBalanceBefore, MAX_SUPPLY_AMOUNT - state.daiBob.borrowAmount);
    assertEq(state.wethAlice.userBalanceBefore, MAX_SUPPLY_AMOUNT);

    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedPremiumDebtRay: state.daiBob.premiumDebtRayBefore,
      label: 'bob dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedPremiumDebtRay: state.wethBob.premiumDebtRayBefore,
      label: 'bob weth data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedPremiumDebtRay: state.daiAlice.premiumDebtRayBefore,
      label: 'alice dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedPremiumDebtRay: state.wethAlice.premiumDebtRayBefore,
      label: 'alice weth data before'
    });

    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, state.daiBob.borrowAmount);

    // Bob draw all dai reserve liquidity
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(state.daiReserveId, bob, bob, expectedShares, state.daiBob.borrowAmount);
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.borrow(
      state.daiReserveId,
      state.daiBob.borrowAmount,
      bob
    );

    state.daiBob.userBalanceAfter = tokenList.dai.balanceOf(bob);
    state.wethBob.userBalanceAfter = tokenList.weth.balanceOf(bob);
    state.daiAlice.userBalanceAfter = tokenList.dai.balanceOf(alice);
    state.wethAlice.userBalanceAfter = tokenList.weth.balanceOf(alice);

    assertEq(returnValues.shares, expectedShares);
    assertEq(returnValues.amount, state.daiBob.borrowAmount);
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: state.daiBob.borrowAmount,
      suppliedAmount: 0,
      expectedPremiumDebtRay: state.daiBob.premiumDebtRayBefore,
      label: 'bob dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedPremiumDebtRay: state.wethBob.premiumDebtRayBefore,
      label: 'bob weth data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedPremiumDebtRay: state.daiAlice.premiumDebtRayBefore,
      label: 'alice dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedPremiumDebtRay: state.wethAlice.premiumDebtRayBefore,
      label: 'alice weth data after'
    });

    // spoke
    assertEq(
      spoke1.getReserveSuppliedShares(state.daiReserveId),
      spoke1.getUserSuppliedShares(state.daiReserveId, alice),
      'spoke dai suppliedShares'
    );
    assertEq(
      spoke1.getReserveSuppliedShares(state.wethReserveId),
      spoke1.getUserSuppliedShares(state.wethReserveId, bob),
      'spoke weth suppliedShares'
    );

    address[] memory users = new address[](1);
    users[0] = bob;
    _assertUsersAndReserveDebt(spoke1, state.daiReserveId, users, 'bob dai after');

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.borrow');
  }

  function test_borrow_fuzz_amounts(uint256 wethSupplyAmount, uint256 daiBorrowAmount) public {
    BorrowTestData memory state;

    state.wethBob.supplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    state.daiBob.borrowAmount = bound(daiBorrowAmount, 1, state.wethBob.supplyAmount); // to maintain HF
    state.daiAlice.supplyAmount = state.daiBob.borrowAmount;

    state.daiReserveId = _daiReserveId(spoke1);
    state.wethReserveId = _wethReserveId(spoke1);

    // Bob supply weth
    Utils.supplyCollateral(spoke1, state.wethReserveId, bob, state.wethBob.supplyAmount, bob);

    // Alice supply dai
    Utils.supply(spoke1, state.daiReserveId, alice, state.daiAlice.supplyAmount, alice);

    // should be 0 because no realized premium yet
    state.daiBob.premiumDebtRayBefore = _calculatePremiumDebtRay(spoke1, state.daiReserveId, bob);
    state.wethBob.premiumDebtRayBefore = _calculatePremiumDebtRay(spoke1, state.wethReserveId, bob);
    state.daiAlice.premiumDebtRayBefore = _calculatePremiumDebtRay(
      spoke1,
      state.daiReserveId,
      alice
    );
    state.wethAlice.premiumDebtRayBefore = _calculatePremiumDebtRay(
      spoke1,
      state.wethReserveId,
      alice
    );

    state.daiBob.userBalanceBefore = tokenList.dai.balanceOf(bob);
    state.wethBob.userBalanceBefore = tokenList.weth.balanceOf(bob);
    state.daiAlice.userBalanceBefore = tokenList.dai.balanceOf(alice);
    state.wethAlice.userBalanceBefore = tokenList.weth.balanceOf(alice);

    // token balance
    assertEq(state.daiBob.userBalanceBefore, MAX_SUPPLY_AMOUNT);
    assertEq(state.wethBob.userBalanceBefore, MAX_SUPPLY_AMOUNT - state.wethBob.supplyAmount);
    assertEq(state.daiAlice.userBalanceBefore, MAX_SUPPLY_AMOUNT - state.daiBob.borrowAmount);
    assertEq(state.wethAlice.userBalanceBefore, MAX_SUPPLY_AMOUNT);

    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedPremiumDebtRay: state.daiBob.premiumDebtRayBefore,
      label: 'bob dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedPremiumDebtRay: state.wethBob.premiumDebtRayBefore,
      label: 'bob weth data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedPremiumDebtRay: state.daiAlice.premiumDebtRayBefore,
      label: 'alice dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedPremiumDebtRay: state.wethAlice.premiumDebtRayBefore,
      label: 'alice weth data before'
    });

    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, state.daiBob.borrowAmount);

    // Bob draw dai
    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(state.daiReserveId, bob, bob, expectedShares, state.daiBob.borrowAmount);
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.borrow(
      state.daiReserveId,
      state.daiBob.borrowAmount,
      bob
    );

    state.daiBob.userBalanceAfter = tokenList.dai.balanceOf(bob);
    state.wethBob.userBalanceAfter = tokenList.weth.balanceOf(bob);
    state.daiAlice.userBalanceAfter = tokenList.dai.balanceOf(alice);
    state.wethAlice.userBalanceAfter = tokenList.weth.balanceOf(alice);

    assertEq(returnValues.shares, expectedShares);
    assertEq(returnValues.amount, state.daiBob.borrowAmount);

    // token balance
    assertEq(
      state.daiBob.userBalanceAfter,
      state.daiBob.userBalanceBefore + state.daiBob.borrowAmount,
      'bob dai balance after'
    );
    assertEq(
      state.wethBob.userBalanceAfter,
      state.wethBob.userBalanceBefore,
      'bob weth balance after'
    );
    assertEq(
      state.daiAlice.userBalanceAfter,
      state.daiAlice.userBalanceBefore,
      'alice dai balance after'
    );
    assertEq(
      state.wethAlice.userBalanceAfter,
      state.wethAlice.userBalanceBefore,
      'alice weth balance after'
    );

    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: state.daiBob.borrowAmount,
      suppliedAmount: 0,
      expectedPremiumDebtRay: state.daiBob.premiumDebtRayBefore,
      label: 'bob dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedPremiumDebtRay: state.wethBob.premiumDebtRayBefore,
      label: 'bob weth data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedPremiumDebtRay: state.daiAlice.premiumDebtRayBefore,
      label: 'alice dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedPremiumDebtRay: state.wethAlice.premiumDebtRayBefore,
      label: 'alice weth data after'
    });

    address[] memory users = new address[](1);
    users[0] = bob;
    _assertUsersAndReserveDebt(spoke1, state.daiReserveId, users, 'bob dai after');

    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.borrow');
    _assertHubLiquidity(hub1, wethAssetId, 'spoke1.borrow');
  }
}
