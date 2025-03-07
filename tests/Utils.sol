// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

library Utils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // hub
  function supply(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    uint32 riskPremium,
    address user,
    address to // todo: implement
  ) internal {
    vm.startPrank(user);
    hub.assetsList(assetId).approve(address(hub), amount);
    vm.stopPrank();

    vm.prank(spoke);
    hub.supply({assetId: assetId, amount: amount, riskPremium: riskPremium, supplier: user});
  }

  function draw(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    address to,
    uint256 amount,
    uint32 riskPremium,
    address onBehalfOf // todo: implement
  ) internal {
    vm.prank(spoke);
    hub.draw(assetId, amount, riskPremium, to);
  }

  function withdraw(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    uint32 riskPremium,
    address to
  ) internal {
    vm.prank(spoke);
    hub.withdraw(assetId, amount, riskPremium, to);
  }

  function restore(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 amount,
    uint32 riskPremium,
    address repayer
  ) internal {
    vm.startPrank(repayer);
    hub.assetsList(assetId).approve(address(hub), amount);
    vm.stopPrank();

    vm.prank(spoke);
    hub.restore(assetId, amount, riskPremium, repayer);
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
