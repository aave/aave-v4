// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {HubQueryHelpers} from 'tests/helpers/hub/HubQueryHelpers.sol';
import {HubActions} from 'tests/helpers/hub/HubActions.sol';
import {HubConstants} from 'tests/helpers/hub/HubConstants.sol';
import {SpokeConstants} from 'tests/helpers/spoke/SpokeConstants.sol';

/// @title HubSetupHelpers
/// @notice Hub-level state-mutating test setup utilities.
abstract contract HubSetupHelpers is HubQueryHelpers {
  using SafeCast for *;

  /// @dev mocks rate, addSpoke (addUser) adds asset, drawSpoke (drawUser) draws asset, skips time
  function _addAndDrawLiquidity(
    IHub hub,
    uint256 assetId,
    address addUser,
    address addSpoke,
    uint256 addAmount,
    address drawUser,
    address drawSpoke,
    uint256 drawAmount,
    uint256 skipTime
  ) internal returns (uint256 addedShares, uint256 drawnShares) {
    addedShares = HubActions.add({
      hub: hub,
      assetId: assetId,
      caller: addSpoke,
      amount: addAmount,
      user: addUser
    });

    drawnShares = HubActions.draw({
      hub: hub,
      assetId: assetId,
      to: drawUser,
      caller: drawSpoke,
      amount: drawAmount
    });

    skip(skipTime);
  }

  /// @dev Draws liquidity from the Hub via a new temp spoke (creates and registers it)
  function _drawLiquidityViaTempSpoke(
    IHub hub,
    uint256 assetId,
    uint256 amount,
    bool withPremium,
    bool skipTime,
    address hubAdmin
  ) internal {
    address tempSpoke = vm.randomAddress();

    vm.prank(hubAdmin);
    hub.addSpoke(
      assetId,
      tempSpoke,
      IHub.SpokeConfig({
        active: true,
        halted: false,
        addCap: HubConstants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: HubConstants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: SpokeConstants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );

    _drawLiquidity(hub, assetId, amount, withPremium, skipTime, tempSpoke);
  }

  // @dev Draws liquidity from the Hub via a new temp spoke, always skips time
  function _drawLiquidity(
    IHub hub,
    uint256 assetId,
    uint256 amount,
    bool premium,
    address hubAdmin
  ) internal {
    _drawLiquidityViaTempSpoke(hub, assetId, amount, premium, true, hubAdmin);
  }

  /// @dev Draws liquidity from the Hub via a specific spoke
  function _drawLiquidity(
    IHub hub,
    uint256 assetId,
    uint256 amount,
    bool withPremium,
    bool skipTime,
    address spoke
  ) internal {
    HubActions.draw(hub, assetId, spoke, vm.randomAddress(), amount);
    int256 oldPremiumOffsetRay = _calculatePremiumAssetsRay(hub, assetId, amount).toInt256();

    if (withPremium) {
      // inflate premium data to create premium debt
      IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
        hub: hub,
        assetId: assetId,
        oldPremiumShares: 0,
        oldPremiumOffsetRay: 0,
        drawnShares: amount,
        riskPremium: 100_00,
        restoredPremiumRay: 0
      });
      vm.prank(spoke);
      hub.refreshPremium(assetId, premiumDelta);
    }

    if (skipTime) skip(365 days);

    (uint256 drawn, uint256 premium) = hub.getAssetOwed(assetId);
    assertGt(drawn, 0); // non-zero drawn debt

    if (withPremium) {
      assertGt(premium, 0); // non-zero premium debt
      // restore premium data
      IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
        hub: hub,
        assetId: assetId,
        oldPremiumShares: amount,
        oldPremiumOffsetRay: oldPremiumOffsetRay,
        drawnShares: 0, // risk premium is 0
        riskPremium: 0,
        restoredPremiumRay: 0
      });
      vm.prank(spoke);
      hub.refreshPremium(assetId, premiumDelta);
    }
  }

  /// @dev Adds liquidity to the Hub via a random spoke
  function _addLiquidity(IHub hub, uint256 assetId, uint256 amount, address admin) public {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    uint256 initialLiq = hub.getAssetLiquidity(assetId);

    address underlying = hub.getAsset(assetId).underlying;
    deal(underlying, tempUser, amount);

    vm.prank(tempUser);
    IERC20(underlying).approve(tempSpoke, UINT256_MAX);

    vm.prank(admin);
    hub.addSpoke(
      assetId,
      tempSpoke,
      IHub.SpokeConfig({
        active: true,
        halted: false,
        addCap: HubConstants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: HubConstants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: SpokeConstants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );

    HubActions.add({hub: hub, assetId: assetId, caller: tempSpoke, amount: amount, user: tempUser});

    assertEq(hub.getAssetLiquidity(assetId), initialLiq + amount);
  }

  function _snapshotHub(IHub hub, uint256 assetId) internal view returns (HubSnapshot memory snap) {
    snap.liquidity = hub.getAssetLiquidity(assetId);
    snap.addedAssets = hub.getAddedAssets(assetId);
    snap.addedShares = hub.getAddedShares(assetId);
    (snap.drawnAssets, ) = hub.getAssetOwed(assetId);
    snap.drawnShares = hub.getAsset(assetId).drawnShares;
  }
}
