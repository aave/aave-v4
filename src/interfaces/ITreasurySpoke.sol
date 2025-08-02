// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHub} from 'src/interfaces/IHub.sol';
import {ISpokeBase} from 'src/interfaces/ISpokeBase.sol';

/**
 * @title ITreasurySpoke
 */
interface ITreasurySpoke is ISpokeBase {
  /**
   * @notice Supplies a specified amount of the underlying asset to a given reserve.
   * @dev The Hub pulls the underlying asset from the caller, so prior approval is required.
   * @dev The reserve identifier **should match** corresponding asset identifier in the Hub.
   * @param reserveId The identifier of the reserve
   * @param amount The amount of asset to supply.
   * @param onBehalfOf Unused parameter for this spoke.
   */
  function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Withdraws a specified amount of underlying asset from the given reserve.
   * @dev Providing an amount greater than the maximum withdrawable value signals a full withdrawal.
   * @dev The reserve identifier **should match** corresponding asset identifier in the Hub.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to withdraw.
   * @param onBehalfOf Unused parameter for this spoke.
   */
  function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Transfers a specified amount of ERC20 tokens from this contract.
   * @param token The address of the ERC20 token to transfer.
   * @param to The recipient address.
   * @param amount The amount of tokens to transfer.
   */
  function transfer(address token, address to, uint256 amount) external;

  /**
   * @notice Returns the amount of assets supplied.
   * @dev The reserve identifier **should match** corresponding asset identifier in the Hub.
   * @param reserveId The identifier of the reserve.
   * @return The amount of assets supplied
   */
  function getSuppliedAmount(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the amount of assets supplied, expressed in shares.
   * @dev Shares are denominated relative to the supply side.
   * @dev The reserve identifier **should match** corresponding asset identifier in the Hub.
   * @param reserveId The identifier of the reserve.
   * @return The amount of assets supplied, expressed in shares.
   */
  function getSuppliedShares(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the address of the associated Hub.
   * @return The address of the Hub.
   */
  function HUB() external view returns (IHub);
}
