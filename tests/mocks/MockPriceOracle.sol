// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPriceOracle} from 'src/contracts/IPriceOracle.sol';

contract MockPriceOracle is IPriceOracle {
  // Map of asset prices (assetId => price)
  mapping(uint256 => uint256) internal prices;

  uint256 internal ethPriceUsd;

  event AssetPriceUpdated(uint256 assetId, uint256 price, uint256 timestamp);
  event EthPriceUpdated(uint256 price, uint256 timestamp);

  function getAssetPrice(uint256 assetId) external view override returns (uint256) {
    return prices[assetId];
  }

  function setAssetPrice(uint256 assetId, uint256 price) external {
    prices[assetId] = price;
    emit AssetPriceUpdated(assetId, price, block.timestamp);
  }

  function getEthUsdPrice() external view returns (uint256) {
    return ethPriceUsd;
  }

  function setEthUsdPrice(uint256 price) external {
    ethPriceUsd = price;
    emit EthPriceUpdated(price, block.timestamp);
  }
}
