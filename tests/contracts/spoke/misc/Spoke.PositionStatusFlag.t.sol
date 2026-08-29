// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokePositionStatusFlagTest is Base {
  function test_borrow_setsBorrowingFlag() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 100e18;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: borrowAmount * 10,
      onBehalfOf: bob
    });

    assertFalse(_isBorrowing(spoke1, daiReserveId, bob), 'borrow flag before borrow');

    vm.prank(bob);
    spoke1.borrow(daiReserveId, borrowAmount, bob);

    assertTrue(_isBorrowing(spoke1, daiReserveId, bob), 'borrow flag after borrow');
  }

  function test_repay_clearsBorrowingFlag() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 100e18;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: borrowAmount * 10,
      onBehalfOf: bob
    });

    vm.prank(bob);
    spoke1.borrow(daiReserveId, borrowAmount, bob);
    assertTrue(_isBorrowing(spoke1, daiReserveId, bob), 'borrow flag after borrow');

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    assertFalse(_isBorrowing(spoke1, daiReserveId, bob), 'borrow flag after full repay');
  }

  function test_setUsingAsCollateral_emitsAndUpdatesFlag() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 daiAmount = 100e18;

    deal(address(tokenList.dai), bob, daiAmount);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: daiAmount,
      onBehalfOf: bob
    });

    assertFalse(_isUsingAsCollateral(spoke1, daiReserveId, bob), 'collateral flag before enable');

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral({
      reserveId: daiReserveId,
      caller: bob,
      user: bob,
      usingAsCollateral: true
    });
    spoke1.setUsingAsCollateral(daiReserveId, true, bob);

    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, bob), 'collateral flag after enable');

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral({
      reserveId: daiReserveId,
      caller: bob,
      user: bob,
      usingAsCollateral: false
    });
    spoke1.setUsingAsCollateral(daiReserveId, false, bob);

    assertFalse(_isUsingAsCollateral(spoke1, daiReserveId, bob), 'collateral flag after disable');
  }
}
