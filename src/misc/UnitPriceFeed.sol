// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AggregatorInterface} from 'src/dependencies/chainlink/AggregatorInterface.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title UnitPriceFeed contract
/// @author Aave Labs
/// @notice Price feed that returns the unit price (1), with decimals precision.
/// @dev This price feed can be set for reserves that use the base currency as collateral.
contract UnitPriceFeed is AggregatorInterface {
  using SafeCast for uint256;

  int256 private immutable UNITS;

  /// @dev Constructor.
  /// @param decimals_ The number of decimals used to represent the unit price.
  constructor(uint8 decimals_) {
    UNITS = (10 ** decimals_).toInt256();
  }

  /// @inheritdoc AggregatorInterface
  function latestAnswer() public view returns (int256) {
    return UNITS;
  }

  /// @inheritdoc AggregatorInterface
  function latestTimestamp() external view returns (uint256) {
    return block.timestamp;
  }

  /// @inheritdoc AggregatorInterface
  function latestRound() external view returns (uint256) {
    return block.timestamp;
  }

  /// @inheritdoc AggregatorInterface
  function getAnswer(uint256 roundId) external view returns (int256) {
    if (roundId <= block.timestamp) {
      return latestAnswer();
    }
    return 0;
  }

  /// @inheritdoc AggregatorInterface
  function getTimestamp(uint256 roundId) external view returns (uint256) {
    if (roundId <= block.timestamp) {
      return roundId;
    }
    return 0;
  }
}
