// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {IHub} from 'src/hub/interfaces/IHub.sol';

// Contracts
import {HubInvariantAssertions} from './HubInvariantAssertions.t.sol';
import {HandlerAggregator} from '../HandlerAggregator.t.sol';

/// @title HubInvariants
/// @notice Implements Hub Invariants for the hub-suite.
/// @dev Common invariant assertions are inherited from HubInvariantAssertions.
///      This contract adds ERC4626 and AVAILABILITY invariants specific to the hub-suite.
abstract contract HubInvariants is HandlerAggregator, HubInvariantAssertions {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   VIRTUAL OVERRIDES                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Returns actorAddresses + feeReceiver for the given hub and asset.
  function _getSpokesForAsset(
    IHub hub,
    uint256 assetId
  ) internal view override returns (address[] memory) {
    address feeReceiver = hub.getAsset(assetId).feeReceiver;
    uint256 count = NUMBER_OF_ACTORS;
    address[] memory spokes = new address[](count + 1);
    for (uint256 i; i < count; i++) {
      spokes[i] = actors[i];
    }
    spokes[count] = feeReceiver;
    return spokes;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    HUB: ERC4626                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_INV_HUB_ERC4626_A(uint256 assetId, address spoke) internal {
    uint256 addedAssets = hub.getSpokeAddedAssets(assetId, spoke);
    uint256 addedShares = hub.getSpokeAddedShares(assetId, spoke);
    uint256 premiumRay = hub.getAssetPremiumRay(assetId);
    // since premium can be incurred without drawing liquidity
    if (addedAssets != 0 && premiumRay == 0) {
      assertTrue(addedShares != 0, INV_HUB_ERC4626_A);
    }
  }

  function assert_INV_HUB_ERC4626_B(uint256 assetId, address spoke) internal {
    (uint256 drawnAssets, ) = hub.getSpokeOwed(assetId, spoke);
    uint256 drawnShares = hub.getSpokeDrawnShares(assetId, spoke);
    if (drawnAssets != 0) assertTrue(drawnShares != 0, INV_HUB_ERC4626_B);
  }

  function assert_INV_HUB_ERC4626_C(uint256 assetId) internal {
    uint256 addedAssets = hub.getAddedAssets(assetId);
    uint256 addedShares = hub.getAddedShares(assetId);
    uint256 premiumRay = hub.getAssetPremiumRay(assetId);
    // since premium can be incurred without drawing liquidity
    if (addedAssets != 0 && premiumRay == 0) {
      assertTrue(addedShares != 0, INV_HUB_ERC4626_C);
    }
  }

  function assert_INV_HUB_ERC4626_D(uint256 assetId) internal {
    (uint256 drawnAssets, ) = hub.getAssetOwed(assetId);
    uint256 drawnShares = hub.getAssetDrawnShares(assetId);
    if (drawnAssets != 0) assertTrue(drawnShares != 0, INV_HUB_ERC4626_D);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     HUB: AVAILABILITY                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_INV_HUB_AVAILABILITY_A(uint256 assetId) internal {
    try hub.getAddedAssets(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_A);
    }
  }

  function assert_INV_HUB_AVAILABILITY_B(uint256 assetId) internal {
    try hub.getAssetOwed(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_B);
    }
  }

  function assert_INV_HUB_AVAILABILITY_C(uint256 assetId) internal {
    try hub.getAssetTotalOwed(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_C);
    }
  }

  function assert_INV_HUB_AVAILABILITY_D(uint256 assetId) internal {
    try hub.getAssetPremiumRay(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_D);
    }
  }

  function assert_INV_HUB_AVAILABILITY_E(uint256 assetId) internal {
    try hub.getAssetAccruedFees(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_E);
    }
  }

  function assert_INV_HUB_AVAILABILITY_F(uint256 assetId, address spoke) internal {
    try hub.getSpokeAddedAssets(assetId, spoke) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_F);
    }
  }

  function assert_INV_HUB_AVAILABILITY_G(uint256 assetId, address spoke) internal {
    try hub.getSpokeOwed(assetId, spoke) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_G);
    }
  }

  function assert_INV_HUB_AVAILABILITY_H(uint256 assetId, address spoke) internal {
    try hub.getSpokeTotalOwed(assetId, spoke) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_H);
    }
  }

  function assert_INV_HUB_AVAILABILITY_I(uint256 assetId, address spoke) internal {
    try hub.getSpokePremiumRay(assetId, spoke) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_I);
    }
  }
}
