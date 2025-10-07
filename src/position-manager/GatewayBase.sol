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
    _validateSpoke(spoke);
    require(user != address(0), InvalidAddress());
    ISpoke(spoke).renouncePositionManagerRole(user);
  }

  /// @inheritdoc IGatewayBase
  function isSpokeRegistered(address spoke) external view returns (bool) {
    return _registeredSpokes[spoke];
  }

  function _validateSpoke(address spoke) internal view {
    require(spoke != address(0), InvalidAddress());
    require(_registeredSpokes[spoke], SpokeNotRegistered());
  }

  /// @dev RescueGuardian is the owner of the contract.
  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }
}
