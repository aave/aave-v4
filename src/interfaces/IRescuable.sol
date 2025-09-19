// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/**
 * @title IRescuable
 * @author Aave Labs
 * @notice Interface for the Rescuable contract.
 */
interface IRescuable {
  /**
   * @notice Thrown when the caller is not the rescue guardian.
   */
  error OnlyRescueGuardian();

  /**
   * @notice Recovers ERC20 tokens sent to this contract.
   * @param token Address of the ERC20 token to rescue.
   * @param to Address to send the rescued tokens to.
   **/
  function rescueToken(address token, address to) external;

  /**
   * @notice Recovers native asset remaining in this contract.
   * @param to Recipient of rescued native asset.
   * @param amount Amount of native asset to rescue.
   **/
  function rescueNative(address to, uint256 amount) external;

  /**
   * @notice Returns the rescue guardian address.
   * @return The address allowed to rescue funds.
   **/
  function rescueGuardian() external view returns (address);
}
