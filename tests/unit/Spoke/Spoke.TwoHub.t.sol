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
    vm.stopPrank();
  }

  function test_borrow_secondHub() public {
    // Bob supply to spoke 1 on hub 1
    vm.startPrank(bob);
    spoke1.supply(_daiReserveId(spoke1), MAIN_HUB, 100000e18);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true);
    vm.stopPrank();

    deal(address(tokenList.dai), address(spoke1), 1e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub2), type(uint256).max);
    hub2.add(daiAssetId, 1e18, address(spoke1));
    vm.stopPrank();

    // Bob can't borrow from hub 2 because his collateral position is on hub 1
    vm.startPrank(bob);
    vm.expectRevert(ISpoke.HubMismatch.selector);
    spoke1.borrow(_daiReserveId(spoke1), HUB2, 1e18, bob);

    // Bob withdraw from hub 1 and supplies to hub 2
    spoke1.withdraw(_daiReserveId(spoke1), MAIN_HUB, type(uint256).max, bob);
    tokenList.dai.approve(address(hub2), type(uint256).max);
    spoke1.supply(_daiReserveId(spoke1), HUB2, 100000e18);

    // Now bob can borrow from hub 2
    spoke1.borrow(_daiReserveId(spoke1), HUB2, 1e18, bob);

    // If bob has borrowed already from hub2, cannot borrow from hub 1
    vm.expectRevert(ISpoke.HubMismatch.selector);
    spoke1.borrow(_daiReserveId(spoke1), MAIN_HUB, 1e18, bob);

    // Bob cannot repay to hub 1, with debt in hub 2 (same asset)
    vm.expectRevert(ISpoke.HubMismatch.selector);
    spoke1.repay(_daiReserveId(spoke1), MAIN_HUB, 1e18);

    // Bob can repay to hub 2
    spoke1.repay(_daiReserveId(spoke1), HUB2, type(uint256).max);

    // Bob withdraws from hub 2 and supplies to hub 1
    spoke1.withdraw(_daiReserveId(spoke1), HUB2, type(uint256).max, bob);
    spoke1.supply(_daiReserveId(spoke1), MAIN_HUB, 100000e18);
    vm.stopPrank();

    // Now Bob can draw from hub 1
    _deployLiquidity(spoke1, _daiReserveId(spoke1), 1000e18);
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), MAIN_HUB, 1e18, bob);
  }
}
