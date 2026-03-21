// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Libraries
import {Premium} from 'src/hub/libraries/Premium.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

// Interfaces
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

// Specs
import {HubInvariantsSpec} from '../specs/HubInvariantsSpec.t.sol';

// Assertions
import {StdAsserts} from '../../shared/utils/StdAsserts.sol';

/// @title HubInvariantAssertions
/// @notice Abstract hub invariant assertion logic, importable by any suite.
/// @dev Does not inherit any suite-specific base class. Concrete suites override
///      `_getSpokesForAsset` to supply the spoke list for iteration.
abstract contract HubInvariantAssertions is StdAsserts, HubInvariantsSpec {
  using SafeCast for *;
  using WadRayMath for *;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                 STATEFUL INVARIANT STORAGE                                //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Last seen drawn index per hub per assetId (INV_HUB_Q)
  mapping(IHub => mapping(uint256 => uint256)) internal _lastSeenDebtSharePrice;
  /// @notice Last seen added assets (+ virtual) per hub per assetId (INV_HUB_R)
  mapping(IHub => mapping(uint256 => uint256)) internal _lastSeenAssets;
  /// @notice Last seen added shares (+ virtual) per hub per assetId (INV_HUB_R)
  mapping(IHub => mapping(uint256 => uint256)) internal _lastSeenShares;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     VIRTUAL HOOKS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Returns the list of spokes to iterate for a given hub and asset.
  ///      Hub-suite returns actorAddresses + feeReceiver; protocol-suite returns allSpokes.
  function _getSpokesForAsset(
    IHub hub,
    uint256 assetId
  ) internal view virtual returns (address[] memory);

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    HUB INVARIANTS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_INV_HUB_A(IHub hub, uint256 assetId) internal {
    uint256 assets = hub.getAddedAssets(assetId);

    if (assets == 0) {
      assertEq(hub.getAddedShares(assetId), 0, INV_HUB_A);
    }
  }

  function assert_INV_HUB_B(IHub hub, uint256 assetId) internal {
    address[] memory spokes = _getSpokesForAsset(hub, assetId);
    uint256 spokeCount = spokes.length;
    uint256 sumDebt;

    for (uint256 i; i < spokeCount; i++) {
      sumDebt += hub.getSpokeTotalOwed(assetId, spokes[i]);
    }

    uint256 assetTotal = hub.getAssetTotalOwed(assetId);
    assertGe(sumDebt, assetTotal, INV_HUB_B);
  }

  function assert_INV_HUB_C(IHub hub, uint256 assetId) internal {
    address[] memory spokes = _getSpokesForAsset(hub, assetId);
    uint256 spokeCount = spokes.length;

    uint256 sumDrawnShares;
    uint256 sumPremDrawnShares;
    int256 sumPremOffsetRay;

    for (uint256 i; i < spokeCount; i++) {
      address spoke = spokes[i];
      sumDrawnShares += hub.getSpokeDrawnShares(assetId, spoke);
      (uint256 premiumDrawnShares, int256 premiumOffsetRay) = hub.getSpokePremiumData(
        assetId,
        spoke
      );
      sumPremDrawnShares += premiumDrawnShares;
      sumPremOffsetRay += premiumOffsetRay;
    }

    // Asset totals
    IHub.Asset memory asset = hub.getAsset(assetId);

    // Checks
    assertEq(sumDrawnShares, asset.drawnShares, INV_HUB_C);
    assertEq(sumPremDrawnShares, asset.premiumShares, INV_HUB_C);
    assertEq(sumPremOffsetRay, asset.premiumOffsetRay, INV_HUB_C);
  }

  function assert_INV_HUB_E(IHub hub, uint256 assetId) internal {
    uint256 totalAssets = hub.getAddedAssets(assetId);
    uint256 totalShares = hub.getAddedShares(assetId);

    // interest accrued on virtual shares
    uint256 burntInterest = totalAssets - hub.previewRemoveByShares(assetId, totalShares);

    // Checks: totalAddedAssets ≈ previewRemoveByShares(totalAddedShares)
    // Tolerance: the virtual offset (V=1e6) absorbs a fraction of accrued interest when
    // converting all shares back to assets.
    assertApproxEqAbs(
      totalAssets,
      hub.previewRemoveByShares(assetId, totalShares), // round down
      burntInterest,
      INV_HUB_E_1
    );

    assertGe(
      totalAssets + SharesMath.VIRTUAL_ASSETS,
      hub.previewRemoveByShares(assetId, totalShares + SharesMath.VIRTUAL_ASSETS),
      INV_HUB_E_2
    );
  }

  function assert_INV_HUB_F(IHub hub, uint256 assetId) internal {
    uint256 totalAssets = hub.getAddedAssets(assetId);
    uint256 accruedFees = hub.getAssetAccruedFees(assetId);

    IHub.Asset memory asset = hub.getAsset(assetId);
    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    uint256 premiumRay = Premium.calculatePremiumRay({
      premiumShares: asset.premiumShares,
      premiumOffsetRay: asset.premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    uint256 drawnRay = asset.drawnShares * drawnIndex;
    uint256 aggregatedOwed = (drawnRay + premiumRay + asset.deficitRay).fromRayUp();

    assertEq(totalAssets + accruedFees, asset.liquidity + aggregatedOwed + asset.swept, INV_HUB_F);
  }

  function assert_INV_HUB_GH(IHub hub, uint256 assetId) internal {
    address[] memory spokes = _getSpokesForAsset(hub, assetId);
    uint256 spokeCount = spokes.length;
    uint256 tolerancePerActor = hub.previewAddByShares(assetId, 1);

    // Sum per-spoke values
    uint256 totalAddedAssets;
    uint256 totalAddedShares;
    for (uint256 i; i < spokeCount; i++) {
      totalAddedAssets += hub.getSpokeAddedAssets(assetId, spokes[i]);
      totalAddedShares += hub.getSpokeAddedShares(assetId, spokes[i]);
    }

    // Inline burnt interest: interest accrued on virtual shares
    {
      uint256 totalAssets = hub.getAddedAssets(assetId);
      uint256 totalShares = hub.getAddedShares(assetId);
      totalAddedAssets += totalAssets - hub.previewRemoveByShares(assetId, totalShares);
    }

    // Checks
    uint256 addedShares = hub.getAddedShares(assetId);
    if (addedShares > 0) {
      assertApproxEqAbs(
        totalAddedAssets,
        hub.getAddedAssets(assetId),
        (spokeCount + 2) * tolerancePerActor,
        INV_HUB_G
      );
    }
    assertEq(totalAddedShares, hub.getAddedShares(assetId), INV_HUB_H);
  }

  function assert_INV_HUB_I(IHub hub, uint256 assetId) internal {
    // Get underlying from assetId
    (address underlying, ) = hub.getAssetUnderlyingAndDecimals(assetId);

    // Query values
    uint256 liquidity = hub.getAssetLiquidity(assetId);
    uint256 swept = hub.getAssetSwept(assetId);
    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(hub));

    // Checks
    assertGe(underlyingBalance + swept, liquidity, INV_HUB_I);
  }

  function assert_INV_HUB_K(IHub hub, uint256 assetId) internal {
    IHub.AssetConfig memory assetConfig = hub.getAssetConfig(assetId);

    // Checks
    assertTrue(assetConfig.irStrategy != address(0), INV_HUB_K);
  }

  function assert_INV_HUB_O(IHub hub, uint256 assetId) internal {
    address[] memory spokes = _getSpokesForAsset(hub, assetId);
    uint256 spokeCount = spokes.length;
    uint256 totalDeficitRay;
    for (uint256 i; i < spokeCount; i++) {
      totalDeficitRay += hub.getSpokeDeficitRay(assetId, spokes[i]);
    }
    assertEq(totalDeficitRay, hub.getAssetDeficitRay(assetId), INV_HUB_O);
  }

  function assert_INV_HUB_P(IHub hub, uint256 assetId) internal {
    (uint256 premiumShares, int256 premiumOffsetRay) = hub.getAssetPremiumData(assetId);
    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);
    assertGe((premiumShares * drawnIndex).toInt256(), premiumOffsetRay, INV_HUB_P);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                 STATEFUL HUB INVARIANTS                                   //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_INV_HUB_Q(IHub hub, uint256 assetId) internal {
    uint256 lastIndex = _lastSeenDebtSharePrice[hub][assetId];
    uint256 currentIndex = hub.getAssetDrawnIndex(assetId);
    assertGe(currentIndex, WadRayMath.RAY, INV_HUB_Q);
    if (lastIndex > 0) {
      assertGe(currentIndex, lastIndex, INV_HUB_Q);
    }
    _lastSeenDebtSharePrice[hub][assetId] = currentIndex;
  }

  function assert_INV_HUB_R(IHub hub, uint256 assetId) internal {
    uint256 lastAssets = _lastSeenAssets[hub][assetId];
    uint256 lastShares = _lastSeenShares[hub][assetId];
    uint256 assets = hub.getAddedAssets(assetId) + SharesMath.VIRTUAL_ASSETS;
    uint256 shares = hub.getAddedShares(assetId) + SharesMath.VIRTUAL_SHARES;
    if (lastShares > 0) {
      // assets/shares >= lastAssets/lastShares  <=>  assets * lastShares >= lastAssets * shares
      assertFullMulGe(assets, lastShares, lastAssets, shares, INV_HUB_R);
    }
    _lastSeenAssets[hub][assetId] = assets;
    _lastSeenShares[hub][assetId] = shares;
  }
}
