// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';

// Interfaces
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

// Contracts
import {HandlerAggregator} from '../HandlerAggregator.t.sol';

/// @title SpokeInvariants
/// @notice Implements Spoke Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract SpokeInvariants is HandlerAggregator {
  using EnumerableSet for EnumerableSet.AddressSet;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          SPOKE                                             //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_INV_SP_A(ISpoke spoke, uint256 reserveId) internal {
    // Get the assetId related to the reserveId of the spoke
    uint256 assetId = _getAssetId(address(spoke), reserveId);

    IHub hub = IHub(_getHubAddress(address(spoke), reserveId));

    // supply
    assertEq(
      spoke.getReserveSuppliedShares(reserveId),
      hub.getSpokeAddedShares(assetId, address(spoke)),
      INV_SP_A
    );
    assertEq(
      spoke.getReserveSuppliedAssets(reserveId),
      hub.getSpokeAddedAssets(assetId, address(spoke)),
      INV_SP_A
    );

    // debt
    (uint256 d1, uint256 p1) = hub.getSpokeOwed(assetId, address(spoke));
    (uint256 d2, uint256 p2) = spoke.getReserveDebt(reserveId);
    assertEq(d2, d1, INV_SP_A);
    assertEq(p2, p1, INV_SP_A);
  }

  function assert_INV_SP_B(ISpoke spoke, uint256 reserveId, address user) internal {
    // reserve supply
    if (spoke.getReserveSuppliedAssets(reserveId) > 0) {
      assertGt(spoke.getReserveSuppliedShares(reserveId), 0, INV_SP_B);
    }
    // reserve debt
    if (spoke.getReserveTotalDebt(reserveId) > 0) {
      assertGt(
        IHub(_getHubAddress(address(spoke), reserveId)).getSpokeDrawnShares(
          _getAssetId(address(spoke), reserveId),
          address(spoke)
        ),
        0,
        INV_SP_B
      );
    }
    // user supply
    if (spoke.getUserSuppliedAssets(reserveId, user) > 0) {
      assertGt(spoke.getUserSuppliedShares(reserveId, user), 0, INV_SP_B);
    }
    // user debt
    if (spoke.getUserTotalDebt(reserveId, user) > 0) {
      ISpoke.UserPosition memory up = spoke.getUserPosition(reserveId, user);
      assertTrue(up.drawnShares > 0 || up.premiumShares > 0, INV_SP_B);
    }
  }

  function assert_INV_SP_C(ISpoke spoke, uint256 reserveId) internal {
    uint256 sumSpokeDebts;
    for (uint256 i; i < actors.length(); i++) {
      sumSpokeDebts += spoke.getUserTotalDebt(reserveId, actors.at(i));
    }
    assertGe(sumSpokeDebts, spoke.getReserveTotalDebt(reserveId), INV_SP_C);
  }

  function assert_INV_SP_D(ISpoke spoke, address user) internal {
    ISpoke.UserAccountData memory d = spoke.getUserAccountData(user);
    if (d.totalDebtValueRay == 0) {
      assertEq(d.healthFactor, type(uint256).max, INV_SP_D);
    } else if (d.totalCollateralValue == 0) {
      assertEq(d.healthFactor, 0, INV_SP_D);
    }
  }

  function assert_INV_SP_E(ISpoke spoke, uint256 reserveId) internal {
    uint256 sumUserShares;
    for (uint256 i; i < actors.length(); i++) {
      sumUserShares += spoke.getUserSuppliedShares(reserveId, actors.at(i));
    }
    assertEq(sumUserShares, spoke.getReserveSuppliedShares(reserveId), INV_SP_E);
  }

  function assert_INV_SP_F(ISpoke spoke, uint256 reserveId) internal {
    uint256 sumUserAssets;
    for (uint256 i; i < actors.length(); i++) {
      sumUserAssets += spoke.getUserSuppliedAssets(reserveId, actors.at(i));
    }
    uint256 reserveSuppliedAssets = spoke.getReserveSuppliedAssets(reserveId);
    assertLe(sumUserAssets, reserveSuppliedAssets, INV_SP_F);
    assertApproxEqAbs(sumUserAssets, reserveSuppliedAssets, NUMBER_OF_ACTORS, INV_SP_F);
  }

  function assert_INV_SP_H(ISpoke spoke, uint256 reserveId, address user) internal {
    uint32 userKey = spoke.getUserPosition(reserveId, user).dynamicConfigKey;
    uint32 reserveKey = spoke.getReserve(reserveId).dynamicConfigKey;
    if (userKey > 0) {
      assertLe(uint256(userKey), uint256(reserveKey), INV_SP_H);
    }
  }

  function assert_INV_SP_I(ISpoke spoke, uint256 reserveId, address user) internal {
    ISpoke.UserPosition memory up = spoke.getUserPosition(reserveId, user);
    if (up.drawnShares == 0) {
      assertEq(up.premiumShares, 0, INV_SP_I);
      assertEq(up.premiumOffsetRay, 0, INV_SP_I);
    }
  }
}
