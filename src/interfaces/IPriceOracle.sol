// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IPriceOracle
 * @author Aave
 * @notice Defines the basic interface for a Price oracle.
 */
interface IPriceOracle {
  /**
   * @notice Returns the reserve price in the base currency
   * @param reserveId The id of the reserve
   * @return The price of the reserve
   */
  function getReservePrice(uint256 reserveId) external view returns (uint256);
}
