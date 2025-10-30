// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {Rescuable} from 'src/utils/Rescuable.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';

/// @title GatewayBase
/// @author Aave Labs
/// @notice Base implementation for gateway common functionalities.
abstract contract GatewayBase is IGatewayBase, Rescuable, Ownable2Step {
  mapping(address => bool) internal _registeredSpokes;

  /// @notice Modifier that checks if the specified spoke is registered.
  modifier onlyRegisteredSpoke(address spoke) {
    _isSpokeValid(spoke);
    _;
  }

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) Ownable(initialOwner_) {}

  /// @inheritdoc IGatewayBase
  function registerSpoke(address spoke, bool active) external onlyOwner {
    require(spoke != address(0), InvalidAddress());
    _registeredSpokes[spoke] = active;
    emit SpokeRegistered(spoke, active);
  }

  /// @inheritdoc IGatewayBase
  function renouncePositionManagerRole(address spoke, address user) external onlyOwner {
    require(user != address(0), InvalidAddress());
    ISpoke(spoke).renouncePositionManagerRole(user);
  }

  /// @inheritdoc IGatewayBase
  function isSpokeRegistered(address spoke) external view returns (bool) {
    return _registeredSpokes[spoke];
  }

  /// @dev Verifies the specified spoke is registered.
  function _isSpokeValid(address spoke) internal view {
    require(_registeredSpokes[spoke], SpokeNotRegistered());
  }

  /// @return The underlying asset for `reserveId` on the specified spoke.
  /// @return The corresponding Hub address.
  function _getReserveData(
    address spoke,
    uint256 reserveId
  ) internal view returns (address, address) {
    ISpoke.Reserve memory reserveData = ISpoke(spoke).getReserve(reserveId);
    return (reserveData.underlying, address(reserveData.hub));
  }

  /// @dev The `owner()` is the allowed caller for Rescuable methods.
  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }
}
