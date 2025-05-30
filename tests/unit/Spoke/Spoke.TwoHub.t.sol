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

  function setUp() public virtual override {
    super.setUp();

    // Create a second hub
    ILiquidityHub hub2 = new LiquidityHub();

    // TODO: For now, just keep assets added in same order, but later test diff assetId orderings

    // Add assets to the second hub
    vm.startPrank(HUB_ADMIN);
    // Add WETH
    hub.addAsset(
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
    hub.addAsset(
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
    hub.addAsset(
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
    hub.addAsset(
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
  }
}
