// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Spoke} from 'src/spoke/Spoke.sol';
import {ISpokeHook} from 'src/spoke/interfaces/ISpokeHook.sol';

/// @title SpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the Spoke.
contract SpokeInstance is Spoke {
  uint64 public constant SPOKE_REVISION = 1;

  /// @notice The hook invoked before permissionless Spoke actions.
  ISpokeHook internal immutable HOOK;

  /// @dev Constructor.
  /// @dev During upgrade, must ensure that the new oracle is supporting existing assets on the Spoke and the replaced oracle.
  /// @param oracle_ The address of the oracle.
  /// @param maxUserReservesLimit_ The maximum number of collateral and borrow reserves a user can have.
  /// @param hook_ The hook invoked before permissionless Spoke actions.
  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_,
    address hook_
  ) Spoke(oracle_, maxUserReservesLimit_) {
    require(hook_.code.length > 0, InvalidAddress());
    HOOK = ISpokeHook(hook_);
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority The address of the authority contract which manages permissions.
  function initialize(address authority) external override reinitializer(SPOKE_REVISION) {
    emit SetSpokeImmutables(ORACLE, MAX_USER_RESERVES_LIMIT);

    require(authority != address(0), InvalidAddress());
    __AccessManaged_init(authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }
  }

  function _executeHook(address onBehalfOf) internal override {
    HOOK.onAction(
      ISpokeHook.HookContext({caller: msg.sender, onBehalfOf: onBehalfOf, selector: msg.sig})
    );
  }
}
