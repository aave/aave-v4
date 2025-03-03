// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepayTest is SpokeBase {
  using PercentageMath for uint256;

  function test_repay_same_block() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Bob repays half of principal debt
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  function test_repay() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGe(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    // Bob repays half of principal debt
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all debt interest
  function test_repay_only_interest() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGt(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    // Bob repays interest
    uint256 daiRepayAmount = bobDaiDataBefore.baseDebt +
      bobDaiDataBefore.outstandingPremium -
      daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(bobDaiDataAfter.outstandingPremium, 0, 'bob dai outstanding premium final balance');
    assertEq(bobDaiDataAfter.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
    assertEq(
      bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all outstanding premium debt
  function test_repay_only_premium() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGt(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    // Bob repays premium
    uint256 daiRepayAmount = bobDaiDataBefore.outstandingPremium;
    assertGt(daiRepayAmount, 0); // interest is not zero

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
      bobDaiDataBefore.baseDebt,
      'bob dai debt final balance'
    );
    assertEq(bobDaiDataAfter.outstandingPremium, 0, 'bob dai outstanding premium final balance');
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all accrued base debt when outstanding premium is already repaid
  function test_repay_only_base_debt() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGt(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    // Bob repays premium
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), bobDaiDataBefore.outstandingPremium);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);

    assertEq(bobDaiDataBefore.outstandingPremium, 0);

    // Bob repays base debt
    uint256 daiRepayAmount = bobDaiDataBefore.baseDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(bobDaiDataAfter.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
    assertEq(bobDaiDataAfter.outstandingPremium, 0, 'bob dai outstanding premium final balance');
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all accrued base debt when outstanding premium is zero
  function test_repay_only_base_debt_no_premium() public {
    // update liquidity premium to zero
    updateLiquidityPremium(spoke1, wethReserveId(spoke1), 0);

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGt(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobDaiDataBefore.outstandingPremium, 0, 'bob dai outstanding premium before');

    // Bob repays base debt
    uint256 daiRepayAmount = bobDaiDataBefore.baseDebt - daiBorrowAmount;
    assertGt(daiRepayAmount, 0); // interest is not zero

    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(bobDaiDataAfter.baseDebt, daiBorrowAmount, 'bob dai base debt final balance');
    assertEq(bobDaiDataAfter.outstandingPremium, 0, 'bob dai outstanding premium final balance');
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  function test_repay_revertsWith_amount_exceeds_debt() public {
    DataTypes.UserPosition memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertEq(bobDaiData.baseDebt + bobDaiData.outstandingPremium, 0, 'bob dai debt before');

    vm.expectRevert(abi.encodeWithSelector(ISpoke.RepayAmountExceedsDebt.selector, 0));
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), 1);
  }

  function test_repay_revertsWith_amount_exceeds_debt_with_non_zero_debt() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertEq(
      bobDaiData.baseDebt + bobDaiData.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    vm.expectRevert(
      abi.encodeWithSelector(ISpoke.RepayAmountExceedsDebt.selector, daiBorrowAmount)
    );
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiBorrowAmount + 1);
  }

  /// repay all or a portion of total debt in same block
  function test_repay_same_block_fuzz_amounts(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      wethReserveId(spoke1),
      daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Bob repays
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all or a portion of total debt
  function test_repay_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      wethReserveId(spoke1),
      daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGe(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    // Bob repays
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
    vm.prank(bob);
    spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium - daiRepayAmount,
      'bob dai debt final balance'
    );
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - daiRepayAmount,
      'bob dai final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  /// repay all or a portion of debt interest
  function test_repay_fuzz_amounts_only_interest(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      wethReserveId(spoke1),
      daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGe(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    // Bob repays
    uint256 bobDaiInterest = bobDaiDataBefore.baseDebt +
      bobDaiDataBefore.outstandingPremium -
      daiBorrowAmount;
    if (bobDaiInterest == 0) {
      // not enough time travel for interest accrual
      daiRepayAmount = 0;
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
      vm.prank(bob);
      spoke1.repay(daiReserveId(spoke1), daiRepayAmount);
    } else {
      // interest is at least 1
      daiRepayAmount = bound(daiRepayAmount, 1, bobDaiInterest);
      deal(address(tokenList.dai), bob, daiRepayAmount);

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
      vm.prank(bob);
      spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

      DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(
        spoke1,
        bob,
        daiReserveId(spoke1)
      );
      DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
        spoke1,
        bob,
        wethReserveId(spoke1)
      );

      assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
      assertEq(
        bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
        bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium - daiRepayAmount,
        'bob dai debt final balance'
      );
      assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
      assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

      assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
      assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

      // repays only interest
      // it can be equal because of 1 wei rounding issue when repaying
      assertGe(bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium, daiBorrowAmount);
    }
  }

  /// repay all or a portion of outstanding premium debt
  function test_repay_fuzz_amounts_only_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      wethReserveId(spoke1),
      daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGe(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    // Bob repays
    uint256 bobDaiPremium = bobDaiDataBefore.outstandingPremium;
    if (bobDaiPremium == 0) {
      // not enough time travel for premium accrual
      daiRepayAmount = 0;
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
      vm.prank(bob);
      spoke1.repay(daiReserveId(spoke1), daiRepayAmount);
    } else {
      // interest is at least 1
      daiRepayAmount = bound(daiRepayAmount, 1, bobDaiPremium);
      deal(address(tokenList.dai), bob, daiRepayAmount);

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
      vm.prank(bob);
      spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

      DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(
        spoke1,
        bob,
        daiReserveId(spoke1)
      );
      DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
        spoke1,
        bob,
        wethReserveId(spoke1)
      );

      assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
      assertEq(
        bobDaiDataAfter.baseDebt,
        bobDaiDataBefore.baseDebt,
        'bob dai base debt final balance'
      );
      assertEq(
        bobDaiDataAfter.outstandingPremium,
        bobDaiDataBefore.outstandingPremium - daiRepayAmount,
        'bob dai outstanding premium final balance'
      );
      assertEq(
        bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
        bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium - daiRepayAmount,
        'bob dai debt final balance'
      );
      assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
      assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

      assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
      assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

      // repays only premium
      assertGe(bobDaiDataAfter.outstandingPremium, 0);
    }
  }

  /// repay all or a portion of accrued base debt when outstanding premium is already repaid
  function test_repay_fuzz_amounts_base_debt(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      wethReserveId(spoke1),
      daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGe(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );

    // Bob repays premium first if any
    if (bobDaiDataBefore.outstandingPremium > 0) {
      deal(address(tokenList.dai), bob, bobDaiDataBefore.outstandingPremium);
      vm.prank(bob);
      spoke1.repay(daiReserveId(spoke1), bobDaiDataBefore.outstandingPremium);
    }

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);

    assertEq(bobDaiDataBefore.outstandingPremium, 0);

    // Bob repays
    uint256 bobDaiBaseDebt = bobDaiDataBefore.baseDebt - daiBorrowAmount;
    if (bobDaiBaseDebt == 0) {
      // not enough time travel for premium accrual
      daiRepayAmount = 0;
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
      spoke1.repay(daiReserveId(spoke1), daiRepayAmount);
    } else {
      // interest is at least 1
      daiRepayAmount = bound(daiRepayAmount, 1, bobDaiBaseDebt);
      deal(address(tokenList.dai), bob, daiRepayAmount);

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
      vm.prank(bob);
      spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

      DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(
        spoke1,
        bob,
        daiReserveId(spoke1)
      );
      DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
        spoke1,
        bob,
        wethReserveId(spoke1)
      );

      assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
      assertEq(
        bobDaiDataAfter.baseDebt,
        bobDaiDataBefore.baseDebt - daiRepayAmount,
        'bob dai base debt final balance'
      );
      assertEq(bobDaiDataAfter.outstandingPremium, 0, 'bob dai outstanding premium final balance');
      assertEq(
        bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
        bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium - daiRepayAmount,
        'bob dai debt final balance'
      );
      assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
      assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

      assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
      assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

      // repays only base debt
      assertGe(bobDaiDataAfter.baseDebt, daiBorrowAmount);
    }
  }

  /// repay all or a portion of accrued base debt when outstanding premium is zero
  function test_repay_fuzz_amounts_base_debt_no_premium(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // update liquidity premium to zero
    updateLiquidityPremium(spoke1, wethReserveId(spoke1), 0);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      wethReserveId(spoke1),
      daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    DataTypes.UserPosition memory bobWethDataBefore = getUserInfo(
      spoke1,
      bob,
      wethReserveId(spoke1)
    );
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    assertGe(
      bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium,
      daiBorrowAmount,
      'bob dai debt before'
    );
    assertEq(bobDaiDataBefore.outstandingPremium, 0, 'bob dai outstanding premium before');

    // Bob repays
    uint256 bobDaiBaseDebt = bobDaiDataBefore.baseDebt - daiBorrowAmount;
    if (bobDaiBaseDebt == 0) {
      // not enough time travel for premium accrual
      daiRepayAmount = 0;
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
      spoke1.repay(daiReserveId(spoke1), daiRepayAmount);
    } else {
      // interest is at least 1
      daiRepayAmount = bound(daiRepayAmount, 1, bobDaiBaseDebt);
      deal(address(tokenList.dai), bob, daiRepayAmount);

      vm.expectEmit(address(spoke1));
      emit ISpoke.Repaid(daiReserveId(spoke1), bob, daiRepayAmount);
      vm.prank(bob);
      spoke1.repay(daiReserveId(spoke1), daiRepayAmount);

      DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(
        spoke1,
        bob,
        daiReserveId(spoke1)
      );
      DataTypes.UserPosition memory bobWethDataAfter = getUserInfo(
        spoke1,
        bob,
        wethReserveId(spoke1)
      );

      assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
      assertEq(
        bobDaiDataAfter.baseDebt,
        bobDaiDataBefore.baseDebt - daiRepayAmount,
        'bob dai base debt final balance'
      );
      assertEq(bobDaiDataAfter.outstandingPremium, 0, 'bob dai outstanding premium final balance');
      assertEq(
        bobDaiDataAfter.baseDebt + bobDaiDataAfter.outstandingPremium,
        bobDaiDataBefore.baseDebt + bobDaiDataBefore.outstandingPremium - daiRepayAmount,
        'bob dai debt final balance'
      );
      assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
      assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

      assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
      assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

      // repays only base debt
      assertGe(bobDaiDataAfter.baseDebt, daiBorrowAmount);
    }
  }

  struct RepayMultipleLocal {
    uint256 borrowAmount;
    uint256 repayAmount;
    DataTypes.UserPosition posBefore; // positionBefore
    DataTypes.UserPosition posAfter; // positionAfter
  }

  /// borrow and repay multiple reserves
  function test_repay_multiple_reserves_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 wethBorrowAmount,
    uint256 usdxBorrowAmount,
    uint256 wbtcBorrowAmount,
    uint256 repayPortion,
    uint40 skipTime
  ) public {
    RepayMultipleLocal memory daiInfo;
    RepayMultipleLocal memory wethInfo;
    RepayMultipleLocal memory usdxInfo;
    RepayMultipleLocal memory wbtcInfo;

    daiInfo.borrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    wethInfo.borrowAmount = bound(wethBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    usdxInfo.borrowAmount = bound(usdxBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    wbtcInfo.borrowAmount = bound(wbtcBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    repayPortion = bound(repayPortion, 0, PercentageMath.PERCENTAGE_FACTOR);

    daiInfo.repayAmount = daiInfo.borrowAmount.percentMul(repayPortion);
    wethInfo.repayAmount = wethInfo.borrowAmount.percentMul(repayPortion);
    usdxInfo.repayAmount = usdxInfo.borrowAmount.percentMul(repayPortion);
    wbtcInfo.repayAmount = wbtcInfo.borrowAmount.percentMul(repayPortion);

    // weth collateral for dai and usdx
    // wbtc collateral for weth and wbtc
    // calculate weth collateral
    {
      uint256 wethSupplyAmount = _calcMinimumCollAmount(
        spoke1,
        wethReserveId(spoke1),
        daiReserveId(spoke1),
        daiInfo.borrowAmount
      ) +
        _calcMinimumCollAmount(
          spoke1,
          wethReserveId(spoke1),
          usdxReserveId(spoke1),
          usdxInfo.borrowAmount
        );
      uint256 wbtcSupplyAmount = _calcMinimumCollAmount(
        spoke1,
        wbtcReserveId(spoke1),
        wethReserveId(spoke1),
        wethInfo.borrowAmount
      ) +
        _calcMinimumCollAmount(
          spoke1,
          wbtcReserveId(spoke1),
          wbtcReserveId(spoke1),
          wbtcInfo.borrowAmount
        );

      // Bob supply weth and wbtc
      deal(address(tokenList.weth), bob, wethSupplyAmount);
      Utils.spokeSupply(spoke1, wethReserveId(spoke1), bob, wethSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, wethReserveId(spoke1), true);
      deal(address(tokenList.wbtc), bob, wbtcSupplyAmount);
      Utils.spokeSupply(spoke1, wbtcReserveId(spoke1), bob, wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke1, bob, wbtcReserveId(spoke1), true);
    }

    // Alice supply liquidity
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), alice, daiInfo.borrowAmount, alice);
    Utils.spokeSupply(spoke1, wethReserveId(spoke1), alice, wethInfo.borrowAmount, alice);
    Utils.spokeSupply(spoke1, usdxReserveId(spoke1), alice, usdxInfo.borrowAmount, alice);
    Utils.spokeSupply(spoke1, wbtcReserveId(spoke1), alice, wbtcInfo.borrowAmount, alice);

    // Bob borrows
    Utils.spokeBorrow(spoke1, daiReserveId(spoke1), bob, daiInfo.borrowAmount, bob);
    Utils.spokeBorrow(spoke1, wethReserveId(spoke1), bob, wethInfo.borrowAmount, bob);
    Utils.spokeBorrow(spoke1, usdxReserveId(spoke1), bob, usdxInfo.borrowAmount, bob);
    Utils.spokeBorrow(spoke1, wbtcReserveId(spoke1), bob, wbtcInfo.borrowAmount, bob);

    daiInfo.posBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    wethInfo.posBefore = getUserInfo(spoke1, bob, wethReserveId(spoke1));
    usdxInfo.posBefore = getUserInfo(spoke1, bob, usdxReserveId(spoke1));
    wbtcInfo.posBefore = getUserInfo(spoke1, bob, wbtcReserveId(spoke1));

    assertEq(
      daiInfo.posBefore.baseDebt + daiInfo.posBefore.outstandingPremium,
      daiInfo.borrowAmount
    );
    assertEq(
      wethInfo.posBefore.baseDebt + wethInfo.posBefore.outstandingPremium,
      wethInfo.borrowAmount
    );
    assertEq(
      wbtcInfo.posBefore.baseDebt + wbtcInfo.posBefore.outstandingPremium,
      wbtcInfo.borrowAmount
    );
    assertEq(
      usdxInfo.posBefore.baseDebt + usdxInfo.posBefore.outstandingPremium,
      usdxInfo.borrowAmount
    );

    // Time passes
    skip(skipTime);

    daiInfo.posBefore = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    wethInfo.posBefore = getUserInfo(spoke1, bob, wethReserveId(spoke1));
    usdxInfo.posBefore = getUserInfo(spoke1, bob, usdxReserveId(spoke1));
    wbtcInfo.posBefore = getUserInfo(spoke1, bob, wbtcReserveId(spoke1));

    assertGe(
      daiInfo.posBefore.baseDebt + daiInfo.posBefore.outstandingPremium,
      daiInfo.borrowAmount
    );
    assertGe(
      wethInfo.posBefore.baseDebt + wethInfo.posBefore.outstandingPremium,
      wethInfo.borrowAmount
    );
    assertGe(
      wbtcInfo.posBefore.baseDebt + wbtcInfo.posBefore.outstandingPremium,
      wbtcInfo.borrowAmount
    );
    assertGe(
      usdxInfo.posBefore.baseDebt + usdxInfo.posBefore.outstandingPremium,
      usdxInfo.borrowAmount
    );

    // Repayments
    if (daiInfo.repayAmount > 0) {
      deal(address(tokenList.dai), bob, daiInfo.repayAmount);
      Utils.spokeRepay(spoke1, daiReserveId(spoke1), bob, daiInfo.repayAmount);
    }
    if (wethInfo.repayAmount > 0) {
      deal(address(tokenList.weth), bob, wethInfo.repayAmount);
      Utils.spokeRepay(spoke1, wethReserveId(spoke1), bob, wethInfo.repayAmount);
    }
    if (wbtcInfo.repayAmount > 0) {
      deal(address(tokenList.wbtc), bob, wbtcInfo.repayAmount);
      Utils.spokeRepay(spoke1, wbtcReserveId(spoke1), bob, wbtcInfo.repayAmount);
    }
    if (usdxInfo.repayAmount > 0) {
      deal(address(tokenList.usdx), bob, usdxInfo.repayAmount);
      Utils.spokeRepay(spoke1, usdxReserveId(spoke1), bob, usdxInfo.repayAmount);
    }

    daiInfo.posAfter = getUserInfo(spoke1, bob, daiReserveId(spoke1));
    wethInfo.posAfter = getUserInfo(spoke1, bob, wethReserveId(spoke1));
    usdxInfo.posAfter = getUserInfo(spoke1, bob, usdxReserveId(spoke1));
    wbtcInfo.posAfter = getUserInfo(spoke1, bob, wbtcReserveId(spoke1));

    // collateral remains the same
    assertEq(daiInfo.posAfter.suppliedShares, daiInfo.posBefore.suppliedShares);
    assertEq(wethInfo.posAfter.suppliedShares, wethInfo.posBefore.suppliedShares);
    assertEq(usdxInfo.posAfter.suppliedShares, usdxInfo.posBefore.suppliedShares);
    assertEq(wbtcInfo.posAfter.suppliedShares, wbtcInfo.posBefore.suppliedShares);

    // debt
    assertEq(
      daiInfo.posAfter.baseDebt + daiInfo.posAfter.outstandingPremium,
      daiInfo.posBefore.baseDebt + daiInfo.posBefore.outstandingPremium - daiInfo.repayAmount,
      'bob dai debt final balance'
    );
    assertEq(
      wethInfo.posAfter.baseDebt + wethInfo.posAfter.outstandingPremium,
      wethInfo.posBefore.baseDebt + wethInfo.posBefore.outstandingPremium - wethInfo.repayAmount,
      'bob weth debt final balance'
    );
    assertEq(
      usdxInfo.posAfter.baseDebt + usdxInfo.posAfter.outstandingPremium,
      usdxInfo.posBefore.baseDebt + usdxInfo.posBefore.outstandingPremium - usdxInfo.repayAmount,
      'bob usdx debt final balance'
    );
    assertEq(
      wbtcInfo.posAfter.baseDebt + wbtcInfo.posAfter.outstandingPremium,
      wbtcInfo.posBefore.baseDebt + wbtcInfo.posBefore.outstandingPremium - wbtcInfo.repayAmount,
      'bob wbtc debt final balance'
    );
  }

  /// todo: borrow, repay, borrow more, repay
  /// todo: multiple users repay different reserves
}
