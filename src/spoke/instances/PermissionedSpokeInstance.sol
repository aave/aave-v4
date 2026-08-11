// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeInstanceBase} from 'src/spoke/instances/SpokeInstanceBase.sol';
import {IMandatoryPositionManager} from 'src/spoke/interfaces/IMandatoryPositionManager.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';

/// @title PermissionedSpokeInstance
/// @author Aave Labs
/// @notice Spoke implementation with a configurable mandatory position manager, which replaces the
/// default position manager authorization on position actions.
contract PermissionedSpokeInstance is SpokeInstanceBase, IPermissionedSpoke {
  /// @custom:storage-location erc7201:aave.storage.PermissionedSpoke
  struct PermissionedSpokeStorage {
    address mandatoryPositionManager;
  }

  // keccak256(abi.encode(uint256(keccak256('aave.storage.PermissionedSpoke')) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant PermissionedSpokeStorageLocation =
    0xad19adda25bc112a506d1eb6b62266ed84c7e8969fba16c536d63fc20c4fda00;

  function _getPermissionedSpokeStorage()
    private
    pure
    returns (PermissionedSpokeStorage storage $)
  {
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
  function updateMandatoryPositionManager(address mandatoryPositionManager) external restricted {
    _getPermissionedSpokeStorage().mandatoryPositionManager = mandatoryPositionManager;
    emit UpdateMandatoryPositionManager(mandatoryPositionManager);
  }

  /// @inheritdoc IPermissionedSpoke
  function getMandatoryPositionManager() external view returns (address) {
    return _getPermissionedSpokeStorage().mandatoryPositionManager;
  }

  /// @dev When a mandatory position manager is set, it replaces the default authorization and fully
  /// decides whether the call is allowed, based on the caller, the position owner and the calldata.
  function _isAuthorizedPositionManagerCall(address user) internal view override returns (bool) {
    address mandatoryPositionManager = _getPermissionedSpokeStorage().mandatoryPositionManager;
    if (mandatoryPositionManager == address(0)) {
      return super._isAuthorizedPositionManagerCall(user);
    }
    return
      IMandatoryPositionManager(mandatoryPositionManager).isCallAllowed({
        caller: msg.sender,
        onBehalfOf: user,
        data: msg.data
      });
  }
}
