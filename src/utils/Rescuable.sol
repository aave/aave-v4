// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IRescuable} from 'src/interfaces/IRescuable.sol';

/// @title Rescuable
/// @author Aave Labs
/// @notice Contract that allows for the rescue of tokens and native assets.
abstract contract Rescuable is IRescuable {
  using SafeERC20 for IERC20;

  modifier onlyRescueGuardian() {
    _checkRescueGuardian();
    _;
  }

  /// @inheritdoc IRescuable
  function rescueToken(address token, address to, uint256 amount) external onlyRescueGuardian {
    IERC20(token).safeTransfer(to, amount);
  }

  /// @inheritdoc IRescuable
  function rescueNative(address to, uint256 amount) external onlyRescueGuardian {
    Address.sendValue(payable(to), amount);
  }

  /// @inheritdoc IRescuable
  function rescueGuardian() external view returns (address) {
    return _rescueGuardian();
  }

  function _rescueGuardian() internal view virtual returns (address);

  function _checkRescueGuardian() internal view virtual {
    require(_rescueGuardian() == msg.sender, OnlyRescueGuardian());
  }
}
