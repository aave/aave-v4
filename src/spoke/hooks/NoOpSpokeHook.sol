// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpokeHook} from 'src/spoke/interfaces/ISpokeHook.sol';

/// @title NoOpSpokeHook
/// @author Aave Labs
/// @notice Hook implementation that allows every supported Spoke action.
contract NoOpSpokeHook is ISpokeHook {
  /// @inheritdoc ISpokeHook
  function onAction(HookContext calldata) external pure {}
}
