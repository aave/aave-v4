// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

library Utils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // hub
  function add(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    address user,
    address to // todo: implement
  ) internal returns (uint256) {
    vm.startPrank(user);
    hub.assetsList(assetId).approve(address(hub), amount);
    vm.stopPrank();

    vm.prank(spoke);
    return hub.add(assetId, amount, user);
  }

  function draw(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    address to,
    uint256 amount,
    address onBehalfOf // todo: implement
  ) internal returns (uint256) {
    vm.prank(spoke);
    hub.draw(assetId, amount, to);
  }

  function remove(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    address to
  ) internal {
    vm.prank(spoke);
    hub.remove(assetId, amount, to);
  }

  function restore(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 baseAmount,
    uint256 premiumAmount,
    address repayer
  ) internal {
    vm.startPrank(repayer);
    hub.assetsList(assetId).approve(address(hub), (baseAmount + premiumAmount));
    vm.stopPrank();

    vm.prank(spoke);
    hub.restore(assetId, baseAmount, premiumAmount, repayer);
  }

  // spoke
  function spokeSupply(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(user);
    spoke.supply(reserveId, amount);
  }

  function spokeWithdraw(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(user);
    spoke.withdraw(reserveId, amount, user);
  }

  function spokeBorrow(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(user);
    spoke.borrow(reserveId, amount, user);
  }

  function spokeRepay(ISpoke spoke, uint256 reserveId, address user, uint256 amount) internal {
    vm.prank(user);
    spoke.repay(reserveId, amount);
  }
}
