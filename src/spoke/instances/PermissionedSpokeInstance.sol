// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {IMandatoryPositionManager} from 'src/spoke/interfaces/IMandatoryPositionManager.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';

/// @title PermissionedSpokeInstance
/// @author Aave Labs
/// @notice Spoke implementation with a configurable mandatory position manager, which replaces the
/// default position manager authorization on position actions.
contract PermissionedSpokeInstance is SpokeInstance, IPermissionedSpoke {
  /// @dev Address of the mandatory position manager, or the zero address if unset.
  address internal _mandatoryPositionManager;

  /// @dev Constructor.
  /// @param oracle_ The address of the oracle.
  /// @param maxUserReservesLimit_ The maximum number of collateral and borrow reserves a user can have.
  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_
  ) SpokeInstance(oracle_, maxUserReservesLimit_) {}

  /// @inheritdoc IPermissionedSpoke
  function updateMandatoryPositionManager(address mandatoryPositionManager) external restricted {
    _mandatoryPositionManager = mandatoryPositionManager;
    emit UpdateMandatoryPositionManager(mandatoryPositionManager);
  }

  /// @inheritdoc IPermissionedSpoke
  function getMandatoryPositionManager() external view returns (address) {
    return _mandatoryPositionManager;
  }

  /// @dev When a mandatory position manager is set, it replaces the default authorization and fully
  /// decides whether the call is allowed, based on the caller, the position owner and the calldata.
  function _isAuthorizedPositionManagerCall(address user) internal view override returns (bool) {
    address mandatoryPositionManager = _mandatoryPositionManager;
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
