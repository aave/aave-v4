// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ILiquidityHub
 * @author Aave Labs
 * @notice Basic interface for LiquidityHub
 */
interface ILiquidityHub {
  function draw(uint256 assetId, uint256 amount) external;
  function restore(uint256 assetId, uint256 amount) external;
}
