// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {ISpokeBase, ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

library Utils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // hub
  function add(
    IHubBase hub,
    address asset,
    address caller,
    uint256 amount,
    address user
  ) internal returns (uint256) {
    approve(IHub(address(hub)), asset, caller, user, amount);
    transferFrom(IHub(address(hub)), asset, caller, user, address(hub), amount);
    vm.prank(caller);
    return hub.add(asset, amount);
  }

  function draw(
    IHubBase hub,
    address asset,
    address caller,
    address to,
    uint256 amount
  ) internal returns (uint256) {
    vm.prank(caller);
    return hub.draw(asset, amount, to);
  }

  function remove(
    IHubBase hub,
    address asset,
    address caller,
    uint256 amount,
    address to
  ) internal returns (uint256) {
    vm.prank(caller);
    return hub.remove(asset, amount, to);
  }

  function restoreDrawn(
    IHubBase hub,
    address asset,
    address caller,
    uint256 drawnAmount,
    address restorer
  ) internal returns (uint256) {
    approve(IHub(address(hub)), asset, caller, restorer, drawnAmount);
    transferFrom(IHub(address(hub)), asset, caller, restorer, address(hub), drawnAmount);
    vm.prank(caller);
    return hub.restore(asset, drawnAmount, 0, IHubBase.PremiumDelta(0, 0, 0));
  }

  function addSpoke(
    IHub hub,
    address hubAdmin,
    address asset,
    address spoke,
    IHub.SpokeConfig memory spokeConfig
  ) internal {
    vm.prank(hubAdmin);
    hub.addSpoke(asset, spoke, spokeConfig);
  }

  function updateSpokeConfig(
    IHub hub,
    address hubAdmin,
    address asset,
    address spoke,
    IHub.SpokeConfig memory spokeConfig
  ) internal {
    vm.prank(hubAdmin);
    hub.updateSpokeConfig(asset, spoke, spokeConfig);
  }

  function addAsset(
    IHub hub,
    address hubAdmin,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy,
    bytes memory encodedIrData
  ) internal {
    vm.prank(hubAdmin);
    hub.addAsset(underlying, decimals, feeReceiver, interestRateStrategy, encodedIrData);
  }

  function updateAssetConfig(
    IHub hub,
    address hubAdmin,
    address asset,
    IHub.AssetConfig memory config,
    bytes memory encodedIrData
  ) internal {
    vm.prank(hubAdmin);
    hub.updateAssetConfig(asset, config, encodedIrData);
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

  function mintFeeShares(IHub hub, address asset, address caller) internal returns (uint256) {
    vm.prank(caller);
    return hub.mintFeeShares(asset);
  }

  function approve(ISpoke spoke, uint256 reserveId, address owner, uint256 amount) internal {
    IHubBase hub = spoke.getReserve(reserveId).hub;
    address underlying = spoke.getReserve(reserveId).underlying;
    _approve(IERC20(underlying), owner, address(spoke), amount);
  }

  function approve(ISpoke spoke, address underlying, address owner, uint256 amount) internal {
    _approve(IERC20(underlying), owner, address(spoke), amount);
  }

  function approve(
    ISpoke spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    _approve(IERC20(spoke.getReserve(reserveId).underlying), owner, spender, amount);
  }

  function approve(
    IHub hub,
    address asset,
    address caller,
    address owner,
    uint256 amount
  ) internal {
    /// @dev caller is always a spoke
    _approve(IERC20(asset), owner, caller, amount);
  }

  function _approve(IERC20 underlying, address owner, address spender, uint256 amount) private {
    vm.startPrank(owner);
    underlying.approve(spender, 0);
    underlying.approve(spender, amount);
    vm.stopPrank();
  }

  function transferFrom(
    ISpoke spoke,
    uint256 reserveId,
    address caller,
    address from,
    address to,
    uint256 amount
  ) internal {
    _transferFrom(IERC20(spoke.getReserve(reserveId).underlying), caller, from, to, amount);
  }

  function transferFrom(
    IHub hub,
    address asset,
    address caller,
    address from,
    address to,
    uint256 amount
  ) internal {
    _transferFrom(IERC20(asset), caller, from, to, amount);
  }

  function _transferFrom(
    IERC20 underlying,
    address caller,
    address from,
    address to,
    uint256 amount
  ) private {
    vm.prank(caller);
    underlying.transferFrom(from, to, amount);
  }
}
