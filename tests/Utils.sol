// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

library Utils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // hub
  function add(
    ILiquidityHub hub,
    uint256 assetId,
    address caller,
    uint256 amount,
    address user
  ) internal returns (uint256) {
    vm.startPrank(user);
    IERC20(hub.getAsset(assetId).underlying).approve(address(hub), amount);
    vm.stopPrank();

    vm.prank(caller);
    return hub.add(assetId, amount, user);
  }

  function draw(
    ILiquidityHub hub,
    uint256 assetId,
    address caller,
    address to,
    uint256 amount
  ) internal returns (uint256) {
    vm.prank(caller);
    return hub.draw(assetId, amount, to);
  }

  function remove(
    ILiquidityHub hub,
    uint256 assetId,
    address caller,
    uint256 amount,
    address to
  ) internal returns (uint256) {
    vm.prank(caller);
    return hub.remove(assetId, amount, to);
  }

  function restore(
    ILiquidityHub hub,
    uint256 assetId,
    address caller,
    uint256 baseAmount,
    uint256 premiumAmount,
    address repayer
  ) internal returns (uint256) {
    vm.startPrank(repayer);
    IERC20(hub.getAsset(assetId).underlying).approve(address(hub), (baseAmount + premiumAmount));
    vm.stopPrank();

    vm.prank(caller);
    return hub.restore(assetId, baseAmount, premiumAmount, repayer);
  }

  function addSpoke(
    ILiquidityHub hub,
    address hubAdmin,
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory spokeConfig
  ) internal {
    vm.prank(hubAdmin);
    hub.addSpoke(assetId, spoke, spokeConfig);
  }

  function updateSpokeConfig(
    ILiquidityHub hub,
    address hubAdmin,
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory spokeConfig
  ) internal {
    vm.prank(hubAdmin);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  function addAsset(
    ILiquidityHub hub,
    address hubAdmin,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy,
    bytes memory encodedIrData
  ) internal returns (uint256) {
    vm.prank(hubAdmin);
    return hub.addAsset(underlying, decimals, feeReceiver, interestRateStrategy, encodedIrData);
  }

  function updateAssetConfig(
    ILiquidityHub hub,
    address hubAdmin,
    uint256 assetId,
    DataTypes.AssetConfig memory config
  ) internal {
    vm.prank(hubAdmin);
    hub.updateAssetConfig(assetId, config);
  }

  // spoke
  function setUsingAsCollateral(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    bool usingAsCollateral,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  function supply(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.supply(reserveId, amount, onBehalfOf);
  }

  function supplyCollateral(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    supply(spoke, reserveId, caller, amount, onBehalfOf);
    setUsingAsCollateral(spoke, reserveId, caller, true, onBehalfOf);
  }

  function withdraw(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.withdraw(reserveId, amount, onBehalfOf);
  }

  function borrow(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.borrow(reserveId, amount, onBehalfOf);
  }

  function repay(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.repay(reserveId, amount, onBehalfOf);
  }
}
