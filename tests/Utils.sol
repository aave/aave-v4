// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IHub, IHubBase} from 'src/interfaces/IHub.sol';
import {ISpokeBase, ISpoke} from 'src/interfaces/ISpoke.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

library Utils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // hub
  function add(
    IHub hub,
    uint256 assetId,
    address caller,
    uint256 amount,
    address user
  ) internal returns (uint256) {
    approve(hub, assetId, caller, amount);
    vm.prank(caller);
    return hub.add(assetId, amount, user);
  }

  function draw(
    IHubBase hub,
    uint256 assetId,
    address caller,
    address to,
    uint256 amount
  ) internal returns (uint256) {
    vm.prank(caller);
    return hub.draw(assetId, amount, to);
  }

  function remove(
    IHubBase hub,
    uint256 assetId,
    address caller,
    uint256 amount,
    address to
  ) internal returns (uint256) {
    vm.prank(caller);
    return hub.remove(assetId, amount, to);
  }

  function restoreDrawn(
    IHub hub,
    uint256 assetId,
    address caller,
    uint256 drawnAmount,
    address restorer
  ) internal returns (uint256) {
    approve(hub, assetId, restorer, drawnAmount);
    vm.prank(caller);
    return hub.restore(assetId, drawnAmount, 0, DataTypes.PremiumDelta(0, 0, 0), restorer);
  }

  function addSpoke(
    IHub hub,
    address hubAdmin,
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory spokeConfig
  ) internal {
    vm.prank(hubAdmin);
    hub.addSpoke(assetId, spoke, spokeConfig);
  }

  function updateSpokeConfig(
    IHub hub,
    address hubAdmin,
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory spokeConfig
  ) internal {
    vm.prank(hubAdmin);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  function addAsset(
    IHub hub,
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
    IHub hub,
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
    ISpokeBase spoke,
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
    ISpokeBase spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.withdraw(reserveId, amount, onBehalfOf);
  }

  function borrow(
    ISpokeBase spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.borrow(reserveId, amount, onBehalfOf);
  }

  function repay(
    ISpokeBase spoke,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    spoke.repay(reserveId, amount, onBehalfOf);
  }

  function approve(ISpoke spoke, uint256 reserveId, address owner, uint256 amount) internal {
    _approve(
      IERC20(spoke.getReserve(reserveId).underlying),
      owner,
      address(spoke.getReserve(reserveId).hub),
      amount
    );
  }

  function approve(IHub hub, uint256 assetId, address owner, uint256 amount) internal {
    _approve(IERC20(hub.getAsset(assetId).underlying), owner, address(hub), amount);
  }

  function _approve(IERC20 underlying, address owner, address spender, uint256 amount) private {
    uint256 allowance = underlying.allowance(owner, spender);
    if (allowance < amount) {
      vm.startPrank(owner);
      underlying.approve(spender, 0);
      underlying.approve(spender, amount);
      vm.stopPrank();
    }
  }
}
