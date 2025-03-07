// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract SpokeTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
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
    Utils.spokeSupply(spoke1, ethId, USER1, ethAmount, USER1);

    // USER2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.spokeSupply(spoke1, daiId, USER2, daiAmount, USER2);

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
    Utils.spokeSupply(spoke1, ethId, USER1, ethAmount, USER1);

    // USER2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.spokeSupply(spoke1, daiId, USER2, daiAmount, USER2);

    // USER1 borrow half of dai reserve liquidity
    Utils.borrow(spoke1, daiId, USER1, drawAmount, USER1);

    // spoke1 restore half of drawn dai liquidity
    vm.startPrank(USER1);
    IERC20(address(dai)).approve(address(hub), restoreAmount);
    vm.expectEmit(address(spoke1));
    emit Repaid(daiId, USER1, restoreAmount);
    ISpoke(address(spoke1)).repay(daiId, restoreAmount);
    vm.stopPrank();

    Spoke.UserPosition memory user1EthData = spoke1.getUserPosition(ethId, USER1);
    Spoke.UserPosition memory user2EthData = spoke1.getUserPosition(ethId, USER2);
    Spoke.UserPosition memory user1DaiData = spoke1.getUserPosition(daiId, USER1);
    Spoke.UserPosition memory user2DaiData = spoke1.getUserPosition(daiId, USER2);

    // assertEq(
    //   user1EthData.supplyShares,
    //   ILiquidityHub(address(hub)).convertToShares(ethId, ethAmount),
    //   'wrong user1 eth supply shares final balance'
    // );
    // assertEq(user1EthData.debtShares, 0, 'wrong user1 eth debt shares final balance');
    // assertEq(user2EthData.supplyShares, 0, 'wrong user2 eth supply shares final balance');
    // assertEq(user2EthData.debtShares, 0, 'wrong user2 eth debt shares final balance');

    // assertEq(user1DaiData.supplyShares, 0, 'wrong user1 dai supply shares final balance');
    // assertEq(
    //   user1DaiData.debtShares,
    //   ILiquidityHub(address(hub)).convertToShares(ethId, drawAmount - restoreAmount),
    //   'wrong user1 dai debt shares final balance'
    // );
    // assertEq(
    //   user2DaiData.supplyShares,
    //   ILiquidityHub(address(hub)).convertToShares(daiId, daiAmount),
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

    DataTypes.Reserve memory reserveData = spoke1.getReserve(daiId);

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      lt: reserveData.config.lt + 1,
      lb: reserveData.config.lb + 1,
      liquidityPremium: 0,
      borrowable: !reserveData.config.borrowable,
      collateral: !reserveData.config.collateral
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(
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
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    updateCollateral(spoke1, daiReserveId, newCollateral);

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotCollateral.selector, daiReserveId));
    ISpoke(spoke1).setUsingAsCollateral(daiReserveId, usingAsCollateral);
  }

  function test_setUsingAsCollateral() public {
    bool newCollateral = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    // ensure DAI is allowed as collateral
    updateCollateral(spoke1, spokeInfo[spoke1].dai.reserveId, newCollateral);

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, daiAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, daiAmount, bob);

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.UsingAsCollateral(spokeInfo[spoke1].dai.reserveId, bob, usingAsCollateral);
    ISpoke(spoke1).setUsingAsCollateral(spokeInfo[spoke1].dai.reserveId, usingAsCollateral);

    DataTypes.UserPosition memory userData = spoke1.getUserPosition(
      spokeInfo[spoke1].dai.reserveId,
      bob
    );
    assertEq(userData.usingAsCollateral, usingAsCollateral, 'wrong usingAsCollateral');
  }
}
