// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title ISpokeHook
/// @author Aave Labs
/// @notice Interface for a hook invoked before a permissionless Spoke action.
interface ISpokeHook {
  /// @notice Context of the Spoke action entering the hook.
  /// @param caller The original caller of the Spoke action.
  /// @param onBehalfOf The user whose position is affected by the action.
  /// @param selector The selector of the Spoke action.
  struct HookContext {
    address caller;
    address onBehalfOf;
    bytes4 selector;
  }

  /// @notice Called by the Spoke before executing a permissionless action.
  /// @param context The context of the Spoke action.
  function onAction(HookContext calldata context) external;
}
