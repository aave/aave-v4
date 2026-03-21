// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';

// Interfaces
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

// Hub invariant assertions (imported from hub-suite)
import {HubInvariantAssertions} from '../hub-suite/invariants/HubInvariantAssertions.t.sol';

// Spoke invariants (protocol-suite)
import {SpokeInvariants} from './invariants/SpokeInvariants.t.sol';

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognized by Echidna when property mode is activated
/// @dev Inherits HubInvariantAssertions, SpokeInvariants
abstract contract Invariants is SpokeInvariants, HubInvariantAssertions {
  using EnumerableSet for EnumerableSet.AddressSet;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   VIRTUAL OVERRIDES                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Returns allSpokes for the given hub (includes treasury spokes).
  function _getSpokesForAsset(IHub, uint256) internal view override returns (address[] memory) {
    return allSpokes;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    HUB ACCOUNTING                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB_ACCOUNTING() public returns (bool) {
    for (uint256 i; i < hubs.length(); i++) {
      IHub hub = IHub(hubs.at(i));
      uint256 assetCount = hub.getAssetCount();
      for (uint256 j; j < assetCount; j++) {
        assert_INV_HUB_A(hub, j);
        assert_INV_HUB_B(hub, j);
        assert_INV_HUB_C(hub, j);
        assert_INV_HUB_GH(hub, j);
        assert_INV_HUB_O(hub, j);
        assert_INV_HUB_P(hub, j);
      }
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     HUB SOLVENCY                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB_SOLVENCY() public returns (bool) {
    for (uint256 i; i < hubs.length(); i++) {
      IHub hub = IHub(hubs.at(i));
      uint256 assetCount = hub.getAssetCount();
      for (uint256 j; j < assetCount; j++) {
        assert_INV_HUB_E(hub, j);
        assert_INV_HUB_F(hub, j);
        assert_INV_HUB_I(hub, j);
        assert_INV_HUB_K(hub, j);
      }
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   HUB MONOTONICITY                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB_MONOTONICITY() public returns (bool) {
    for (uint256 i; i < hubs.length(); i++) {
      IHub hub = IHub(hubs.at(i));
      uint256 assetCount = hub.getAssetCount();
      for (uint256 j; j < assetCount; j++) {
        assert_INV_HUB_Q(hub, j);
        assert_INV_HUB_R(hub, j);
      }
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      SPOKE SYNC                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_SP_SYNC() public returns (bool) {
    // Applied per user-facing spoke
    for (uint256 i; i < spokes.length(); i++) {
      ISpoke spoke = ISpoke(spokes.at(i));
      uint256 reserveCount = spoke.getReserveCount();
      for (uint256 j; j < reserveCount; j++) {
        assert_INV_SP_A(spoke, j);
      }
    }

    // Applied per treasury spoke (only hub-sync invariant applies;
    // user-level invariants don't apply since TreasurySpoke has no per-user positions)
    for (uint256 i; i < treasurySpokes.length(); i++) {
      ISpoke spoke = ISpoke(treasurySpokes.at(i));
      // reserveId == assetId for treasury spoke
      uint256 reserveCount = IHub(address(ITreasurySpoke(address(spoke)).HUB())).getAssetCount();
      for (uint256 j; j < reserveCount; j++) {
        assert_INV_SP_A(spoke, j);
      }
    }

    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   SPOKE ACCOUNTING                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_SP_ACCOUNTING() public returns (bool) {
    for (uint256 i; i < spokes.length(); i++) {
      ISpoke spoke = ISpoke(spokes.at(i));
      uint256 reserveCount = spoke.getReserveCount();
      for (uint256 j; j < reserveCount; j++) {
        assert_INV_SP_C(spoke, j);
        assert_INV_SP_E(spoke, j);
        assert_INV_SP_F(spoke, j);
        for (uint256 k; k < actors.length(); k++) {
          assert_INV_SP_B(spoke, j, actors.at(k));
        }
      }
    }
    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      SPOKE RISK                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_SP_RISK() public returns (bool) {
    for (uint256 i; i < spokes.length(); i++) {
      ISpoke spoke = ISpoke(spokes.at(i));

      // Applied per actor on the spoke
      for (uint256 j; j < actors.length(); j++) {
        assert_INV_SP_D(spoke, actors.at(j));
      }

      // Applied per reserve per actor of the spoke
      uint256 reserveCount = spoke.getReserveCount();
      for (uint256 j; j < reserveCount; j++) {
        for (uint256 k; k < actors.length(); k++) {
          assert_INV_SP_H(spoke, j, actors.at(k));
          assert_INV_SP_I(spoke, j, actors.at(k));
        }
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
  }

  function _checkAllSpokeInvariants() internal {
    assertTrue(invariant_INV_SP_SYNC());
    assertTrue(invariant_INV_SP_ACCOUNTING());
    assertTrue(invariant_INV_SP_RISK());
  }
}
