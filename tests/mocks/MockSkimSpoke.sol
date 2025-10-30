// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';

contract MockSkimSpoke {
  IHubBase public immutable HUB;

  constructor(address hubAddress) {
    HUB = IHubBase(hubAddress);
  }

  function skim(uint256 assetId, uint256 amount) external returns (uint256) {
    return HUB.add(assetId, amount);
  }

  function withdraw(uint256 assetId, uint256 amount, address to) external returns (uint256) {
    return HUB.remove(assetId, amount, to);
  }
}
