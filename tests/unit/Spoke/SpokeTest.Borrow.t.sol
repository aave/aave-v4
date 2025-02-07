// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';

contract SpokeBorrowTest is BaseTest {
  function setUp() public override {
    super.setUp();
    super.initEnvironment();
  }

  function test_borrow_revertsWith_reserve_not_borrowable() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethAmount);
    Utils.spokeSupply(hub, spoke1, wethAssetId, bob, wethAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiAssetId, alice, daiAmount, alice);

    // set reserve not borrowable
    Utils.updateBorrowable(spoke1, daiAssetId, false);

    // Bob draw half of dai reserve liquidity
    vm.prank(bob);
    vm.expectRevert(TestErrors.RESERVE_NOT_BORROWABLE);
    ISpoke(spoke1).borrow(daiAssetId, bob, daiAmount / 2);
  }

  function test_borrow() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Reset account balances
    deal(address(tokenList.dai), bob, 0);
    deal(address(tokenList.weth), alice, 0);

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethAmount);
    Utils.spokeSupply(hub, spoke1, wethAssetId, bob, wethAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiAssetId, alice, daiAmount, alice);

    Spoke.UserConfig memory bobData = spoke1.getUser(wethAssetId, bob);
    Spoke.UserConfig memory aliceData = spoke1.getUser(daiAssetId, alice);

    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, wethAmount),
      'bob supply shares pre-draw'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt pre-draw');
    assertEq(
      aliceData.suppliedShares,
      hub.convertToSharesDown(daiAssetId, daiAmount),
      'alice supply shares pre-draw'
    );
    assertEq(aliceData.baseDebt, 0, 'alice base debt pre-draw');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance pre-draw');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'spoke2 weth balance pre-draw');
    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai balance pre-draw');
    assertEq(tokenList.weth.balanceOf(alice), 0, 'alice weth balance pre-draw');

    // Bob draw half of dai reserve liquidity
    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Borrowed(daiAssetId, bob, daiAmount / 2);
    spoke1.borrow(daiAssetId, bob, daiAmount / 2);

    bobData = spoke1.getUser(wethAssetId, bob);
    aliceData = spoke1.getUser(daiAssetId, alice);

    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, wethAmount),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt weth final balance');
    bobData = spoke1.getUser(daiAssetId, bob);
    assertEq(bobData.baseDebt, daiAmount / 2, 'bob base debt dai final balance');
    assertEq(
      aliceData.suppliedShares,
      hub.convertToSharesDown(daiAssetId, daiAmount),
      'alice supply shares final balance'
    );
    assertEq(aliceData.baseDebt, 0, 'alice base debt final');
    assertEq(tokenList.dai.balanceOf(bob), daiAmount / 2, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(alice), 0, 'alice weth final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'spoke2 weth final balance');
  }

  function test_borrow_revertsWith_not_available_liquidity() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethAmount);
    Utils.spokeSupply(hub, spoke1, wethAssetId, bob, wethAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiAssetId, alice, daiAmount, alice);

    // Bob draw more than supplied dai amount
    vm.prank(bob);
    vm.expectRevert('NOT_AVAILABLE_LIQUIDITY');
    spoke1.borrow(daiAssetId, bob, daiAmount + 1);
  }

  function test_borrow_revertsWith_invalid_draw_amount() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethAmount);
    Utils.spokeSupply(hub, spoke1, wethAssetId, bob, wethAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiAssetId, alice, daiAmount, alice);

    // Bob draw 0 dai
    vm.prank(bob);
    vm.expectRevert('INVALID_DRAW_AMOUNT');
    spoke1.borrow(daiAssetId, bob, 0);
  }

  function test_borrow_fuzz_amounts(uint256 wethSupplyAmount, uint256 daiBorrowAmount) public {
    wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    daiBorrowAmount = bound(daiBorrowAmount, 1, wethSupplyAmount / 2 + 1);

    // Reset account balances
    deal(address(tokenList.dai), bob, 0);
    deal(address(tokenList.weth), alice, 0);

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethSupplyAmount);
    Utils.spokeSupply(hub, spoke1, wethAssetId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiBorrowAmount);
    Utils.spokeSupply(hub, spoke1, daiAssetId, alice, daiBorrowAmount, alice);

    Spoke.UserConfig memory bobData = spoke1.getUser(wethAssetId, bob);
    Spoke.UserConfig memory aliceData = spoke1.getUser(daiAssetId, alice);

    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, wethSupplyAmount),
      'bob supply shares pre-draw'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt pre-draw');
    assertEq(
      aliceData.suppliedShares,
      hub.convertToSharesDown(daiAssetId, daiBorrowAmount),
      'alice supply shares pre-draw'
    );
    assertEq(aliceData.baseDebt, 0, 'alice base debt pre-draw');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance pre-draw');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'spoke2 weth balance pre-draw');
    assertEq(tokenList.dai.balanceOf(bob), 0, 'bob dai balance pre-draw');
    assertEq(tokenList.weth.balanceOf(alice), 0, 'alice weth balance pre-draw');

    // Bob draw dai
    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Borrowed(daiAssetId, bob, daiBorrowAmount);
    spoke1.borrow(daiAssetId, bob, daiBorrowAmount);

    bobData = spoke1.getUser(wethAssetId, bob);
    aliceData = spoke1.getUser(daiAssetId, alice);

    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, wethSupplyAmount),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt weth final balance');
    bobData = spoke1.getUser(daiAssetId, bob);
    assertEq(bobData.baseDebt, daiBorrowAmount, 'bob base debt dai final balance');
    assertEq(
      aliceData.suppliedShares,
      hub.convertToSharesDown(daiAssetId, daiBorrowAmount),
      'alice supply shares final balance'
    );
    assertEq(aliceData.baseDebt, 0, 'alice base debt final');
    assertEq(tokenList.dai.balanceOf(bob), daiBorrowAmount, 'bob dai final balance');
    assertEq(tokenList.weth.balanceOf(alice), 0, 'alice weth final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'spoke2 weth final balance');
  }
}
