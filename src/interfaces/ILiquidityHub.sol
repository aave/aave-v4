// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../libraries/types/DataTypes.sol';

/**
 * @title ILiquidityHub
 * @author Aave Labs
 * @notice Basic interface for LiquidityHub
 */
interface ILiquidityHub {
  function draw(
    uint256 assetId,
    address to,
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

  function getBaseInterestRate(uint256 assetId) external view returns (uint256);

  function addAsset(DataTypes.AssetConfig memory params, address asset) external;
  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) external;

  function convertSharesToAssetsUp(uint256 assetId, uint256 amount) external view returns (uint256);
  function convertSharesToAssetsDown(
    uint256 assetId,
    uint256 amount
  ) external view returns (uint256);
  function convertAssetsToSharesUp(uint256 assetId, uint256 amount) external view returns (uint256);
  function convertAssetsToSharesDown(
    uint256 assetId,
    uint256 amount
  ) external view returns (uint256);

  event Supply(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event Withdraw(
    uint256 indexed assetId,
    address indexed spoke,
    address indexed to,
    uint256 amount
  );
  event Draw(uint256 indexed assetId, address indexed spoke, address indexed to, uint256 amount);
  event Restore(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event SpokeAdded(uint256 indexed assetId, address indexed spoke);
}
