// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'src/contracts/LiquidityHub.sol';
import 'src/contracts/Spoke.sol';
import 'src/dependencies/openzeppelin/IERC20.sol';

library Utils {
  // hub
  function addAssetAndSpokes(
    LiquidityHub hub,
    address asset,
    DataTypes.AssetConfig memory assetConfig,
    address[] memory spokes,
    DataTypes.SpokeConfig[] memory spokeConfigs,
    Spoke.ReserveConfig[] memory reserveConfigs
  ) internal {
    hub.addAsset(assetConfig, asset);
    uint256 assetId = hub.assetCount() - 1;
    for (uint256 i = 0; i < spokes.length; i++) {
      hub.addSpoke(assetId, spokeConfigs[i], spokes[i]);
      Spoke(spokes[i]).addReserve(assetId, reserveConfigs[i], asset);
    }
  }
  function supply(
    Vm vm,
    LiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    address onBehalfOf
  ) internal {
    address asset = hub.assetsList(assetId);
    vm.startPrank(spoke);
    IERC20(asset).transfer(address(hub), amount);
    hub.supply(assetId, amount, 0);
    vm.stopPrank();
  }

  function draw(
    Vm vm,
    LiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.startPrank(spoke);
    hub.draw(assetId, spoke, amount, 0);
    vm.stopPrank();
  }

  function withdraw(
    Vm vm,
    LiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    address to
  ) internal {
    vm.startPrank(spoke);
    // TODO: risk premium
    hub.withdraw(assetId, to, amount, 0);
    vm.stopPrank();
  }

  // spoke
  function spokeSupply(
    Vm vm,
    LiquidityHub hub,
    Spoke spoke,
    uint256 assetId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    address asset = hub.assetsList(assetId);
    vm.startPrank(user);
    IERC20(asset).approve(address(spoke), amount);
    spoke.supply(assetId, amount);
    vm.stopPrank();
  }

  function borrow(
    Vm vm,
    Spoke spoke,
    uint256 assetId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.startPrank(user);
    spoke.borrow(assetId, user, amount);
    vm.stopPrank();
  }
}
