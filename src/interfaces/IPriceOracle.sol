// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IPriceOracle
 * @author Aave
 * @notice Defines the basic interface for a Price oracle.
 */
interface IPriceOracle {
  /**
   * @notice Returns the asset price in the base currency
   * @param assetId The id of the asset
   * @return The price of the asset
   */
  function getAssetPrice(uint256 assetId) external view returns (uint256);
}
