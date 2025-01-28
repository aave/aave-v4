// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../libraries/types/DataTypes.sol';

/**
 * @title ILiquidityHub
 * @author Aave Labs
 * @notice Basic interface for LiquidityHub
 */
interface ILiquidityHub {
  /**
   * @notice Supply asset on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of asset to supply.
   * @param riskPremiumRad The new aggregated risk premium of the calling spoke.
   * @param supplier The address which we pull assets from (user).
   * @return The new base borrow index.
   * @return The amount of shares supplied.
   */
  function supply(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremiumRad,
    address supplier
  ) external returns (uint256, uint256);

  /**
   * @notice Withdraw supplied asset on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of asset to withdraw.
   * @param riskPremiumRad The new aggregated risk premium of the calling spoke.
   * @param to The address to transfer the assets to.
   * @return The amount of shares withdrawn.
   */
  function withdraw(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremiumRad,
    address to
  ) external returns (uint256);

  /**
   * @notice Draw debt on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of debt to draw.
   * @param riskPremiumRad The new aggregated risk premium of the calling spoke.
   * @param to The address to draw debt to (user).
   * @return The amount of debt drawn.
   */
  function draw(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremiumRad,
    address to
  ) external returns (uint256);

  /**
   * @notice Repays debt on behalf of user.
   * @dev Only callable by spokes.
   * @dev Interest is always paid off first from premium, then from base.
   * @param assetId The asset id.
   * @param amount The amount to repay.
   * @param riskPremiumRad The new aggregated risk premium of the calling spoke.
   * @param repayer The address to pull assets from.
   * @return The amount of debt restored.
   */
  function restore(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremiumRad,
    address repayer
  ) external returns (uint256);

  function getBaseInterestRate(uint256 assetId) external view returns (uint256);

  function addAsset(DataTypes.AssetConfig memory params, address asset) external;
  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) external;

  function convertToAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToAssetsDown(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToSharesUp(uint256 assetId, uint256 assets) external view returns (uint256);
  function convertToSharesDown(uint256 assetId, uint256 assets) external view returns (uint256);

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
