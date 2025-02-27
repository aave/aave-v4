// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract SpokeRepayTest is Base {
  using PercentageMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_repay() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    uint256 daiRepayAmount = daiSupplyAmount / 4;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, daiBorrowAmount, bob);

    DataTypes.UserConfig memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataBefore = getUserInfo(spoke1, bob, wethReserveId);
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    assertGe(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');

    // Bob repays half of principal debt
    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId, bob, daiRepayAmount);
    spoke1.repay(daiReserveId, daiRepayAmount);

    DataTypes.UserConfig memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataAfter = getUserInfo(spoke1, bob, wethReserveId);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt,
      bobDaiDataBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
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

  function test_repay_only_interest() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    console.log(spoke1.getLiquidityPremium(wethReserveId));

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, daiBorrowAmount, bob);

    DataTypes.UserConfig memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataBefore = getUserInfo(spoke1, bob, wethReserveId);
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    console.log('after');
    console.log(
      bobDaiDataBefore.baseDebt,
      bobDaiDataBefore.outstandingPremium,
      bobDaiDataBefore.riskPremium
    );
    assertGt(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');

    // Bob repays interest
    uint256 daiRepayAmount = bobDaiDataBefore.baseDebt - daiBorrowAmount;
    assert(daiRepayAmount > 0); // interest is not zero

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId, bob, daiRepayAmount);
    spoke1.repay(daiReserveId, daiRepayAmount);

    DataTypes.UserConfig memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataAfter = getUserInfo(spoke1, bob, wethReserveId);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt,
      bobDaiDataBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
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

  // todo
  function test_repay_only_premium() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;
    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiSupplyAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, daiBorrowAmount, bob);

    DataTypes.UserConfig memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataBefore = getUserInfo(spoke1, bob, wethReserveId);
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    assertGe(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');

    // Bob repays interest
    uint256 daiRepayAmount = bobDaiDataBefore.baseDebt - daiBorrowAmount;

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId, bob, daiRepayAmount);
    spoke1.repay(daiReserveId, daiRepayAmount);

    DataTypes.UserConfig memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataAfter = getUserInfo(spoke1, bob, wethReserveId);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt,
      bobDaiDataBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
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

  function test_repay_revertsWith_amount_exceeds_debt() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;

    DataTypes.UserConfig memory bobDaiData = getUserInfo(spoke1, bob, daiReserveId);
    assertEq(bobDaiData.baseDebt, 0, 'bob dai base debt before');

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.RepayAmountExceedsDebt.selector, 0));
    spoke1.repay(daiReserveId, 1);
  }

  function test_repay_fuzz_amounts(uint256 daiBorrowAmount, uint256 daiRepayAmount) public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(wethReserveId, daiReserveId, daiBorrowAmount);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, daiBorrowAmount, bob);

    DataTypes.UserConfig memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataBefore = getUserInfo(spoke1, bob, wethReserveId);
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Bob repays
    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId, bob, daiRepayAmount);
    spoke1.repay(daiReserveId, daiRepayAmount);

    DataTypes.UserConfig memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataAfter = getUserInfo(spoke1, bob, wethReserveId);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt,
      bobDaiDataBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
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

  function test_repay_fuzz_amountsAndWait(
    uint256 daiBorrowAmount,
    uint256 daiRepayAmount,
    uint40 skipTime
  ) public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    daiRepayAmount = bound(daiRepayAmount, 1, daiBorrowAmount);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(wethReserveId, daiReserveId, daiBorrowAmount);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, daiBorrowAmount, bob);

    DataTypes.UserConfig memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataBefore = getUserInfo(spoke1, bob, wethReserveId);
    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    assertGe(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');

    // Bob repays
    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId, bob, daiRepayAmount);
    spoke1.repay(daiReserveId, daiRepayAmount);

    DataTypes.UserConfig memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataAfter = getUserInfo(spoke1, bob, wethReserveId);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(
      bobDaiDataAfter.baseDebt,
      bobDaiDataBefore.baseDebt - daiRepayAmount,
      'bob dai base debt final balance'
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

  function test_repay_fuzz_full_amount_with_interest(
    uint256 daiBorrowAmount,
    uint40 skipTime
  ) public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // calculate weth collateral
    uint256 wethSupplyAmount = _calcMinimumCollAmount(wethReserveId, daiReserveId, daiBorrowAmount);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, daiBorrowAmount, bob);

    DataTypes.UserConfig memory bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataBefore = getUserInfo(spoke1, bob, wethReserveId);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');
    assertEq(bobWethDataBefore.suppliedShares, hub.convertToShares(wethAssetId, wethSupplyAmount));
    assertEq(bobWethDataBefore.baseDebt, 0);

    // Time passes
    skip(skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, daiReserveId);
    assertGe(bobDaiDataBefore.baseDebt, daiBorrowAmount, 'bob dai base debt before');

    // Bob repays full amount
    uint256 daiRepayAmount = bobDaiDataBefore.baseDebt;
    deal(address(tokenList.dai), bob, daiRepayAmount);

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repaid(daiReserveId, bob, daiRepayAmount);
    spoke1.repay(daiReserveId, daiRepayAmount);

    DataTypes.UserConfig memory bobDaiDataAfter = getUserInfo(spoke1, bob, daiReserveId);
    DataTypes.UserConfig memory bobWethDataAfter = getUserInfo(spoke1, bob, wethReserveId);

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertEq(bobDaiDataAfter.baseDebt, 0, 'bob dai base debt final balance');
    assertEq(bobWethDataAfter.suppliedShares, bobWethDataBefore.suppliedShares);
    assertEq(bobWethDataAfter.baseDebt, bobWethDataBefore.baseDebt);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  function test_repay_invalid_amount() public {}

  function test_repay_full_amount_exact() public {}

  function test_repay_full_amount() public {}

  function test_repay_fuzz_multiple() public {}

  function test_repay_fuzz_multiple_reserves() public {}

  function _calcMinimumCollAmount(
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 debtAmount
  ) internal view returns (uint256) {
    DataTypes.Reserve memory collData = spoke1.getReserve(collReserveId);
    uint256 collPrice = oracle.getAssetPrice(collData.assetId);
    uint256 collAssetUnits = 10 ** hub.getAsset(collData.assetId).config.decimals;

    DataTypes.Reserve memory debtData = spoke1.getReserve(debtReserveId);
    uint256 debtAssetUnits = 10 ** hub.getAsset(debtData.assetId).config.decimals;
    uint256 debtPrice = oracle.getAssetPrice(debtData.assetId);

    return
      ((debtAmount * debtPrice * collAssetUnits) / (collPrice * debtAssetUnits)).percentDiv(
        collData.config.lt
      ) + 1;
  }
}
