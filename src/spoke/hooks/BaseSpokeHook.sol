// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeHook} from 'src/spoke/interfaces/ISpokeHook.sol';

/// @title BaseSpokeHook
/// @author Aave Labs
/// @notice Base contract that authenticates a Spoke and routes generic hook context to typed hooks.
/// @dev Override only the action hooks needed by an implementation. All hooks are no-ops by default.
abstract contract BaseSpokeHook is ISpokeHook {
  /// @notice The only Spoke allowed to invoke this hook.
  address public immutable SPOKE;

  /// @notice Thrown when the Spoke address is invalid.
  error InvalidSpoke();

  /// @notice Thrown when the caller is not the configured Spoke.
  error UnauthorizedCaller(address caller);

  /// @notice Thrown when the action selector is not supported by the base hook.
  error UnsupportedSelector(bytes4 selector);

  /// @param spoke The Spoke allowed to invoke this hook.
  constructor(address spoke) {
    require(spoke != address(0), InvalidSpoke());
    SPOKE = spoke;
  }

  /// @inheritdoc ISpokeHook
  function onAction(HookContext calldata context) external {
    require(msg.sender == SPOKE, UnauthorizedCaller(msg.sender));

    if (context.selector == ISpoke.supply.selector) {
      _onSupply(context.caller, context.onBehalfOf);
    } else if (context.selector == ISpoke.withdraw.selector) {
      _onWithdraw(context.caller, context.onBehalfOf);
    } else if (context.selector == ISpoke.borrow.selector) {
      _onBorrow(context.caller, context.onBehalfOf);
    } else if (context.selector == ISpoke.repay.selector) {
      _onRepay(context.caller, context.onBehalfOf);
    } else if (context.selector == ISpoke.liquidationCall.selector) {
      _onLiquidationCall(context.caller, context.onBehalfOf);
    } else if (context.selector == ISpoke.setUsingAsCollateral.selector) {
      _onSetUsingAsCollateral(context.caller, context.onBehalfOf);
    } else {
      revert UnsupportedSelector(context.selector);
    }
  }

  function _onSupply(address caller, address onBehalfOf) internal virtual {}

  function _onWithdraw(address caller, address onBehalfOf) internal virtual {}

  function _onBorrow(address caller, address onBehalfOf) internal virtual {}

  function _onRepay(address caller, address onBehalfOf) internal virtual {}

  function _onLiquidationCall(address caller, address onBehalfOf) internal virtual {}

  function _onSetUsingAsCollateral(address caller, address onBehalfOf) internal virtual {}
}
