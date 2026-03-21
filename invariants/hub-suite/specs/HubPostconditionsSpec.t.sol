// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title HubPostconditionsSpec
/// @notice Postconditions specification for the hub
/// @dev Contains pseudo code and description for the postcondition properties in the hub.
///      This is the canonical source for all hub postcondition strings.
///      Protocol-suite imports these via inheritance.
abstract contract HubPostconditionsSpec {
  /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - POSTCONDITIONS:
    ///   - Properties that should hold true after an action is executed.
    ///   - Implemented in the /hooks and /handlers folders.
    ///   - There are two types of POSTCONDITIONS:
    ///     - GLOBAL POSTCONDITIONS (GPOST):
    ///       - Properties that should always hold true after any action is executed.
    ///       - Checked in the `_checkPostConditions` function within the HookAggregator contract.
    ///     - HANDLER-SPECIFIC POSTCONDITIONS (HSPOST):
    ///       - Properties that should hold true after a specific action is executed in a specific context.
    ///       - Implemented within each handler function, under the HANDLER-SPECIFIC POSTCONDITIONS section.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     MONOTONICITY                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant GPOST_HUB_A =
    'GPOST_HUB_A: Drawn index cannot decrease (remains constant or increases). If no time passes, it stays constant. only increases due to interest accumulation';

  string constant GPOST_HUB_B =
    "GPOST_HUB_B: Add exchange rate (total assets / total shares) cannot decrease (remains constant or increases). If no time passes, it stays constant. it increases due to interest accumulation, premium debt settlement and donations (from actions' rounding).";

  string constant GPOST_HUB_D =
    'GPOST_HUB_D: lastUpdateTimestamp must be <= block.timestamp after any action (timestamps cannot be in the future).';

  string constant GPOST_HUB_G =
    'GPOST_HUB_G: lastUpdateTimestamp is monotonic non-decreasing across actions (time does not go backwards)';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      ACCOUNTING                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant GPOST_HUB_C =
    'GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block.';

  string constant HSPOST_HUB_M =
    'HSPOST_HUB_M: refreshPremium cannot change total premium debt (only redistribution)';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         CAPS                                              //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant GPOST_HUB_E =
    'GPOST_HUB_E: if addedAssets for a spoke & assetId increase, addedAssets <= addCap * precision (when cap != MAX)';

  string constant GPOST_HUB_F =
    'GPOST_HUB_F: if owed for a spoke & assetId increase, owed + deficit <= drawCap * precision (when cap != MAX)';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         ERC4626                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  // Add
  string constant HSPOST_HUB_ERC4626_ADD_A =
    'HSPOST_HUB_ERC4626_ADD_A: After add, spoke addedAssets must increase by at most addedAmount';

  string constant HSPOST_HUB_ERC4626_ADD_B =
    'HSPOST_HUB_ERC4626_ADD_B: After add, spoke addedShares must increase by addedSharesAmount';

  string constant HSPOST_HUB_ERC4626_ADD_C =
    'HSPOST_HUB_ERC4626_ADD_C: previewAddedShares must be less than or equal to the added shares after the action';

  // Remove
  string constant HSPOST_HUB_ERC4626_REMOVE_A =
    'HSPOST_HUB_ERC4626_REMOVE_A: After remove, spoke addedAssets must decrease by at least removedAmount';

  string constant HSPOST_HUB_ERC4626_REMOVE_B =
    'HSPOST_HUB_ERC4626_REMOVE_B: After remove, spoke addedShares must decrease by removedSharesAmount';

  string constant HSPOST_HUB_ERC4626_REMOVE_C =
    'HSPOST_HUB_ERC4626_REMOVE_C: previewRemovedShares must be greater than or equal to the removed shares after the action';

  // Draw
  string constant HSPOST_HUB_ERC4626_DRAW_A =
    'HSPOST_HUB_ERC4626_DRAW_A: After draw, spoke drawnAssets must increase by at least drawnAmount';

  string constant HSPOST_HUB_ERC4626_DRAW_B =
    'HSPOST_HUB_ERC4626_DRAW_B: After draw, spoke drawnShares must increase by drawnSharesAmount';

  string constant HSPOST_HUB_ERC4626_DRAW_C =
    'HSPOST_HUB_ERC4626_DRAW_C: previewDrawnShares must be greater than or equal to the drawn shares after the action';

  // Restore
  string constant HSPOST_HUB_ERC4626_RESTORE_A =
    'HSPOST_HUB_ERC4626_RESTORE_A: After restore, spoke drawnAssets must increase by at most drawnAmount';

  string constant HSPOST_HUB_ERC4626_RESTORE_B =
    'HSPOST_HUB_ERC4626_RESTORE_B: After restore, spoke drawnShares must decrease by restoredSharesAmount';

  string constant HSPOST_HUB_ERC4626_RESTORE_C =
    'HSPOST_HUB_ERC4626_RESTORE_C: previewRestoredShares must be less than or equal to the restored shares after the action';
}
