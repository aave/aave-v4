// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';

contract MockSkimSpoke {
  IHubBase public immutable HUB;

  constructor(address hub_) {
    HUB = IHubBase(hub_);
  }

  function skimAdd(uint256 assetId, uint256 amount) external returns (uint256) {
    return HUB.add(assetId, amount);
  }

  function withdraw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    return HUB.remove(assetId, amount, to);
  }

  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    return HUB.draw(assetId, amount, to);
  }

  function skimRestore(uint256 assetId, uint256 drawnAmount) external returns (uint256) {
    return HUB.restore(assetId, drawnAmount, IHubBase.PremiumDelta(0, 0, 0, 0));
  }
}
