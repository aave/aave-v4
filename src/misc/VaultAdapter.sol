// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

/**
 * @dev Adapter contract to hold funds.
 * - Acts as a liquidityHub to an existing Spoke and a Spoke to an existing liquidity hub.
 * - Merges vault/safe into adapter. Supply actions can be forwarded to Safe to hold liquidity.
 * - Draw actions are forwarded to connected (one) hub.
 * todo extract core hub & spoke methods to inherit
 */
contract VaultAdapter {
  using SafeERC20 for IERC20;

  mapping(uint256 assetId => mapping(address spokeAddress => DataTypes.SpokeData spokeData))
    internal _spokes;
  ILiquidityHub internal immutable _hub; // connects to only one hub

  constructor(address hub_) {
    _hub = ILiquidityHub(hub_);
  }

  // --------- HUB actions ----------
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256) {
    // validate asset id, caps, emit
    uint256 suppliedShares = _previewAdd(assetId, amount);
    _spokes[assetId][msg.sender].suppliedShares += suppliedShares;
    // can push assets to vault here
    IERC20(_hub.getAsset(assetId).underlying).safeTransferFrom(from, address(this), amount);
    return suppliedShares;
  }

  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    // validate asset id, caps, emit
    uint256 withdrawnShares = _previewRemove(assetId, amount);
    _spokes[assetId][msg.sender].suppliedShares += withdrawnShares;
    // can pull assets from vault here
    IERC20(_hub.getAsset(assetId).underlying).safeTransfer(to, amount);
    return withdrawnShares;
  }

  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    return _hub.draw(assetId, amount, to);
  }

  function restore(
    uint256 assetId,
    uint256 baseAmount,
    uint256 premiumAmount,
    address from
  ) external returns (uint256) {
    return _hub.restore(assetId, baseAmount, premiumAmount, from);
  }

  function refreshPremiumDebt(
    uint256 assetId,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) external {
    _hub.refreshPremiumDebt(
      assetId,
      premiumDrawnSharesDelta,
      premiumOffsetDelta,
      realizedPremiumAdded,
      realizedPremiumTaken
    );
  }

  function payFee(uint256 assetId, uint256 shares) external {
    _hub.payFee(assetId, shares);
  }

  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _hub.convertToDrawnAssets(assetId, shares);
  }

  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _hub.convertToDrawnShares(assetId, assets);
  }

  function previewOffset(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _hub.previewOffset(assetId, shares);
  }

  function previewDrawnIndex(uint256 assetId) external view returns (uint256) {
    return _hub.previewDrawnIndex(assetId);
  }

  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory) {
    return _hub.getAsset(assetId);
  }

  function convertToSuppliedAssets(
    uint256 /* assetId */,
    uint256 shares
  ) external pure returns (uint256) {
    return shares;
  }

  function convertToSuppliedShares(
    uint256 /* assetId */,
    uint256 assets
  ) external pure returns (uint256) {
    return assets;
  }

  // needed on liq
  function convertToSuppliedSharesUp(
    uint256 /* assetId */,
    uint256 assets
  ) external pure returns (uint256) {
    return assets;
  }

  function _previewAdd(uint256 /* assetId */, uint256 assets) internal pure returns (uint256) {
    // 1-1 since assets are not supplied
    return assets;
  }

  function _previewRemove(uint256 /* assetId */, uint256 assets) internal pure returns (uint256) {
    // 1-1 since assets are not supplied
    return assets;
  }
  // ----------------------

  // --------- SPOKE actions ----------
  // add with posm, supply/withdraw/borrow/liquidate onBehalfOf user (ie vault/safe)
  // -----------------------
}
