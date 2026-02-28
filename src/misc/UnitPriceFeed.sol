// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AggregatorV2V3Interface} from 'src/dependencies/chainlink/AggregatorV2V3Interface.sol';
import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import {AggregatorInterface} from 'src/dependencies/chainlink/AggregatorInterface.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title UnitPriceFeed contract
/// @author Aave Labs
/// @notice Price feed that returns the unit price (1), with decimals precision.
/// @dev This price feed can be set for reserves that use the base currency as collateral.
contract UnitPriceFeed is AggregatorV2V3Interface {
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
    if (_roundId <= block.timestamp.toUint80()) {
      roundId = _roundId;
      answer = latestAnswer();
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
    roundId = block.timestamp.toUint80();
    answer = latestAnswer();
    startedAt = block.timestamp;
    updatedAt = block.timestamp;
    answeredInRound = roundId;
  }

  /// @inheritdoc AggregatorV3Interface
  function decimals() external view returns (uint8) {
    return DECIMALS;
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
