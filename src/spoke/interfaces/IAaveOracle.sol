// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';

/// @title IAaveOracle
/// @author Aave Labs
/// @notice Interface for the Aave Oracle.
interface IAaveOracle is IPriceOracle {
  /// @dev Emitted when the price feed source of a reserve is updated.
  /// @param reserveId The identifier of the reserve.
  /// @param source The price feed source of the reserve.
  event UpdateReserveSource(uint256 indexed reserveId, address indexed source);

  /// @dev Thrown when the price feed source uses a different number of decimals than the oracle.
  /// @param reserveId The identifier of the reserve.
  error InvalidSourceDecimals(uint256 reserveId);

  /// @dev Thrown when the price feed source is invalid (zero address).
  /// @param reserveId The identifier of the reserve.
  error InvalidSource(uint256 reserveId);

  /// @dev Thrown when the price feed source returns an invalid price (non-positive).
  /// @param reserveId The identifier of the reserve.
  error InvalidPrice(uint256 reserveId);

  /// @dev Thrown when the given address is invalid.
  error InvalidAddress();

  /// @notice Sets the price feed source of a reserve.
  /// @dev Must be called by the spoke.
  /// @dev The source must implement the AggregatorV3Interface.
  /// @param reserveId The identifier of the reserve.
  /// @param source The price feed source of the reserve.
  function setReserveSource(uint256 reserveId, address source) external;

  /// @notice Returns the description of the oracle.
  /// @return The description of the oracle.
  function DESCRIPTION() external view returns (string memory);

  /// @notice Returns the prices of multiple reserves.
  /// @param reserveIds The identifiers of the reserves.
  /// @return prices The prices of the reserves.
  function getReservesPrices(
    uint256[] calldata reserveIds
  ) external view returns (uint256[] memory);

  /// @notice Returns the price feed source of a reserve.
  /// @param reserveId The identifier of the reserve.
  /// @return source The price feed source of the reserve.
  function getReserveSource(uint256 reserveId) external view returns (address);
}
