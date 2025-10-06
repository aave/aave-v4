// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import {IAaveOracle, IPriceOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

/// @title AaveOracle
/// @author Aave Labs
/// @notice Provides reserve prices.
/// @dev Oracles are spoke-specific, due to the usage of reserve id as index of the `_sources` mapping.
contract AaveOracle is IAaveOracle {
  /// @inheritdoc IPriceOracle
  address public immutable override SPOKE;

  /// @inheritdoc IPriceOracle
  uint8 public immutable override DECIMALS;

  /// @inheritdoc IAaveOracle
  string public override DESCRIPTION;

  mapping(uint256 reserveId => AggregatorV3Interface) internal _sources;

  /// @dev Constructor.
  /// @dev `decimals` must match the spoke's decimals for compatibility.
  /// @param spoke_ The address of the spoke contract.
  /// @param decimals_ The number of decimals for the oracle.
  /// @param description_ The description of the oracle.
  constructor(address spoke_, uint8 decimals_, string memory description_) {
    require(spoke_ != address(0), InvalidAddress());
    SPOKE = spoke_;
    DECIMALS = decimals_;
    DESCRIPTION = description_;
  }

  /// @inheritdoc IAaveOracle
  function setReserveSource(uint256 reserveId, address source) external override {
    require(msg.sender == SPOKE, OnlySpoke());
    AggregatorV3Interface targetSource = AggregatorV3Interface(source);
    require(targetSource.decimals() == DECIMALS, InvalidSourceDecimals(reserveId));
    _sources[reserveId] = targetSource;
    _getSourcePrice(reserveId); // check if the source is valid
    emit UpdateReserveSource(reserveId, source);
  }

  /// @inheritdoc IPriceOracle
  function getReservePrice(uint256 reserveId) external view override returns (uint256) {
    return _getSourcePrice(reserveId);
  }

  /// @inheritdoc IAaveOracle
  function getReservesPrices(
    uint256[] calldata reserveIds
  ) external view override returns (uint256[] memory) {
    uint256[] memory prices = new uint256[](reserveIds.length);
    for (uint256 i = 0; i < reserveIds.length; ++i) {
      prices[i] = _getSourcePrice(reserveIds[i]);
    }
    return prices;
  }

  /// @inheritdoc IAaveOracle
  function getReserveSource(uint256 reserveId) external view override returns (address) {
    return address(_sources[reserveId]);
  }

  /// @dev Price of zero will revert with `InvalidPrice`.
  function _getSourcePrice(uint256 reserveId) internal view returns (uint256) {
    AggregatorV3Interface source = _sources[reserveId];
    require(address(source) != address(0), InvalidSource(reserveId));

    (, int256 price, , , ) = source.latestRoundData();
    require(price > 0, InvalidPrice(reserveId));

    return uint256(price);
  }
}
