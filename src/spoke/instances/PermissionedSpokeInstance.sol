// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeInstanceBase} from 'src/spoke/instances/SpokeInstanceBase.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';
import {IPermissionedSpoke} from 'src/spoke/interfaces/IPermissionedSpoke.sol';

/// @title PermissionedSpokeInstance
/// @author Aave Labs
/// @notice Spoke implementation where a gate, settable by governance, replaces the default
/// position manager authorization on position actions.
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

  /// @dev Disabled in favor of `initialize(address,address)`.
  function initialize(address) external pure override {
    revert InvalidInitialization();
  }

  /// @notice Initializer.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority The address of the authority contract which manages permissions.
  /// @param gate The address of the gate.
  function initialize(address authority, address gate) external reinitializer(SPOKE_REVISION) {
    emit SetSpokeImmutables(ORACLE, MAX_USER_RESERVES_LIMIT);

    require(authority != address(0), InvalidAddress());
    __AccessManaged_init(authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }

    _updateGate(gate);
  }

  /// @inheritdoc IPermissionedSpoke
  function updateGate(address gate) external restricted {
    _updateGate(gate);
  }

  /// @inheritdoc IPermissionedSpoke
  function getGate() external view returns (address) {
    return _permissionedSpokeStorage().gate;
  }

  function _updateGate(address gate) internal {
    require(gate != address(0), InvalidAddress());
    _permissionedSpokeStorage().gate = gate;
    emit UpdateGate(gate);
  }

  /// @dev The gate fully decides whether the call is allowed, based on the caller, the position
  /// owner and the calldata. It can preserve the default authorization by calling back
  /// `isPositionManager`.
  function _isAuthorizedPositionManagerCall(
    address caller,
    address user,
    bytes calldata data
  ) internal view override returns (bool) {
    return
      ISpokeGate(_permissionedSpokeStorage().gate).isCallAllowed({
        caller: caller,
        onBehalfOf: user,
        data: data
      });
  }
}
