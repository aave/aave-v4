// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Spoke} from 'src/spoke/Spoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPolicyGate} from 'src/spoke/interfaces/IPolicyGate.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';
import {AuthKind} from 'src/spoke/libraries/AuthKind.sol';

/// @title PermissionedSpoke
/// @author Aave Labs
/// @notice Spoke where a policy gate decides who is eligible to use it.
/// @dev Position actions keep the canonical authorization (owner or approved position manager). The
/// policy gate is asked after it and can only restrict. Reserve managers can additionally perform the
/// actions the policy gate grants them on the reserve in the call (supply, withdraw, repay, set
/// collateral), never borrow.
/// Every liquidation is checked by the policy gate.
abstract contract PermissionedSpoke is IPermissionedSpoke, Spoke {
  /// @inheritdoc IPermissionedSpoke
  address public immutable POLICY_GATE;

  /// @dev Authorizes the caller, then asks the policy gate.
  modifier onlyPositionManager(address onBehalfOf) override {
    _validatePositionAction(onBehalfOf);
    _;
  }

  /// @dev Constructor.
  /// @param oracle_ The address of the oracle.
  /// @param maxUserReservesLimit_ The maximum number of collateral and borrow reserves a user can have.
  /// @param policyGate_ The address of the policy gate.
  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_,
    address policyGate_
  ) Spoke(oracle_, maxUserReservesLimit_) {
    require(policyGate_ != address(0), InvalidAddress());
    POLICY_GATE = policyGate_;
  }

  /// @dev Reverts with `Unauthorized` if the caller is neither the owner, an approved position manager
  /// nor a reserve manager of the reserve in the call, or if the policy gate rejects the call.
  function _validatePositionAction(address onBehalfOf) internal view {
    uint8 auth;
    if (_isPositionManager({user: onBehalfOf, manager: msg.sender})) {
      auth = msg.sender == onBehalfOf ? AuthKind.OWNER : AuthKind.POSITION_MANAGER;
    } else {
      uint8 action = _reserveManagerAction(msg.data);
      require(
        action != 0 &&
          IPolicyGate(POLICY_GATE).getReserveManagerActions(
            msg.sender,
            uint256(bytes32(msg.data[4:36]))
          ) &
            action !=
            0,
        Unauthorized()
      );
      auth = AuthKind.RESERVE_MANAGER;
    }
    require(
      IPolicyGate(POLICY_GATE).isEligible(msg.sender, onBehalfOf, msg.data, auth),
      Unauthorized()
    );
  }

  /// @dev Asks the policy gate whether the liquidator is allowed.
  function _validateLiquidator() internal view override {
    require(
      IPolicyGate(POLICY_GATE).isEligible(msg.sender, msg.sender, msg.data, AuthKind.OWNER),
      Unauthorized()
    );
  }

  /// @dev Returns the reserve manager action bit of `data`, zero for calls a reserve manager can
  /// never perform, such as borrow. All actions take the reserve identifier as first argument.
  function _reserveManagerAction(bytes calldata data) internal pure returns (uint8) {
    bytes4 selector = bytes4(data[0:4]);
    if (selector == ISpoke.supply.selector) return AuthKind.ACTION_SUPPLY;
    if (selector == ISpoke.withdraw.selector) return AuthKind.ACTION_WITHDRAW;
    if (selector == ISpoke.repay.selector) return AuthKind.ACTION_REPAY;
    if (selector == ISpoke.setUsingAsCollateral.selector) return AuthKind.ACTION_SET_COLLATERAL;
    return 0;
  }
}
