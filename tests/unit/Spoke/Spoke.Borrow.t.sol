// SPDX-License-Identifier: MIT
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
    state.daiBob.userPosBefore.realizedPremium = _calculateExpectedRealizedPremium(
      spoke1,
      state.daiReserveId,
      bob
    );
    state.wethBob.userPosBefore.realizedPremium = _calculateExpectedRealizedPremium(
      spoke1,
      state.wethReserveId,
      bob
    );
    state.daiAlice.userPosBefore.realizedPremium = _calculateExpectedRealizedPremium(
      spoke1,
      state.daiReserveId,
      alice
    );
    state.wethAlice.userPosBefore.realizedPremium = _calculateExpectedRealizedPremium(
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
      expectedRealizedPremium: state.daiBob.userPosBefore.realizedPremium,
      label: 'bob dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedRealizedPremium: state.wethBob.userPosBefore.realizedPremium,
      label: 'bob weth data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedRealizedPremium: state.daiAlice.userPosBefore.realizedPremium,
      label: 'alice dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedRealizedPremium: state.wethAlice.userPosBefore.realizedPremium,
      label: 'alice weth data before'
    });

    // Bob draw all dai reserve liquidity
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      state.daiReserveId,
      bob,
      bob,
      hub1.convertToDrawnShares(daiAssetId, state.daiBob.borrowAmount)
    );
    vm.prank(bob);
    spoke1.borrow(state.daiReserveId, state.daiBob.borrowAmount, bob);

    state.daiBob.userBalanceAfter = tokenList.dai.balanceOf(bob);
    state.wethBob.userBalanceAfter = tokenList.weth.balanceOf(bob);
    state.daiAlice.userBalanceAfter = tokenList.dai.balanceOf(alice);
    state.wethAlice.userBalanceAfter = tokenList.weth.balanceOf(alice);

    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: bob,
      debtAmount: state.daiBob.borrowAmount,
      suppliedAmount: 0,
      expectedRealizedPremium: state.daiBob.userPosBefore.realizedPremium,
      label: 'bob dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedRealizedPremium: state.wethBob.userPosBefore.realizedPremium,
      label: 'bob weth data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedRealizedPremium: state.daiAlice.userPosBefore.realizedPremium,
      label: 'alice dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedRealizedPremium: state.wethAlice.userPosBefore.realizedPremium,
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
    state.daiBob.userPosBefore.realizedPremium = _calculateExpectedRealizedPremium(
      spoke1,
      state.daiReserveId,
      bob
    );
    state.wethBob.userPosBefore.realizedPremium = _calculateExpectedRealizedPremium(
      spoke1,
      state.wethReserveId,
      bob
    );
    state.daiAlice.userPosBefore.realizedPremium = _calculateExpectedRealizedPremium(
      spoke1,
      state.daiReserveId,
      alice
    );
    state.wethAlice.userPosBefore.realizedPremium = _calculateExpectedRealizedPremium(
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
      expectedRealizedPremium: state.daiBob.userPosBefore.realizedPremium,
      label: 'bob dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedRealizedPremium: state.wethBob.userPosBefore.realizedPremium,
      label: 'bob weth data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedRealizedPremium: state.daiAlice.userPosBefore.realizedPremium,
      label: 'alice dai data before'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedRealizedPremium: state.wethAlice.userPosBefore.realizedPremium,
      label: 'alice weth data before'
    });

    // Bob draw dai
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      state.daiReserveId,
      bob,
      bob,
      hub1.convertToDrawnShares(daiAssetId, state.daiBob.borrowAmount)
    );
    vm.prank(bob);
    spoke1.borrow(state.daiReserveId, state.daiBob.borrowAmount, bob);

    state.daiBob.userBalanceAfter = tokenList.dai.balanceOf(bob);
    state.wethBob.userBalanceAfter = tokenList.weth.balanceOf(bob);
    state.daiAlice.userBalanceAfter = tokenList.dai.balanceOf(alice);
    state.wethAlice.userBalanceAfter = tokenList.weth.balanceOf(alice);

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
      expectedRealizedPremium: state.daiBob.userPosBefore.realizedPremium,
      label: 'bob dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: bob,
      debtAmount: 0,
      suppliedAmount: state.wethBob.supplyAmount,
      expectedRealizedPremium: state.wethBob.userPosBefore.realizedPremium,
      label: 'bob weth data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.daiReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: state.daiAlice.supplyAmount,
      expectedRealizedPremium: state.daiAlice.userPosBefore.realizedPremium,
      label: 'alice dai data after'
    });
    _assertUserPositionAndDebt({
      spoke: spoke1,
      reserveId: state.wethReserveId,
      user: alice,
      debtAmount: 0,
      suppliedAmount: 0,
      expectedRealizedPremium: state.wethAlice.userPosBefore.realizedPremium,
      label: 'alice weth data after'
    });

    address[] memory users = new address[](1);
    users[0] = bob;
    _assertUsersAndReserveDebt(spoke1, state.daiReserveId, users, 'bob dai after');
  }
}
