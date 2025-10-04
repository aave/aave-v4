// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';

/// @title UnitPriceFeed contract
/// @author Aave Labs
/// @notice Price feed that returns the unit price (1), with decimals precision.
/// @dev This price feed can be set for reserves that use the base currency as collateral.
contract UnitPriceFeed is AggregatorV3Interface {
  /// @inheritdoc AggregatorV3Interface
  uint8 public immutable override decimals;

  /// @inheritdoc AggregatorV3Interface
  string public override description;

  int256 private immutable _units;

  /// @notice Thrown when the operation is not supported.
  error OperationNotSupported();

  /// @dev Constructor.
  /// @param decimals_ The number of decimals used to represent the unit price.
  /// @param description_ The description of the unit price feed.
  constructor(uint8 decimals_, string memory description_) {
    decimals = decimals_;
    description = description_;
    _units = int256(10 ** decimals_);
  }

  /// @inheritdoc AggregatorV3Interface
  function version() external pure override returns (uint256) {
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
    roundId = _roundId;
    answer = _units;
    startedAt = _roundId;
    updatedAt = _roundId;
    answeredInRound = _roundId;
  }

  /// @inheritdoc AggregatorV3Interface
  function latestRoundData()
    external
    view
    virtual
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    roundId = uint80(block.timestamp);
    answer = _units;
    startedAt = block.timestamp;
    updatedAt = block.timestamp;
    answeredInRound = roundId;
  }
}
