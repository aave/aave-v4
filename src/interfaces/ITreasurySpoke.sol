// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';

/**
 * @title ITreasurySpoke
 */
interface ITreasurySpoke {
  error InvalidHubAddress(); // todo: this is duplicated

  /**
   * @notice Supplies a specified amount of the underlying asset to a given reserve.
   * @dev The Liquidity Hub pulls the underlying asset from the caller, so prior approval is required.
   * @dev The reserve identifier matches the corresponding asset in the Liquidity Hub.
   * @param reserveId The identifier of the reserve
   * @param amount The amount of asset to supply.
   */
  function supply(uint256 reserveId, uint256 amount) external;

  /**
   * @notice Withdraws a specified amount of underlying asset from the given reserve.
   * @dev Providing an amount greater than the maximum withdrawable value signals a full withdrawal.
   * @dev The reserve identifier matches the corresponding asset in the Liquidity Hub.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to withdraw.
   * @param to The address receiving the withdrawn assets.
   */
  function withdraw(uint256 reserveId, uint256 amount, address to) external;

  /**
   * @notice Returns the amount of assets supplied.
   * @dev The reserve identifier matches the corresponding asset in the Liquidity Hub.
   * @param reserveId The identifier of the reserve.
   * @return The amount of assets supplied
   */
  function getSuppliedAmount(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the amount of assets supplied, expressed in shares.
   * @dev Shares are denominated relative to the supply side.
   * @dev The reserve identifier matches the corresponding asset in the Liquidity Hub.
   * @param reserveId The identifier of the reserve.
   * @return The amount of assets supplied, expressed in shares.
   */
  function getSuppliedShares(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the address of the associated Liquidity Hub.
   * @return The address of the Liquidity Hub.
   */
  function HUB() external view returns (ILiquidityHub);
}
