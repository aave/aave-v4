// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';

contract MockHub {
  mapping(address => uint256) private _assetIds;
  mapping(uint256 => IHub.AssetConfig) private _assetConfigs;

  function setAssetId(address underlying, uint256 assetId) external {
    _assetIds[underlying] = assetId;
  }

  function setAssetConfig(uint256 assetId, IHub.AssetConfig memory config) external {
    _assetConfigs[assetId] = config;
  }

  function getAssetId(address underlying) external view returns (uint256) {
    return _assetIds[underlying];
  }

  function getAssetConfig(uint256 assetId) external view returns (IHub.AssetConfig memory) {
    return _assetConfigs[assetId];
  }
}
