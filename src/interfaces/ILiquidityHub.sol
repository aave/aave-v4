// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ILiquidityHub
 * @author Aave Labs
 * @notice Basic interface for LiquidityHub
 */
interface ILiquidityHub {
  function draw(
    uint256 assetId,
    address onBehalfOf,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256);
  function restore(uint256 assetId, uint256 amount, uint256 riskPremium) external returns (uint256);
  function supply(uint256 assetId, uint256 amount, uint256 riskPremium) external returns (uint256);
  function withdraw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256);

  function getInterestRate(uint256 assetId) external view returns (uint256);

  function convertSharesToAssets(
    uint256 assetId,
    uint256 amount,
    bool roundUp
  ) external view returns (uint256);

  function convertAssetsToShares(
    uint256 assetId,
    uint256 amount,
    bool roundUp
  ) external view returns (uint256);
}
