// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';

contract SpokeTest_ToMigrate is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    vm.skip(true, 'pending spoke migration');

    super.setUp();

    address[] memory spokes = new address[](2);
    spokes[0] = address(spoke1);
    spokes[1] = address(spoke2);
    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    spokeConfigs[1] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });

    Spoke.ReserveConfig[] memory reserveConfigs = new Spoke.ReserveConfig[](2);

    // Add dai
    uint256 daiAssetId = 0;

    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({lt: 0.8e4, lb: 0, borrowable: true, collateral: true});

    Utils.addAssetAndSpokes(
      hub,
      address(dai),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(daiAssetId, 1e8);

    // Add eth
    uint256 ethAssetId = 1;

    reserveConfigs[0] = Spoke.ReserveConfig({lt: 0.8e4, lb: 0, borrowable: true, collateral: true});
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.76e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });

    Utils.addAssetAndSpokes(
      hub,
      address(eth),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(ethAssetId, 2000e8);

    // Add USDC
    uint256 usdcId = 2;

    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.78e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.72e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });

    Utils.addAssetAndSpokes(
      hub,
      address(usdc),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(usdcId, 1e8);

    irStrategy.setInterestRateParams(
      daiAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );
    irStrategy.setInterestRateParams(
      ethAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );
    irStrategy.setInterestRateParams(
      usdcId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );
  }

  function test_supply_revertsWith_reserve_not_listed() public {
    uint256 assetId = 5; // invalid assetId
    uint256 amount = 100e18;

    vm.prank(USER1);
    vm.expectRevert(TestErrors.RESERVE_NOT_LISTED);
    spoke1.supply(assetId, amount);
  }

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 assetId = 0;
    uint256 amount = 100e18;

    vm.prank(USER1);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        0,
        amount
      )
    );
    spoke1.supply(assetId, amount);
  }

  function test_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), USER1, amount);

    Spoke.UserConfig memory userData = spoke1.getUser(assetId, USER1);

    // assertEq(dai.balanceOf(USER1), amount, 'wrong user token balance pre-supply');
    // assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');
    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-supply');
    // assertEq(userData.supplyShares, 0, 'wrong user shares pre-supply');
    // assertEq(userData.debtShares, 0, 'wrong user shares pre-supply');

    vm.startPrank(USER1);
    dai.approve(address(hub), amount);
    vm.expectEmit(address(spoke1));
    emit Supplied(assetId, USER1, amount);
    spoke1.supply(assetId, amount);
    vm.stopPrank();

    userData = spoke1.getUser(assetId, USER1);

    // assertEq(dai.balanceOf(USER1), 0);
    // assertEq(dai.balanceOf(address(hub)), amount);
    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    // assertEq(
    //   userData.supplyShares,
    //   hub.convertToSharesDown(assetId, amount),
    //   'wrong user supply shares'
    // );
    // assertEq(userData.debtShares, 0, 'wrong user debt shares');
  }

  function test_borrow_revertsWith_reserve_not_borrowable() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    // USER1 supply eth
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(hub, spoke1, ethId, USER1, ethAmount, USER1);

    // USER2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiId, USER2, daiAmount, USER2);

    // set reserve not borrowable
    Utils.updateBorrowable(spoke1, daiId, false);

    // USER1 draw half of dai reserve liquidity
    vm.prank(USER1);
    vm.expectRevert(TestErrors.RESERVE_NOT_BORROWABLE);
    ISpoke(spoke1).borrow(daiId, USER1, daiAmount / 2);
  }

  function test_borrow() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    // USER1 supply eth
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(hub, spoke1, ethId, USER1, ethAmount, USER1);

    // USER2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiId, USER2, daiAmount, USER2);

    Spoke.UserConfig memory user1Data = spoke1.getUser(ethId, USER1);
    Spoke.UserConfig memory user2Data = spoke1.getUser(daiId, USER2);

    // assertEq(
    //   user1Data.supplyShares,
    //   ILiquidityHub(address(hub)).convertToSharesDown(ethId, ethAmount),
    //   'wrong user1 supply shares pre-draw'
    // );
    // assertEq(user1Data.debtShares, 0, 'wrong user1 debt shares pre-draw');
    // assertEq(
    //   user2Data.supplyShares,
    //   ILiquidityHub(address(hub)).convertToSharesDown(daiId, daiAmount),
    //   'wrong user2 supply shares pre-draw'
    // );
    // assertEq(user2Data.debtShares, 0, 'wrong user2 debt shares pre-draw');
    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai balance pre-draw');
    // assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth balance pre-draw');
    // assertEq(dai.balanceOf(USER1), 0, 'wrong spoke1 dai balance pre-draw');
    // assertEq(eth.balanceOf(USER2), 0, 'wrong spoke2 eth balance pre-draw');

    // USER1 draw half of dai reserve liquidity
    vm.prank(USER1);
    vm.expectEmit(address(spoke1));
    emit Borrowed(daiId, USER1, daiAmount / 2);
    ISpoke(spoke1).borrow(daiId, USER1, daiAmount / 2);

    user1Data = spoke1.getUser(ethId, USER1);
    user2Data = spoke1.getUser(daiId, USER2);

    // assertEq(
    //   user1Data.supplyShares,
    //   ILiquidityHub(address(hub)).convertToSharesDown(ethId, ethAmount),
    //   'wrong user1 supply shares final balance'
    // );
    // assertEq(user1Data.debtShares, 0, 'wrong user1 debt shares final balance');
    // assertEq(
    //   user2Data.supplyShares,
    //   ILiquidityHub(address(hub)).convertToSharesDown(daiId, daiAmount),
    //   'wrong user2 supply shares final balance'
    // );
    // assertEq(user2Data.debtShares, 0, 'wrong user2 debt shares final');
    // assertEq(dai.balanceOf(USER1), daiAmount / 2, 'wrong USER1 dai final balance');
    // assertEq(eth.balanceOf(USER2), 0, 'wrong USER2 eth final balance');
    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai final balance');
    // assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth final balance');
  }

  function test_withdraw() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // USER1 supply
    deal(address(dai), USER1, amount);
    Utils.spokeSupply(hub, spoke1, assetId, USER1, amount, USER1);

    Spoke.UserConfig memory user1Data = spoke1.getUser(assetId, USER1);

    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-withdraw');
    // assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance pre-withdraw');
    // assertEq(dai.balanceOf(USER1), 0, 'wrong user token balance pre-withdraw');
    // assertEq(
    //   user1Data.supplyShares,
    //   ILiquidityHub(hub).convertToSharesDown(assetId, amount),
    //   'wrong user supply shares post-withdraw'
    // );
    // assertEq(user1Data.debtShares, 0, 'wrong user debt shares post-withdraw');

    vm.startPrank(USER1);
    vm.expectEmit(address(spoke1));
    emit Withdrawn(assetId, USER1, amount);
    spoke1.withdraw(assetId, USER1, amount);
    vm.stopPrank();

    user1Data = spoke1.getUser(assetId, USER1);

    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-withdraw');
    // assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance post-withdraw');
    // assertEq(dai.balanceOf(USER1), amount, 'wrong user token balance post-withdraw');
    // assertEq(user1Data.supplyShares, 0, 'wrong user supply shares post-withdraw');
    // assertEq(user1Data.debtShares, 0, 'wrong user debt shares post-withdraw');
  }

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

  function test_updateReserveConfig() public {
    uint256 daiId = 0;

    Spoke.Reserve memory reserveData = spoke1.getReserve(daiId);

    Spoke.ReserveConfig memory newReserveConfig = Spoke.ReserveConfig({
      lt: reserveData.config.lt + 1,
      lb: reserveData.config.lb + 1,
      borrowable: !reserveData.config.borrowable,
      collateral: !reserveData.config.collateral
    });
    vm.expectEmit(address(spoke1));
    emit ReserveConfigUpdated(
      daiId,
      newReserveConfig.lt,
      newReserveConfig.lb,
      newReserveConfig.borrowable,
      newReserveConfig.collateral
    );
    spoke1.updateReserveConfig(daiId, newReserveConfig);

    reserveData = spoke1.getReserve(daiId);

    assertEq(reserveData.config.lt, newReserveConfig.lt, 'wrong lt');
    assertEq(reserveData.config.lb, newReserveConfig.lb, 'wrong lb');
    assertEq(reserveData.config.borrowable, newReserveConfig.borrowable, 'wrong borrowable');
    assertEq(reserveData.config.collateral, newReserveConfig.collateral, 'wrong collateral');
  }

  function test_setUsingAsCollateral_revertsWith_reserve_not_collateral() public {
    uint256 daiId = 0;
    bool newCollateral = false;
    bool usingAsCollateral = true;
    Utils.updateCollateral(spoke1, daiId, newCollateral);

    vm.prank(USER1);
    vm.expectRevert(TestErrors.RESERVE_NOT_COLLATERAL);
    ISpoke(spoke1).setUsingAsCollateral(daiId, usingAsCollateral);
  }

  function test_setUsingAsCollateral_revertsWith_no_supply() public {
    uint256 daiId = 0;
    bool newCollateral = true;
    bool usingAsCollateral = true;
    Utils.updateCollateral(spoke1, daiId, newCollateral);

    vm.prank(USER1);
    vm.expectRevert(TestErrors.NO_SUPPLY);
    ISpoke(spoke1).setUsingAsCollateral(daiId, usingAsCollateral);
  }

  function test_setUsingAsCollateral() public {
    uint256 daiId = 0;
    bool newCollateral = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    // ensure DAI is allowed as collateral
    Utils.updateCollateral(spoke1, daiId, newCollateral);

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiId, USER1, daiAmount, USER1);

    vm.prank(USER1);
    vm.expectEmit(address(spoke1));
    emit UsingAsCollateral(daiId, USER1, usingAsCollateral);
    ISpoke(spoke1).setUsingAsCollateral(daiId, usingAsCollateral);

    Spoke.UserConfig memory userData = spoke1.getUser(daiId, USER1);
    assertEq(userData.usingAsCollateral, usingAsCollateral, 'wrong usingAsCollateral');
  }
}
