// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IPriceFeed} from 'src/spoke/interfaces/IPriceFeed.sol';

/// @title UnitPriceFeed contract
/// @author Aave Labs
/// @notice Price feed that returns the unit price (1), with decimals precision.
/// @dev This price feed can be set for reserves that use the base currency as collateral.
contract UnitPriceFeed is IPriceFeed {
  using SafeCast for uint256;

  /// @inheritdoc IPriceFeed
  uint8 public immutable decimals;

  /// @notice The number of units used to represent the price.
  int256 public immutable units;

  /// @inheritdoc IPriceFeed
  string public description;

  /// @dev Constructor.
  /// @param decimals_ The number of decimals used to represent the unit price.
  /// @param description_ The description of the unit price feed.
  constructor(uint8 decimals_, string memory description_) {
    units = (10 ** decimals_).toInt256();
    decimals = decimals_;
    description = description_;
  }

  /// @inheritdoc IPriceFeed
  function latestAnswer() public view returns (int256) {
    return units;
  }
}
