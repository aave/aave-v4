// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IPriceOracle
 * @author Aave Labs
 * @notice Basic interface for any price oracle used by the Aave protocol
 * @dev All prices must use the same number of decimals as the oracle and should be returned in the same currency
 */
interface IPriceOracle {
  /**
   * @notice Returns the number of decimals used to return prices
   * @return The number of decimals
   */
  function DECIMALS() external view returns (uint8);

  /**
   * @notice Returns the description of the oracle
   * @return The description of the oracle
   */
  function DESCRIPTION() external view returns (string memory);

  /**
   * @notice Returns the reserve price with `decimals` precision
   * @param reserveId The identifier of the reserve
   * @return The price of the reserve
   */
  function getReservePrice(uint256 reserveId) external view returns (uint256);
}
