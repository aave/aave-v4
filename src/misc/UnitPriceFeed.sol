// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {IPriceFeed} from 'src/spoke/interfaces/IPriceFeed.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title UnitPriceFeed contract
/// @author Aave Labs
/// @notice Price feed that returns the unit price (1), with decimals precision.
/// @dev This price feed can be set for reserves that use the base currency as collateral.
contract UnitPriceFeed is IPriceFeed {
  using SafeCast for uint256;

  /// @inheritdoc IPriceFeed
  uint8 public immutable decimals;

  int256 private immutable UNITS;

  /// @dev Constructor.
  /// @param decimals_ The number of decimals used to represent the unit price.
  constructor(uint8 decimals_) {
    UNITS = (10 ** decimals_).toInt256();
    decimals = decimals_;
  }

  /// @inheritdoc IPriceFeed
  function latestAnswer() public view returns (int256) {
    return UNITS;
  }
}
