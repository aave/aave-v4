import "../../src/contracts/Hub.sol";
import {AssetLogic} from 'src/libraries/logic/AssetLogic.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
pragma solidity ^0.8.0;

contract HubHarness is Hub {
      using AssetLogic for DataTypes.Asset;

  constructor(address authority_) Hub(authority_) {
    // Intentionally left blank
  }


  function accrueInterest(
    uint256 assetId
  ) external  {
    
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue( assetId, _spokes[assetId][asset.feeReceiver]);
  
  }


  function toSharesDown(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) external pure returns (uint256) {
    return  SharesMath.toSharesDown(assets, totalAssets, totalShares);
  }

  function toAssetsDown(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) external pure returns (uint256) {
    return  SharesMath.toAssetsDown(shares, totalAssets, totalShares);
  }

  function toSharesUp(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) external pure returns (uint256) {
      return  SharesMath.toSharesUp(assets, totalAssets, totalShares);
  }

  function toAssetsUp(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) external pure returns (uint256) {
      return  SharesMath.toAssetsUp(shares, totalAssets, totalShares);
  }

  function getAssetSuppliedAmountUp(uint256 assetId) external view returns (uint256) {
    return _assets[assetId].toAddedAssetsUp(_assets[assetId].addedShares);
  }
  
  /*
  function getFeeShares(uint256 assetId, uint256 indexDelta) 
    external view returns (uint256) {
        DataTypes.Asset storage asset = _assets[assetId];
        return asset.getFeeShares(indexDelta);
    }
    */
    function unrealizedFeeShares(uint256 assetId) external view returns (uint256) {
        DataTypes.Asset storage asset = _assets[assetId];
        return asset.unrealizedFeeShares();
  }
}
