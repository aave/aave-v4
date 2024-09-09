// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'src/contracts/LiquidityHub.sol';
import 'src/dependencies/openzeppelin/IERC20.sol';

library Utils {
  function supply(
    Vm vm,
    LiquidityHub hub,
    uint256 assetId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    address asset = hub.reservesList(assetId);
    vm.startPrank(user);
    IERC20(asset).approve(address(hub), amount);
    hub.supply(assetId, amount, onBehalfOf, 0);
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
    hub.withdraw(assetId, amount, to);
    vm.stopPrank();
  }
}
