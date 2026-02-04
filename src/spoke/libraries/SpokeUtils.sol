// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title SpokeUtils library
/// @author Aave Labs
/// @notice Provides utility functions for the Spoke contract.
library SpokeUtils {
  /// @dev The number of decimals used by the oracle.
  uint8 public constant ORACLE_DECIMALS = 8;

  /// @dev The maximum allowed decimals for an asset (inclusive).
  uint256 public constant MAX_ALLOWED_ASSET_DECIMALS = 18;

  /// @dev The maximum allowed asset unit (10 ** MAX_ALLOWED_ASSET_DECIMALS).
  uint256 public constant MAX_ALLOWED_ASSET_UNIT = 10 ** MAX_ALLOWED_ASSET_DECIMALS;

  /// @notice Returns the reserve for a given reserve id.
  /// @param reserves The mapping of reserves per reserve id.
  /// @param reserveId The identifier of the reserve.
  /// @return The reserve.
  function get(
    mapping(uint256 reserveId => ISpoke.Reserve) storage reserves,
    uint256 reserveId
  ) internal view returns (ISpoke.Reserve storage) {
    ISpoke.Reserve storage reserve = reserves[reserveId];
    require(address(reserve.hub) != address(0), ISpoke.ReserveNotListed());
    return reserve;
  }

  /// @notice Converts an asset amount to Value.
  /// @dev Reverts if asset uses more than `MAX_ALLOWED_ASSET_DECIMALS` decimals. Reverts if multiplication overflows.
  /// @param amount The asset amount.
  /// @param decimals The decimals of the asset.
  /// @param price The price of the asset.
  /// @return The amount in units of Value.
  function toValue(
    uint256 amount,
    uint256 decimals,
    uint256 price
  ) internal pure returns (uint256) {
    return amount * price * MathUtils.uncheckedExp(10, MAX_ALLOWED_ASSET_DECIMALS - decimals);
  }
}
