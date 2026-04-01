// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';

library HubActions {
  using SafeERC20 for *;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  CORE HUB ACTIONS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function add(
    IHubBase hub,
    uint256 assetId,
    address caller,
    uint256 amount,
    address user
  ) internal returns (uint256) {
    IHub ihub = IHub(address(hub));
    approve({hub: ihub, assetId: assetId, caller: caller, owner: user, amount: amount});
    transferFrom({
      hub: ihub,
      assetId: assetId,
      caller: caller,
      from: user,
      to: address(hub),
      amount: amount
    });
    vm.prank(caller);
    return hub.add(assetId, amount);
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
    IHubBase hub,
    uint256 assetId,
    address caller,
    uint256 drawnAmount,
    address restorer
  ) internal returns (uint256) {
    IHub ihub = IHub(address(hub));
    approve({hub: ihub, assetId: assetId, caller: caller, owner: restorer, amount: drawnAmount});
    transferFrom({
      hub: ihub,
      assetId: assetId,
      caller: caller,
      from: restorer,
      to: address(hub),
      amount: drawnAmount
    });
    vm.prank(caller);
    return hub.restore(assetId, drawnAmount, IHubBase.PremiumDelta(0, 0, 0));
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  ADMIN HUB ACTIONS                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function addSpoke(
    IHub hub,
    address hubAdmin,
    uint256 assetId,
    address spoke,
    IHub.SpokeConfig memory spokeConfig
  ) internal {
    vm.prank(hubAdmin);
    hub.addSpoke(assetId, spoke, spokeConfig);
  }

  function updateSpokeConfig(
    IHub hub,
    address hubAdmin,
    uint256 assetId,
    address spoke,
    IHub.SpokeConfig memory spokeConfig
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
    address irStrategy,
    bytes memory encodedIrData
  ) internal returns (uint256) {
    vm.prank(hubAdmin);
    return hub.addAsset(underlying, decimals, feeReceiver, irStrategy, encodedIrData);
  }

  function updateAssetConfig(
    IHub hub,
    address hubAdmin,
    uint256 assetId,
    IHub.AssetConfig memory config,
    bytes memory encodedIrData
  ) internal {
    vm.prank(hubAdmin);
    hub.updateAssetConfig(assetId, config, encodedIrData);
  }

  function mintFeeShares(IHub hub, uint256 assetId, address caller) internal returns (uint256) {
    vm.prank(caller);
    return hub.mintFeeShares(assetId);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  TOKEN HELPERS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function approve(
    IHub hub,
    uint256 assetId,
    address caller,
    address owner,
    uint256 amount
  ) internal {
    /// @dev caller is always a spoke
    _approve({
      underlying: IERC20(hub.getAsset(assetId).underlying),
      owner: owner,
      spender: caller,
      amount: amount
    });
  }

  function transferFrom(
    IHub hub,
    uint256 assetId,
    address caller,
    address from,
    address to,
    uint256 amount
  ) internal {
    _transferFrom({
      underlying: IERC20(hub.getAsset(assetId).underlying),
      caller: caller,
      from: from,
      to: to,
      amount: amount
    });
  }

  function _approve(IERC20 underlying, address owner, address spender, uint256 amount) private {
    vm.startPrank(owner);
    underlying.forceApprove(spender, amount);
    vm.stopPrank();
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
