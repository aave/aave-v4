// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {HubInvariants} from './invariants/HubInvariants.t.sol';

/// @title Invariants
/// @notice Aggregator for hub invariants
abstract contract Invariants is HubInvariants {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      ACCOUNTING                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB_ACCOUNTING() public returns (bool) {
    uint256 assetCount = hub.getAssetCount();
    for (uint256 i; i < assetCount; i++) {
      assert_INV_HUB_A(hub, i);
      assert_INV_HUB_B(hub, i);
      assert_INV_HUB_C(hub, i);
      assert_INV_HUB_GH(hub, i);
      assert_INV_HUB_O(hub, i);
      assert_INV_HUB_P(hub, i);
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       SOLVENCY                                            //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB_SOLVENCY() public returns (bool) {
    uint256 assetCount = hub.getAssetCount();
    for (uint256 i; i < assetCount; i++) {
      assert_INV_HUB_E(hub, i);
      assert_INV_HUB_F(hub, i);
      assert_INV_HUB_I(hub, i);
      assert_INV_HUB_K(hub, i);
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     MONOTONICITY                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB_MONOTONICITY() public returns (bool) {
    uint256 assetCount = hub.getAssetCount();
    for (uint256 i; i < assetCount; i++) {
      assert_INV_HUB_Q(hub, i);
      assert_INV_HUB_R(hub, i);
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                        ERC4626                                            //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB_ERC4626() public returns (bool) {
    uint256 assetCount = hub.getAssetCount();
    for (uint256 i; i < assetCount; i++) {
      for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
        assert_INV_HUB_ERC4626_A(i, actors[j]);
        assert_INV_HUB_ERC4626_B(i, actors[j]);
      }
      assert_INV_HUB_ERC4626_C(i);
      assert_INV_HUB_ERC4626_D(i);
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     AVAILABILITY                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB_AVAILABILITY() public returns (bool) {
    uint256 assetCount = hub.getAssetCount();
    for (uint256 i; i < assetCount; i++) {
      assert_INV_HUB_AVAILABILITY_A(i);
      assert_INV_HUB_AVAILABILITY_B(i);
      assert_INV_HUB_AVAILABILITY_C(i);
      assert_INV_HUB_AVAILABILITY_D(i);
      assert_INV_HUB_AVAILABILITY_E(i);
      for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
        assert_INV_HUB_AVAILABILITY_F(i, actors[j]);
        assert_INV_HUB_AVAILABILITY_G(i, actors[j]);
        assert_INV_HUB_AVAILABILITY_H(i, actors[j]);
        assert_INV_HUB_AVAILABILITY_I(i, actors[j]);
      }
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    REPLAY HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _checkAllHubInvariants() internal {
    assertTrue(invariant_INV_HUB_ACCOUNTING());
    assertTrue(invariant_INV_HUB_SOLVENCY());
    assertTrue(invariant_INV_HUB_MONOTONICITY());
    assertTrue(invariant_INV_HUB_ERC4626());
    assertTrue(invariant_INV_HUB_AVAILABILITY());
  }
}
