// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title HubInvariantsSpec
/// @notice Invariants specification for the hub
/// @dev Contains pseudo code and description for the invariant properties in the hub.
///      This is the canonical source for all hub invariant strings.
///      Protocol-suite imports these via inheritance.
abstract contract HubInvariantsSpec {
  /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV):
    ///   - Properties that should always hold true in the system.
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      ACCOUNTING                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant INV_HUB_A = 'INV_HUB_A: If hub assets = 0 => shares 0';

  string constant INV_HUB_B =
    'INV_HUB_B: Sum of spoke debts on a single asset must be greater or equal than the total debt of the asset';

  string constant INV_HUB_C =
    'INV_HUB_C: Sum of [baseDrawnShares/premiumDrawnShares/premiumOffsetRay] of individual (spoke/user) should match the corresponding value of the asset on the Hub';

  string constant INV_HUB_G =
    'INV_HUB_G: totalAddedAssets = sum of addedAssets of all registered spokes (including present & past treasury spoke) with a tolerance of SPOKE_COUNT';

  string constant INV_HUB_H =
    'INV_HUB_H: totalAddedShares = sum of addedShares of all registered spokes';

  string constant INV_HUB_O =
    'INV_HUB_O: sum of deficitRay across spokes for a given asset == total asset deficitRay';

  string constant INV_HUB_P =
    'INV_HUB_P: Premium offset should not exceed premium shares * drawnIndex';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       SOLVENCY                                            //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant INV_HUB_E_1 =
    'INV_HUB_E: total assets is equal to or greater than the supplied amount without taking into account the virtual assets and shares up to the burn interest to virtual shares';

  string constant INV_HUB_E_2 =
    'INV_HUB_E: total assets is equal to the supplied amount when taking into account the virtual assets and shares';

  string constant INV_HUB_F =
    'INV_HUB_F: hub.getTotalSuppliedAssets = totalAssets() = availableLiquidity + (totalDebtRay + deficitRay).fromRayUp + swept';

  string constant INV_HUB_I =
    'INV_HUB_I: asset.underlying.balanceOf(hub) + asset.swept >= asset.liquidity';

  string constant INV_HUB_K =
    'INV_HUB_K: Asset.irStrategy should never be address(0) for any (currently/previously) registered asset';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     MONOTONICITY                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant INV_HUB_Q =
    'INV_HUB_Q: Drawn index must be monotonically non-decreasing across invariant checks';

  string constant INV_HUB_R =
    'INV_HUB_R: Supply share price (addedAssets/addedShares) must be monotonically non-decreasing across invariant checks';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         ERC4626                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant INV_HUB_ERC4626_A =
    'INV_HUB_ERC4626_A: Spoke cannot have non-zero assets and zero shares in add side without any premium';

  string constant INV_HUB_ERC4626_B =
    'INV_HUB_ERC4626_B: Spoke cannot have non-zero assets and zero shares in draw side';

  string constant INV_HUB_ERC4626_C =
    'INV_HUB_ERC4626_C: Asset cannot have non-zero assets and zero shares in add side without any premium';

  string constant INV_HUB_ERC4626_D =
    'INV_HUB_ERC4626_D: Asset cannot have non-zero assets and zero shares in draw side';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         ERC4626 ROUNDTRIP                                 //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev ERC4626: redeem(deposit(a)) <= a
  string constant INV_HUB_ERC4626_RT_A =
    'INV_HUB_ERC4626_RT_A: previewRemoveByShares(previewAddByAssets(a)) <= a';

  /// @dev ERC4626: s = deposit(a), s' = withdraw(a), s' >= s
  string constant INV_HUB_ERC4626_RT_B =
    'INV_HUB_ERC4626_RT_B: previewRemoveByAssets(a) >= previewAddByAssets(a)';

  /// @dev ERC4626: deposit(redeem(s)) <= s
  string constant INV_HUB_ERC4626_RT_C =
    'INV_HUB_ERC4626_RT_C: previewAddByAssets(previewRemoveByShares(s)) <= s';

  /// @dev ERC4626: a = redeem(s), a' = mint(s), a' >= a
  string constant INV_HUB_ERC4626_RT_D =
    'INV_HUB_ERC4626_RT_D: previewAddByShares(s) >= previewRemoveByShares(s)';

  /// @dev ERC4626: withdraw(mint(s)) >= s
  string constant INV_HUB_ERC4626_RT_E =
    'INV_HUB_ERC4626_RT_E: previewRemoveByAssets(previewAddByShares(s)) >= s';

  /// @dev ERC4626: a = mint(s), a' = redeem(s), a' <= a
  string constant INV_HUB_ERC4626_RT_F =
    'INV_HUB_ERC4626_RT_F: previewRemoveByShares(s) <= previewAddByShares(s)';

  /// @dev ERC4626: mint(withdraw(a)) >= a
  string constant INV_HUB_ERC4626_RT_G =
    'INV_HUB_ERC4626_RT_G: previewAddByShares(previewRemoveByAssets(a)) >= a';

  /// @dev ERC4626: s = withdraw(a), s' = deposit(a), s' <= s
  string constant INV_HUB_ERC4626_RT_H =
    'INV_HUB_ERC4626_RT_H: previewAddByAssets(a) <= previewRemoveByAssets(a)';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     AVAILABILITY                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant INV_HUB_AVAILABILITY_A = 'INV_HUB_AVAILABILITY_A: getAddedAssets must not revert';

  string constant INV_HUB_AVAILABILITY_B = 'INV_HUB_AVAILABILITY_B: getAssetOwed must not revert';

  string constant INV_HUB_AVAILABILITY_C =
    'INV_HUB_AVAILABILITY_C: getAssetTotalOwed must not revert';

  string constant INV_HUB_AVAILABILITY_D =
    'INV_HUB_AVAILABILITY_D: getAssetPremiumRay must not revert';

  string constant INV_HUB_AVAILABILITY_E =
    'INV_HUB_AVAILABILITY_E: getAssetAccruedFees must not revert';

  string constant INV_HUB_AVAILABILITY_F =
    'INV_HUB_AVAILABILITY_F: getSpokeAddedAssets must not revert';

  string constant INV_HUB_AVAILABILITY_G = 'INV_HUB_AVAILABILITY_G: getSpokeOwed must not revert';

  string constant INV_HUB_AVAILABILITY_H =
    'INV_HUB_AVAILABILITY_H: getSpokeTotalOwed must not revert';

  string constant INV_HUB_AVAILABILITY_I =
    'INV_HUB_AVAILABILITY_I: getSpokePremiumRay must not revert';
}
