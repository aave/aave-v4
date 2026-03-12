// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

contract MockInterestRateStrategy {
  mapping(uint256 => IAssetInterestRateStrategy.InterestRateData) private _interestRateData;

  function setInterestRateData(
    uint256 assetId,
    IAssetInterestRateStrategy.InterestRateData memory data
  ) external {
    _interestRateData[assetId] = data;
  }

  function getInterestRateData(
    uint256 assetId
  ) external view returns (IAssetInterestRateStrategy.InterestRateData memory) {
    return _interestRateData[assetId];
  }
}
