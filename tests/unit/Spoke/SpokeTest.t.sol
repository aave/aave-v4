// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';

contract SpokeTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_borrow_revertsWith_reserve_not_borrowable() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].weth.reserveId, bob, wethAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiAmount, alice);

    // set reserve not borrowable
    Utils.updateBorrowable(spoke1, spokeInfo[spoke1].dai.reserveId, false);

    // Bob draw half of dai reserve liquidity
    vm.prank(bob);
    vm.expectRevert(TestErrors.RESERVE_NOT_BORROWABLE);
    ISpoke(spoke1).borrow(spokeInfo[spoke1].dai.reserveId, daiAmount / 2, bob);
  }

  function test_borrow() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Reset account balances
    deal(address(tokenList.dai), bob, 0);
    deal(address(tokenList.weth), alice, 0);

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].weth.reserveId, bob, wethAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiAmount, alice);

    Spoke.UserConfig memory bobData = spoke1.getUser(spokeInfo[spoke1].weth.reserveId, bob);
    Spoke.UserConfig memory aliceData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, alice);

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
    emit Borrowed(spokeInfo[spoke1].dai.reserveId, daiAmount / 2, bob);
    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, daiAmount / 2, bob);

    bobData = spoke1.getUser(spokeInfo[spoke1].weth.reserveId, bob);
    aliceData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, alice);

    assertEq(
      bobData.suppliedShares,
      hub.convertToSharesDown(wethAssetId, wethAmount),
      'bob supply shares final balance'
    );
    assertEq(bobData.baseDebt, 0, 'bob base debt weth final balance');
    bobData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, bob);
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
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].weth.reserveId, bob, wethAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiAmount, alice);

    // Bob draw more than supplied dai amount
    vm.prank(bob);
    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, daiAmount + 1, bob);
  }

  function test_borrow_revertsWith_invalid_draw_amount() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].weth.reserveId, bob, wethAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiAmount, alice);

    // Bob draw 0 dai
    vm.prank(bob);
    vm.expectRevert(TestErrors.INVALID_DRAW_AMOUNT);
    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, 0, bob);
  }

  function test_borrow_fuzz_amounts(uint256 wethSupplyAmount, uint256 daiBorrowAmount) public {
    wethSupplyAmount = bound(wethSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    daiBorrowAmount = bound(daiBorrowAmount, 1, wethSupplyAmount / 2 + 1);

    // Reset account balances
    deal(address(tokenList.dai), bob, 0);
    deal(address(tokenList.weth), alice, 0);

    // Bob supply weth
    deal(address(tokenList.weth), bob, wethSupplyAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].weth.reserveId, bob, wethSupplyAmount, bob);

    // Alice supply dai
    deal(address(tokenList.dai), alice, daiBorrowAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiBorrowAmount, alice);

    Spoke.UserConfig memory bobData = spoke1.getUser(spokeInfo[spoke1].weth.reserveId, bob);
    Spoke.UserConfig memory aliceData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, alice);

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

    bobData = spoke1.getUser(spokeInfo[spoke1].weth.reserveId, bob);
    aliceData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, alice);

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

  function test_withdraw() public {
    // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // Bob supply
    deal(address(tokenList.dai), bob, amount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, bob, amount, bob);

    Spoke.UserConfig memory user1Data = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, bob);

    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-withdraw');
    // assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance pre-withdraw');
    // assertEq(dai.balanceOf(USER1), 0, 'wrong user token balance pre-withdraw');
    // assertEq(
    //   user1Data.supplyShares,
    //   ILiquidityHub(hub).convertToSharesDown(assetId, amount),
    //   'wrong user supply shares post-withdraw'
    // );
    // assertEq(user1Data.debtShares, 0, 'wrong user debt shares post-withdraw');

    vm.startPrank(bob);
    vm.expectEmit(address(spoke1));
    emit Withdrawn(spokeInfo[spoke1].dai.reserveId, amount, bob);
    spoke1.withdraw(spokeInfo[spoke1].dai.reserveId, amount, bob);
    vm.stopPrank();

    user1Data = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, bob);

    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-withdraw');
    // assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance post-withdraw');
    // assertEq(dai.balanceOf(USER1), amount, 'wrong user token balance post-withdraw');
    // assertEq(user1Data.supplyShares, 0, 'wrong user supply shares post-withdraw');
    // assertEq(user1Data.debtShares, 0, 'wrong user debt shares post-withdraw');
  }

  /* TODO: Add this test back */
  /*
  function test_repay_revertsWith_repay_exceeds_debt() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 restoreAmount = drawAmount + 1;

    // USER1 supply eth
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(hub, spoke1, ethId, USER1, ethAmount, USER1);

    // USER2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiId, USER2, daiAmount, USER2);

    // USER1 borrow half of dai reserve liquidity
    Utils.borrow(spoke1, daiId, USER1, drawAmount, USER1);

    // spoke1 restore half of drawn dai liquidity
    vm.startPrank(USER1);
    IERC20(address(dai)).approve(address(spoke1), restoreAmount);
    vm.expectRevert(TestErrors.REPAY_EXCEEDS_DEBT);
    ISpoke(address(spoke1)).repay(daiId, restoreAmount);
    vm.stopPrank();
  }
  */

  /* TODO: Add this test back */
  /*
  function test_repay() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 restoreAmount = daiAmount / 4;

    // USER1 supply eth
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(hub, spoke1, ethId, USER1, ethAmount, USER1);

    // USER2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiId, USER2, daiAmount, USER2);

    // USER1 borrow half of dai reserve liquidity
    Utils.borrow(spoke1, daiId, USER1, drawAmount, USER1);

    // spoke1 restore half of drawn dai liquidity
    vm.startPrank(USER1);
    IERC20(address(dai)).approve(address(hub), restoreAmount);
    vm.expectEmit(address(spoke1));
    emit Repaid(daiId, USER1, restoreAmount);
    ISpoke(address(spoke1)).repay(daiId, restoreAmount);
    vm.stopPrank();

    Spoke.UserConfig memory user1EthData = spoke1.getUser(ethId, USER1);
    Spoke.UserConfig memory user2EthData = spoke1.getUser(ethId, USER2);
    Spoke.UserConfig memory user1DaiData = spoke1.getUser(daiId, USER1);
    Spoke.UserConfig memory user2DaiData = spoke1.getUser(daiId, USER2);

    // assertEq(
    //   user1EthData.supplyShares,
    //   ILiquidityHub(address(hub)).convertToSharesDown(ethId, ethAmount),
    //   'wrong user1 eth supply shares final balance'
    // );
    // assertEq(user1EthData.debtShares, 0, 'wrong user1 eth debt shares final balance');
    // assertEq(user2EthData.supplyShares, 0, 'wrong user2 eth supply shares final balance');
    // assertEq(user2EthData.debtShares, 0, 'wrong user2 eth debt shares final balance');

    // assertEq(user1DaiData.supplyShares, 0, 'wrong user1 dai supply shares final balance');
    // assertEq(
    //   user1DaiData.debtShares,
    //   ILiquidityHub(address(hub)).convertToSharesDown(ethId, drawAmount - restoreAmount),
    //   'wrong user1 dai debt shares final balance'
    // );
    // assertEq(
    //   user2DaiData.supplyShares,
    //   ILiquidityHub(address(hub)).convertToSharesDown(daiId, daiAmount),
    //   'wrong user2 dai supply shares final balance'
    // );
    // assertEq(user2DaiData.debtShares, 0, 'wrong user2 dai debt shares final balance');

    // assertEq(dai.balanceOf(address(hub)), daiAmount - restoreAmount, 'wrong hub dai final balance');
    // assertEq(dai.balanceOf(USER1), drawAmount - restoreAmount, 'wrong USER1 dai final balance');
    // assertEq(dai.balanceOf(USER2), 0, 'wrong USER2 dai final balance');

    // assertEq(eth.balanceOf(address(hub)), ethAmount, 'wrong hub eth final balance');
    // assertEq(eth.balanceOf(USER1), 0, 'wrong USER1 eth final balance');
    // assertEq(eth.balanceOf(USER2), 0, 'wrong USER2 eth final balance');
  }
  */

  function test_updateReserveConfig() public {
    uint256 daiId = 0;

    Spoke.Reserve memory reserveData = spoke1.getReserve(daiId);

    Spoke.ReserveConfig memory newReserveConfig = Spoke.ReserveConfig({
      lt: reserveData.config.lt + 1,
      lb: reserveData.config.lb + 1,
      liquidityPremium: 0,
      borrowable: !reserveData.config.borrowable,
      collateral: !reserveData.config.collateral
    });
    vm.expectEmit(address(spoke1));
    emit ReserveConfigUpdated(
      daiId,
      newReserveConfig.lt,
      newReserveConfig.lb,
      newReserveConfig.liquidityPremium,
      newReserveConfig.borrowable,
      newReserveConfig.collateral
    );
    spoke1.updateReserveConfig(daiId, newReserveConfig);

    reserveData = spoke1.getReserve(daiId);

    assertEq(reserveData.config.lt, newReserveConfig.lt, 'wrong lt');
    assertEq(reserveData.config.lb, newReserveConfig.lb, 'wrong lb');
    assertEq(
      reserveData.config.liquidityPremium,
      newReserveConfig.liquidityPremium,
      'wrong liquidityPremium'
    );
    assertEq(reserveData.config.borrowable, newReserveConfig.borrowable, 'wrong borrowable');
    assertEq(reserveData.config.collateral, newReserveConfig.collateral, 'wrong collateral');
  }

  function test_setUsingAsCollateral_revertsWith_reserve_not_collateral() public {
    bool newCollateral = false;
    bool usingAsCollateral = true;
    Utils.updateCollateral(spoke1, daiAssetId, newCollateral);

    vm.prank(bob);
    vm.expectRevert(TestErrors.RESERVE_NOT_COLLATERAL);
    ISpoke(spoke1).setUsingAsCollateral(daiAssetId, usingAsCollateral);
  }

  function test_setUsingAsCollateral() public {
    bool newCollateral = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    // ensure DAI is allowed as collateral
    Utils.updateCollateral(spoke1, spokeInfo[spoke1].dai.reserveId, newCollateral);

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, daiAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, bob, daiAmount, bob);

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit UsingAsCollateral(spokeInfo[spoke1].dai.reserveId, usingAsCollateral, bob);
    ISpoke(spoke1).setUsingAsCollateral(spokeInfo[spoke1].dai.reserveId, usingAsCollateral);

    Spoke.UserConfig memory userData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, bob);
    assertEq(userData.usingAsCollateral, usingAsCollateral, 'wrong usingAsCollateral');
  }
}
