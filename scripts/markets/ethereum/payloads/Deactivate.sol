// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

import {Hubs, Infra} from 'scripts/markets/ethereum/AaveV4Contracts.sol';

contract Deactivate {
  function execute() external {
    _deactivate(Hubs.CORE_HUB);
    _deactivate(Hubs.PLUS_HUB);
    _deactivate(Hubs.PRIME_HUB);
  }

  function _deactivate(address hub) internal {
    uint256 assetCount = IHub(hub).getAssetCount();
    for (uint256 assetId; assetId < assetCount; ++assetId) {
      IHubConfigurator(Infra.HUB_CONFIGURATOR).deactivateAsset(hub, assetId);
    }
  }
}
