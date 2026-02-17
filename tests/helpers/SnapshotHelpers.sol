// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Assertions} from 'tests/helpers/Assertions.sol';

/// @title SnapshotHelpers
/// @notice Lightweight state-capture helpers for the Aave V4 test suite.
abstract contract SnapshotHelpers is Assertions {
  struct UserSnapshot {
    uint256 tokenBalance;
    uint256 suppliedShares;
    uint256 suppliedAmount;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
    ISpoke.UserPosition position;
  }

  struct ReserveSnapshot {
    uint256 totalSuppliedShares;
    uint256 totalSuppliedAmount;
    uint256 totalDrawnDebt;
    uint256 totalPremiumDebt;
    uint256 totalDebt;
  }

  struct HubSnapshot {
    uint256 liquidity;
    uint256 addedAssets;
    uint256 addedShares;
    uint256 drawnAssets;
    uint256 drawnShares;
  }

  function _snapshotUser(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (UserSnapshot memory snap) {
    address underlying = spoke.getReserve(reserveId).underlying;
    snap.tokenBalance = IERC20(underlying).balanceOf(user);
    snap.suppliedShares = spoke.getUserPosition(reserveId, user).suppliedShares;
    snap.suppliedAmount = spoke.getUserSuppliedAssets(reserveId, user);
    (snap.drawnDebt, snap.premiumDebt) = spoke.getUserDebt(reserveId, user);
    snap.totalDebt = snap.drawnDebt + snap.premiumDebt;
    snap.position = spoke.getUserPosition(reserveId, user);
  }

  function _snapshotReserve(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (ReserveSnapshot memory snap) {
    IHub hub = IHub(address(spoke.getReserve(reserveId).hub));
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    snap.totalSuppliedShares = hub.getSpokeAddedShares(assetId, address(spoke));
    snap.totalSuppliedAmount = spoke.getReserveSuppliedAssets(reserveId);
    (snap.totalDrawnDebt, snap.totalPremiumDebt) = spoke.getReserveDebt(reserveId);
    snap.totalDebt = snap.totalDrawnDebt + snap.totalPremiumDebt;
  }

  function _snapshotHub(IHub hub, uint256 assetId) internal view returns (HubSnapshot memory snap) {
    snap.liquidity = hub.getAssetLiquidity(assetId);
    snap.addedAssets = hub.getAddedAssets(assetId);
    snap.addedShares = hub.getAddedShares(assetId);
    (snap.drawnAssets, ) = hub.getAssetOwed(assetId);
    snap.drawnShares = hub.getAsset(assetId).drawnShares;
  }
}
