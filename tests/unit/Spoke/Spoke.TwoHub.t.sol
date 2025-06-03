// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';

contract SpokeTwoHub is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMath for uint256;

  ILiquidityHub hub2;
  uint256 public constant HUB2 = 2;
  uint256 daiHub2ReserveId;

  function setUp() public virtual override {
    super.setUp();

    // Create a second hub
    hub2 = new LiquidityHub();

    // TODO: For now, just keep assets added in same order, but later test diff assetId orderings

    // Add assets to the second hub
    vm.startPrank(HUB_ADMIN);
    // Add WETH
    hub2.addAsset(
      DataTypes.AssetConfig({
        active: true,
        frozen: false,
        paused: false,
        decimals: tokenList.weth.decimals(),
        irStrategy: irStrategy
      }),
      address(tokenList.weth)
    );
    oracle.setAssetPrice(wethAssetId, 1500e8);

    // Add USDX
    hub2.addAsset(
      DataTypes.AssetConfig({
        active: true,
        frozen: false,
        paused: false,
        decimals: tokenList.usdx.decimals(),
        irStrategy: irStrategy
      }),
      address(tokenList.usdx)
    );
    oracle.setAssetPrice(usdxAssetId, 1e8);

    // Add DAI
    hub2.addAsset(
      DataTypes.AssetConfig({
        active: true,
        frozen: false,
        paused: false,
        decimals: tokenList.dai.decimals(),
        irStrategy: irStrategy
      }),
      address(tokenList.dai)
    );
    oracle.setAssetPrice(daiAssetId, 1e8);

    // Add WBTC
    hub2.addAsset(
      DataTypes.AssetConfig({
        active: true,
        frozen: false,
        paused: false,
        decimals: tokenList.wbtc.decimals(),
        irStrategy: irStrategy
      }),
      address(tokenList.wbtc)
    );
    oracle.setAssetPrice(wbtcAssetId, 75_000e8);

    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    hub2.addSpoke(wethAssetId, spokeConfig, address(spoke1));
    hub2.addSpoke(usdxAssetId, spokeConfig, address(spoke1));
    hub2.addSpoke(daiAssetId, spokeConfig, address(spoke1));
    hub2.addSpoke(wbtcAssetId, spokeConfig, address(spoke1));

    spoke1.addHub(address(hub2));

    // Relist dai for hub 2 dai
    DataTypes.ReserveConfig memory daiHub2Config = DataTypes.ReserveConfig({
      decimals: tokenList.dai.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidityPremium: 20_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true,
      hubId: 2
    });
    daiHub2ReserveId = spoke1.addReserve(daiAssetId, daiHub2Config);
    vm.stopPrank();
  }

  function test_borrow_secondHub() public {
    uint256 hub1DaiBorrowAmount = 5e18;
    uint256 hub2DaiBorrowAmount = 1e18;

    // Bob supply to spoke 1 on hub 1
    vm.startPrank(bob);
    spoke1.supply(_daiReserveId(spoke1), 100000e18);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true);
    vm.stopPrank();

    deal(address(tokenList.dai), address(spoke1), 1e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub2), type(uint256).max);
    hub2.add(daiAssetId, 1e18, address(spoke1));
    vm.stopPrank();

    // Bob borrows dai from hub 2
    vm.prank(bob);
    spoke1.borrow(daiHub2ReserveId, hub2DaiBorrowAmount, bob);

    // Bob can also borrow from hub 1
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), hub1DaiBorrowAmount, bob);

    // Check Bob's total debt on each hub
    assertEq(spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob), hub1DaiBorrowAmount);
    assertEq(spoke1.getUserTotalDebt(daiHub2ReserveId, bob), hub2DaiBorrowAmount);

    assertEq(hub.getAssetTotalDebt(daiAssetId), hub1DaiBorrowAmount);
    assertEq(hub2.getAssetTotalDebt(daiAssetId), hub2DaiBorrowAmount);
  }
}
