// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

library ConfigData {
  struct AddAssetParams {
    address hub;
    address underlying;
    uint8 decimals;
    address feeReceiver;
    uint16 liquidityFee;
    address irStrategy;
    address reinvestmentController;
    bytes irData;
  }

  struct UpdateAssetConfigParams {
    address hub;
    uint256 assetId;
    IHub.AssetConfig config;
    bytes irData;
  }

  struct AddSpokeParams {
    address hub;
    uint256 assetId;
    address spoke;
    IHub.SpokeConfig config;
  }

  struct AddSpokeToAssetsParams {
    address hub;
    address spoke;
    uint256[] assetIds;
    IHub.SpokeConfig[] configs;
  }

  struct UpdateLiquidationConfigParams {
    address spoke;
    ISpoke.LiquidationConfig config;
  }

  struct AddReserveParams {
    address spoke;
    address hub;
    uint256 assetId;
    address priceSource;
    ISpoke.ReserveConfig config;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }
}
