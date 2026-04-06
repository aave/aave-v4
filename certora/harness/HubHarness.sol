import '../../src/hub/Hub.sol';
import {AssetLogic} from 'src/hub/libraries/AssetLogic.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';

pragma solidity ^0.8.0;

contract HubHarness is Hub {
  using AssetLogic for Asset;

  constructor(address authority_) Hub(authority_) {
    // Intentionally left blank
  }

  function accrueInterest(uint256 assetId) external {
    Asset storage asset = _assets[assetId];

    asset.accrue();
  }

  function toSharesDown(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) external pure returns (uint256) {
    return SharesMath.toSharesDown(assets, totalAssets, totalShares);
  }

  function toAssetsDown(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) external pure returns (uint256) {
    return SharesMath.toAssetsDown(shares, totalAssets, totalShares);
  }

  function toSharesUp(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) external pure returns (uint256) {
    return SharesMath.toSharesUp(assets, totalAssets, totalShares);
  }

  function toAssetsUp(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) external pure returns (uint256) {
    return SharesMath.toAssetsUp(shares, totalAssets, totalShares);
  }

  function getUnrealizedFees(uint256 assetId) external view returns (uint256) {
    Asset storage asset = _assets[assetId];

    return asset.getUnrealizedFees(asset.getDrawnIndex());
  }
}
