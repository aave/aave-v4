// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

interface IRescuable {
  error OnlyRescueGuardian();

  /**
   * @notice Recovers ERC20 tokens sent to this contract.
   * @param token Address of the ERC20 token to rescue.
   * @param to Address to send the rescued tokens to.
   * @param amount Amount of tokens to rescue.
   **/
  function rescueToken(address token, address to, uint256 amount) external;

  /**
   * @notice Recovers native asset left in this contract.
   * @param to Address to send the rescued native asset to.
   * @param amount Amount of native asset to rescue.
   **/
  function rescueNative(address to, uint256 amount) external;

  /**
   * @notice Returns the address that is allowed to rescue funds.
   **/
  function rescueGuardian() external view returns (address);
}
