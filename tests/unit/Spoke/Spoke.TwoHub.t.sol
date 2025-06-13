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
  ILiquidityHub hub3;
  uint256 daiHub2ReserveId;
  uint256 daiHub3ReserveId;
  uint256 hub3DaiAssetId;
  uint256 hub3UsdxAssetId;
  uint256 hub3WbtcAssetId;
  uint256 hub3WethAssetId;

  function setUp() public virtual override {
    super.setUp();

    // Create a second hub
    hub2 = new LiquidityHub();

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

    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    hub2.addSpoke(wethAssetId, spokeConfig, address(spoke1));
    hub2.addSpoke(usdxAssetId, spokeConfig, address(spoke1));
    hub2.addSpoke(daiAssetId, spokeConfig, address(spoke1));
    hub2.addSpoke(wbtcAssetId, spokeConfig, address(spoke1));

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
      hub: hub2
    });
    daiHub2ReserveId = spoke1.addReserve(daiAssetId, daiHub2Config);

    // Create a third hub with out of order asset ids
    hub3 = new LiquidityHub();

    // Add DAI
    hub3.addAsset(
      DataTypes.AssetConfig({
        active: true,
        frozen: false,
        paused: false,
        decimals: tokenList.dai.decimals(),
        irStrategy: irStrategy
      }),
      address(tokenList.dai)
    );
    hub3DaiAssetId = 0;

    // Add USDX
    hub3.addAsset(
      DataTypes.AssetConfig({
        active: true,
        frozen: false,
        paused: false,
        decimals: tokenList.usdx.decimals(),
        irStrategy: irStrategy
      }),
      address(tokenList.usdx)
    );
    hub3UsdxAssetId = 1;

    // Add WBTC
    hub3.addAsset(
      DataTypes.AssetConfig({
        active: true,
        frozen: false,
        paused: false,
        decimals: tokenList.wbtc.decimals(),
        irStrategy: irStrategy
      }),
      address(tokenList.wbtc)
    );
    hub3WbtcAssetId = 2;

    // Add WETH
    hub3.addAsset(
      DataTypes.AssetConfig({
        active: true,
        frozen: false,
        paused: false,
        decimals: tokenList.weth.decimals(),
        irStrategy: irStrategy
      }),
      address(tokenList.weth)
    );
    hub3WethAssetId = 3;

    hub3.addSpoke(hub3WethAssetId, spokeConfig, address(spoke1));
    hub3.addSpoke(hub3UsdxAssetId, spokeConfig, address(spoke1));
    hub3.addSpoke(hub3DaiAssetId, spokeConfig, address(spoke1));
    hub3.addSpoke(hub3WbtcAssetId, spokeConfig, address(spoke1));

    // Relist dai for hub 3 dai
    DataTypes.ReserveConfig memory daiHub3Config = DataTypes.ReserveConfig({
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
      hub: hub3
    });
    daiHub3ReserveId = spoke1.addReserve(hub3DaiAssetId, daiHub3Config);

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

  function test_borrow_thirdHub() public {
    uint256 hub1DaiBorrowAmount = 5e18;
    uint256 hub3DaiBorrowAmount = 1e18;
    uint256 daiSupplyAmount = 100000e18;

    // Bob supply to spoke 1 on hub 1
    vm.startPrank(bob);
    spoke1.supply(_daiReserveId(spoke1), daiSupplyAmount);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true);
    vm.stopPrank();

    deal(address(tokenList.dai), address(spoke1), hub3DaiBorrowAmount);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub3), type(uint256).max);
    hub3.add(hub3DaiAssetId, hub3DaiBorrowAmount, address(spoke1));
    vm.stopPrank();

    // Bob borrows dai from hub 3
    vm.startPrank(bob);
    spoke1.borrow(daiHub3ReserveId, hub3DaiBorrowAmount, bob);

    // Check Bob's total debt on hub 3
    assertEq(spoke1.getUserTotalDebt(daiHub3ReserveId, bob), hub3DaiBorrowAmount);
    assertEq(hub3.getAssetTotalDebt(hub3DaiAssetId), hub3DaiBorrowAmount);
    assertEq(hub.getAssetTotalDebt(daiAssetId), 0); // No debt on hub 1

    // Check bob is indeed borrowing dai from hub 3
    DataTypes.Reserve memory dai3Reserve = spoke1.getReserve(daiHub3ReserveId);
    assertEq(dai3Reserve.asset, address(tokenList.dai));

    // Bob repays debt on hub3
    tokenList.dai.approve(address(hub3), type(uint256).max);
    spoke1.repay(daiHub3ReserveId, hub3DaiBorrowAmount);
    assertEq(spoke1.getUserTotalDebt(daiHub3ReserveId, bob), 0);
    assertEq(hub3.getAssetTotalDebt(hub3DaiAssetId), 0);

    // Bob withdraws funds from hub1
    spoke1.withdraw(_daiReserveId(spoke1), daiSupplyAmount, bob);
    assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob), 0);
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), 0);

    vm.stopPrank();
  }
}
