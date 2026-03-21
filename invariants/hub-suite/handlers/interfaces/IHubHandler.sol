// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHub.sol';

/// @title IHubHandler
/// @notice Interface for hub handler actions
interface IHubHandler {
  function add(uint256 amount, uint8 i) external returns (uint256 addedShares);

  function remove(uint256 amount, uint8 i) external returns (uint256 removedShares);

  function draw(uint256 amount, uint8 i) external returns (uint256 drawnShares);

  function restore(
    uint256 drawnAmount,
    uint256 premiumAmount,
    int256 sharesDelta,
    uint8 i
  ) external returns (uint256 restoredDrawnShares);

  function reportDeficit(
    uint256 drawnAmount,
    uint256 premiumAmount,
    int256 sharesDelta,
    uint8 i
  ) external;

  function eliminateDeficit(uint256 amount, uint8 i) external;

  function refreshPremium(int256 sharesDelta, uint8 i) external;

  function refreshPremiumBroad(IHubBase.PremiumDelta memory premiumDelta, uint8 i) external;

  function payFeeShares(uint256 shares, uint8 i) external;

  function transferShares(uint256 shares, uint8 i, uint8 j) external;

  function sweep(uint256 amount, uint8 i) external;

  function reclaim(uint256 amount, uint8 i) external;

  function mintFeeShares(uint8 i) external;

  function roundtrip_ERC4626_RT_A(uint256 amount, uint8 i) external;

  function roundtrip_ERC4626_RT_B(uint256 amount, uint8 i) external;

  function roundtrip_ERC4626_RT_C(uint256 shares, uint8 i) external;

  function roundtrip_ERC4626_RT_D(uint256 shares, uint8 i) external;

  function roundtrip_ERC4626_RT_E(uint256 shares, uint8 i) external;

  function roundtrip_ERC4626_RT_F(uint256 shares, uint8 i) external;

  function roundtrip_ERC4626_RT_G(uint256 amount, uint8 i) external;

  function roundtrip_ERC4626_RT_H(uint256 amount, uint8 i) external;
}
