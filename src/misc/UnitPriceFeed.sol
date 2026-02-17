// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title UnitPriceFeed contract
/// @author Aave Labs
/// @notice Price feed that returns the unit price (1), with decimals precision.
/// @dev This price feed can be set for reserves that use the base currency as collateral.
contract UnitPriceFeed is AggregatorV3Interface {
  using SafeCast for uint256;

  /// @inheritdoc AggregatorV3Interface
  string public description;

  uint8 private immutable DECIMALS;
  int256 private immutable UNITS;

  /// @dev Constructor.
  /// @param decimals_ The number of decimals used to represent the unit price.
  /// @param description_ The description of the unit price feed.
  constructor(uint8 decimals_, string memory description_) {
    UNITS = (10 ** decimals_).toInt256();
    DECIMALS = decimals_;
    description = description_;
  }

  /// @inheritdoc AggregatorV3Interface
  function version() external pure returns (uint256) {
    return 1;
  }

  /// @inheritdoc AggregatorV3Interface
  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    if (_roundId <= uint80(block.timestamp)) {
      roundId = _roundId;
      answer = UNITS;
      startedAt = _roundId;
      updatedAt = _roundId;
      answeredInRound = _roundId;
    }
  }

  /// @inheritdoc AggregatorV3Interface
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    roundId = uint80(block.timestamp);
    answer = UNITS;
    startedAt = block.timestamp;
    updatedAt = block.timestamp;
    answeredInRound = roundId;
  }

  /// @inheritdoc AggregatorV3Interface
  function decimals() external view returns (uint8) {
    return DECIMALS;
  }
}
