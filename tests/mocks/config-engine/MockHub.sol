// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';

contract MockHub {
  mapping(address => uint256) private _assetIds;
  mapping(uint256 => IHub.AssetConfig) private _assetConfigs;
  mapping(uint256 => address) private _assetUnderlyings;
  mapping(uint256 => uint8) private _assetDecimals;
  uint40 private _maxAllowedSpokeCap;

  function setAssetId(address underlying, uint256 assetId) external {
    _assetIds[underlying] = assetId;
  }

  function setAssetConfig(uint256 assetId, IHub.AssetConfig memory config) external {
    _assetConfigs[assetId] = config;
  }

  function setAssetUnderlyingAndDecimals(
    uint256 assetId,
    address underlying,
    uint8 decimals
  ) external {
    _assetUnderlyings[assetId] = underlying;
    _assetDecimals[assetId] = decimals;
  }

  function setMaxAllowedSpokeCap(uint40 cap) external {
    _maxAllowedSpokeCap = cap;
  }

  function getAssetId(address underlying) external view returns (uint256) {
    return _assetIds[underlying];
  }

  function getAssetConfig(uint256 assetId) external view returns (IHub.AssetConfig memory) {
    return _assetConfigs[assetId];
  }

  function getAssetUnderlyingAndDecimals(uint256 assetId) external view returns (address, uint8) {
    return (_assetUnderlyings[assetId], _assetDecimals[assetId]);
  }

  function MAX_ALLOWED_SPOKE_CAP() external view returns (uint40) {
    return _maxAllowedSpokeCap;
  }
}
