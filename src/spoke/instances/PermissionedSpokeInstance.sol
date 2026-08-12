// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeInstanceBase} from 'src/spoke/instances/SpokeInstanceBase.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';

/// @title PermissionedSpokeInstance
/// @author Aave Labs
/// @notice Spoke implementation with a configurable gate, which replaces the default position
/// manager authorization on position actions.
contract PermissionedSpokeInstance is SpokeInstanceBase, IPermissionedSpoke {
  /// @custom:storage-location erc7201:aave.storage.PermissionedSpoke
  struct PermissionedSpokeStorage {
    address gate;
  }

  // keccak256(abi.encode(uint256(keccak256('aave.storage.PermissionedSpoke')) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant PermissionedSpokeStorageLocation =
    0xad19adda25bc112a506d1eb6b62266ed84c7e8969fba16c536d63fc20c4fda00;

  function _permissionedSpokeStorage() private pure returns (PermissionedSpokeStorage storage $) {
    assembly {
      $.slot := PermissionedSpokeStorageLocation
    }
  }

  /// @dev Constructor.
  /// @param oracle_ The address of the oracle.
  /// @param maxUserReservesLimit_ The maximum number of collateral and borrow reserves a user can have.
  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_
  ) SpokeInstanceBase(oracle_, maxUserReservesLimit_) {}

  /// @inheritdoc IPermissionedSpoke
  function updateGate(address gate) external restricted {
    _permissionedSpokeStorage().gate = gate;
    emit UpdateGate(gate);
  }

  /// @inheritdoc IPermissionedSpoke
  function getGate() external view returns (address) {
    return _permissionedSpokeStorage().gate;
  }

  /// @dev When a gate is set, it replaces the default authorization and fully decides whether the
  /// call is allowed, based on the caller, the position owner and the calldata.
  function _isAuthorizedPositionManagerCall(
    address caller,
    address user,
    bytes calldata data
  ) internal view override returns (bool) {
    address gate = _permissionedSpokeStorage().gate;
    if (gate == address(0)) {
      return super._isAuthorizedPositionManagerCall(caller, user, data);
    }
    return ISpokeGate(gate).isCallAllowed({caller: caller, onBehalfOf: user, data: data});
  }
}
