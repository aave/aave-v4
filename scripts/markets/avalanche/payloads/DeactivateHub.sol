// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Infra, Hubs} from 'scripts/markets/avalanche/AaveV4Contracts.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

contract DeactivateHub {
  function execute() public {
    _deactivateHub(Hubs.CORE_HUB);
  }

  function _deactivateHub(address hub) internal {
    uint256 assetCount = IHub(hub).getAssetCount();
    for (uint256 assetId; assetId < assetCount; ++assetId) {
      IHubConfigurator(Infra.HUB_CONFIGURATOR).deactivateAsset(hub, assetId);
    }
  }
}
