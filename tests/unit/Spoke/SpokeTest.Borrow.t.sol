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

  function test_borrow_revertsWith_asset_not_active() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethAmount, bob);

    // Alice supply dai
    Utils.spokeSupply(spoke1, daiReserveId, alice, daiAmount, alice);

    // set asset not active
    _updateActive(daiAssetId, false);

    // Bob draw half of dai reserve liquidity
    vm.prank(bob);
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
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

    DataTypes.UserConfig memory bobData = _getUserSpokeInfo(spoke1, bob, wethReserveId);
    DataTypes.UserConfig memory aliceData = _getUserSpokeInfo(spoke1, alice, daiReserveId);

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

    DataTypes.UserConfig memory bobData = _getUserSpokeInfo(spoke1, bob, wethReserveId);
    DataTypes.UserConfig memory aliceData = _getUserSpokeInfo(spoke1, alice, daiReserveId);

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

  function test_borrow_fuzz_multiple_reserves(
    uint256 daiBorrowAmount,
    uint256 wethBorrowamount,
    uint256 usdxBorrowAmount,
    uint256 wbtcBorrowAmount
  ) public {
    uint256 daiReserveId = spokeInfo[spoke2].dai.reserveId;
    uint256 wethReserveId = spokeInfo[spoke2].weth.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
    uint256 wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;
    uint256 dai2ReserveId = spokeInfo[spoke2].dai2.reserveId;

    daiBorrowAmount = bound(daiBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    wethBorrowamount = bound(wethBorrowamount, 0, MAX_SUPPLY_AMOUNT / 2);
    usdxBorrowAmount = bound(usdxBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);

    // Account for dai and dai2 supply actions
    deal(address(tokenList.dai), bob, 2 * MAX_SUPPLY_AMOUNT);

    // Bob supply all reserves
    Utils.spokeSupply(spoke2, daiReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, wethReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, usdxReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, wbtcReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.spokeSupply(spoke2, dai2ReserveId, bob, MAX_SUPPLY_AMOUNT, bob);

    DataTypes.UserConfig memory bobData = _getUserSpokeInfo(spoke2, bob, daiReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(daiAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares pre-draw'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt pre-draw');
    bobData = _getUserSpokeInfo(spoke2, bob, wethReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares pre-draw'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt pre-draw');
    bobData = _getUserSpokeInfo(spoke2, bob, usdxReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(usdxAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares pre-draw'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt pre-draw');
    bobData = _getUserSpokeInfo(spoke2, bob, wbtcReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wbtcAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares pre-draw'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt pre-draw');

    // Bob borrow all reserves
    if (daiBorrowAmount > 0) {
      Utils.spokeBorrow(spoke2, daiReserveId, bob, daiBorrowAmount, bob);
    }
    if (wethBorrowamount > 0) {
      Utils.spokeBorrow(spoke2, wethReserveId, bob, wethBorrowamount, bob);
    }
    if (usdxBorrowAmount > 0) {
      Utils.spokeBorrow(spoke2, usdxReserveId, bob, usdxBorrowAmount, bob);
    }
    if (wbtcBorrowAmount > 0) {
      Utils.spokeBorrow(spoke2, wbtcReserveId, bob, wbtcBorrowAmount, bob);
    }

    bobData = _getUserSpokeInfo(spoke2, bob, daiReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(daiAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, daiBorrowAmount, 'bob base debt dai final balance');
    bobData = _getUserSpokeInfo(spoke2, bob, wethReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, wethBorrowamount, 'bob base debt weth final balance');
    bobData = _getUserSpokeInfo(spoke2, bob, usdxReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(usdxAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, usdxBorrowAmount, 'bob base debt usdx final balance');
    bobData = _getUserSpokeInfo(spoke2, bob, wbtcReserveId);
    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wbtcAssetId, MAX_SUPPLY_AMOUNT),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, wbtcBorrowAmount, 'bob base debt wbtc final balance');
  }
}
