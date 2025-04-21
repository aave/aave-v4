import "../../src/contracts/LiquidityHub.sol" ;
import {AssetLogic} from 'src/libraries/logic/AssetLogic.sol';
pragma solidity ^0.8.0;

contract LiquidityHubHarness is LiquidityHub {
      using AssetLogic for DataTypes.Asset;

  function accrueInterest(
    uint256 assetId
  ) external  {
    
    DataTypes.Asset storage asset = _assets[assetId];
    DataTypes.SpokeData storage spoke = _spokes[assetId][msg.sender];

    asset.accrue();
  }
}

