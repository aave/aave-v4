// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';

contract SpokeBorrowTest is BaseTest {
  function setUp() public override {
    super.setUp();
    super.initEnvironment();
  }

  function test_borrow_revertsWith_reserve_not_borrowable() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // set reserve not borrowable
    Utils.updateBorrowable(spoke1, daiReserveId, false);

    // Bob draw half of dai reserve liquidity
    vm.prank(bob);
    vm.expectRevert(TestErrors.RESERVE_NOT_BORROWABLE);
    spoke1.borrow(daiReserveId, daiAmount / 2, bob);
  }

  function test_borrow() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Reset account balances
    deal(address(tokenList.dai), bob, 0);
    deal(address(tokenList.weth), alice, 0);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    Spoke.UserConfig memory bobData = _getUserSpokeInfo(spoke1, bob, wethReserveId);
    Spoke.UserConfig memory aliceData = _getUserSpokeInfo(spoke1, alice, daiReserveId);

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
    emit Borrowed(daiReserveId, daiAmount / 2, bob);
    spoke1.borrow(daiReserveId, daiAmount / 2, bob);

    bobData = _getUserSpokeInfo(spoke1, bob, wethReserveId);
    aliceData = _getUserSpokeInfo(spoke1, alice, daiReserveId);

    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, wethAmount),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt weth final balance');
    bobData = spoke1.getUser(daiReserveId, bob);
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
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw more than supplied dai amount
    vm.prank(bob);
    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    spoke1.borrow(daiReserveId, daiAmount + 1, bob);
  }

  function test_borrow_revertsWith_invalid_draw_amount() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw 0 dai
    vm.prank(bob);
    vm.expectRevert(TestErrors.INVALID_DRAW_AMOUNT);
    spoke1.borrow(daiReserveId, 0, bob);
  }

  function test_borrow_fuzz_amounts(uint256 wethSupplyAmount, uint256 daiBorrowAmount) public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    daiBorrowAmount = bound(daiBorrowAmount, 1, wethSupplyAmount / 2 + 1);

    // Reset account balances
    deal(address(tokenList.dai), bob, 0);
    deal(address(tokenList.weth), alice, 0);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiBorrowAmount, alice);

    Spoke.UserConfig memory bobData = _getUserSpokeInfo(spoke1, bob, wethReserveId);
    Spoke.UserConfig memory aliceData = _getUserSpokeInfo(spoke1, alice, daiReserveId);

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
    emit Borrowed(spokeInfo[spoke1].dai.reserveId, daiBorrowAmount, bob);
    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, daiBorrowAmount, bob);

    bobData = _getUserSpokeInfo(spoke1, bob, wethReserveId);
    aliceData = _getUserSpokeInfo(spoke1, alice, daiReserveId);

    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, wethSupplyAmount),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt weth final balance');
    bobData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, bob);
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

  function test_borrow_revertsWith_draw_cap_exceeded() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 wethSupplyAmount = 100e18;
    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 drawAmount = drawCap + 1;

    _updateDrawCap(daiAssetId, address(spoke1), drawCap);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob borrow dai amount exceeding draw cap
    vm.prank(bob);
    vm.expectRevert(TestErrors.DRAW_CAP_EXCEEDED);
    spoke1.borrow(daiReserveId, drawAmount, bob);
  }

  function test_borrow_revertsWith_draw_cap_exceeded_due_to_interest() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiAmount = 100e18;
    uint256 drawCap = daiAmount;
    uint256 wethSupplyAmount = 10e18;
    uint256 drawAmount = drawCap - 1;

    _updateDrawCap(daiAssetId, address(spoke1), drawCap);

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // Bob draw dai
    Utils.spokeBorrow(spoke1, daiReserveId, bob, drawAmount, bob);

    skip(365 days);

    // Additional supply to accrue interest
    Utils.spokeSupply(spoke1, daiReserveId, bob, 1e18, bob);

    vm.expectRevert(TestErrors.DRAW_CAP_EXCEEDED);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, 1, bob);
  }
}
