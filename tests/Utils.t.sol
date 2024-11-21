// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'src/contracts/LiquidityHub.sol';
import 'src/contracts/Spoke.sol';
import 'src/dependencies/openzeppelin/IERC20.sol';

library Utils {
  // hub
  function supply(
    Vm vm,
    LiquidityHub hub,
    uint256 assetId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    address asset = hub.assetsList(assetId);
    vm.startPrank(user);
    IERC20(asset).approve(address(hub), amount);
    hub.supply(assetId, amount, 0);
    vm.stopPrank();
  }

  function draw(
    Vm vm,
    LiquidityHub hub,
    uint256 assetId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.startPrank(user);
    hub.draw(assetId, user, amount, 0);
    vm.stopPrank();
  }

  function withdraw(
    Vm vm,
    LiquidityHub hub,
    uint256 assetId,
    address user,
    uint256 amount,
    address to
  ) internal {
    vm.startPrank(user);
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
