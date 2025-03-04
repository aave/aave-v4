// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title ILiquidityHub
 * @author Aave Labs
 * @notice Basic interface for LiquidityHub
 */
interface ILiquidityHub {
  event SpokeAdded(uint256 indexed assetId, address indexed spoke);
  event AssetAdded(uint256 indexed assetId, address indexed asset);
  event AssetConfigUpdated(
    uint256 indexed assetId,
    uint256 decimals,
    bool active,
    address irStrategy
  );
  event SpokeConfigUpdated(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 drawCap,
    uint256 supplyCap
  );

  event Supply(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event Withdraw(
    uint256 indexed assetId,
    address indexed spoke,
    address indexed to,
    uint256 amount
  );
  event Draw(uint256 indexed assetId, address indexed spoke, address indexed to, uint256 amount);
  event Restore(uint256 indexed assetId, address indexed spoke, uint256 amount);

  error MismatchedConfigs();
  error InvalidSharesAmount();
  error InvalidSupplyAmount();
  error AssetNotListed();
  error AssetNotActive();
  error SupplyCapExceeded(uint256 supplyCap);
  error InvalidWithdrawAmount();
  error InvalidRestoreAmount();
  error SuppliedAmountExceeded(uint256 suppliedAmount);
  error NotAvailableLiquidity(uint256 availableLiquidity);
  error InvalidDrawAmount();
  error DrawCapExceeded(uint256 drawCap);
  error SurplusAmountRestored(uint256 maxAllowedRestore);
  error InvalidSpoke();
  error InvalidRiskPremiumBps(uint256 bps);

  function addAsset(DataTypes.AssetConfig memory params, address asset) external;
  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig memory config) external;
  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) external;
  function addSpokes(
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] memory configs,
    address spoke
  ) external;
  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory config
  ) external;

  /**
   * @notice Supply asset on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of asset to supply.
   * @param riskPremium The new aggregated risk premium (in bps) of the calling spoke.
   * @param supplier The address which we pull assets from (user).
   * @return The amount of shares supplied.
   */
  function supply(
    uint256 assetId,
    uint256 amount,
    uint32 riskPremium,
    address supplier
  ) external returns (uint256);

  /**
   * @notice Withdraw supplied asset on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of asset to withdraw.
   * @param riskPremium The new aggregated risk premium (in bps) of the calling spoke.
   * @param to The address to transfer the assets to.
   * @return The amount of shares withdrawn.
   */
  function withdraw(
    uint256 assetId,
    uint256 amount,
    uint32 riskPremium,
    address to
  ) external returns (uint256);

  /**
   * @notice Draw debt on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of debt to draw.
   * @param riskPremium The new aggregated risk premium (in bps) of the calling spoke.
   * @param to The address to transfer the underlying assets to.
   * @return The amount of debt drawn.
   */
  function draw(
    uint256 assetId,
    uint256 amount,
    uint32 riskPremium,
    address to
  ) external returns (uint256);

  /**
   * @notice Repays debt on behalf of user.
   * @dev Only callable by spokes.
   * @dev Interest is always paid off first from premium, then from base.
   * @param assetId The asset id.
   * @param amount The amount to repay.
   * @param riskPremium The new aggregated risk premium (in bps) of the calling spoke.
   * @param repayer The address to pull assets from.
   * @return The amount of debt restored.
   */
  function restore(
    uint256 assetId,
    uint256 amount,
    uint32 riskPremium,
    address repayer
  ) external returns (uint256);
  function accrueInterest(uint256 assetId, uint32 riskPremium) external;

  function previewNextBorrowIndex(uint256 assetId) external view returns (uint256);
  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory);
  function getSpoke(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeData memory);
  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory);
  function getTotalAssets(uint256 assetId) external view returns (uint256);
  function convertToAssets(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToShares(uint256 assetId, uint256 assets) external view returns (uint256);
  function getBaseInterestRate(uint256 assetId) external view returns (uint256);
  function getInterestRate(uint256 assetId) external view returns (uint256);

  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256);
  function getAssetCumulativeDebt(uint256 assetId) external view returns (uint256);
  function getSpokeDebt(uint256 assetId, address spoke) external view returns (uint256, uint256);
  function getSpokeCumulativeDebt(uint256 assetId, address spoke) external view returns (uint256);
  function getAssetSuppliedAmount(uint256 assetId) external view returns (uint256);
  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256);
  function getSpokeSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256);
  function getSpokeSuppliedShares(uint256 assetId, address spoke) external view returns (uint256);
  function getAssetRiskPremium(uint256 assetId) external view returns (uint256);
  function getSpokeRiskPremium(uint256 assetId, address spoke) external view returns (uint256);
  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory);

  function assetCount() external view returns (uint256);
  function assetsList(uint256 assetId) external view returns (IERC20);

  // todo: remove explicit rounding
  function convertToAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToAssetsDown(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToSharesUp(uint256 assetId, uint256 assets) external view returns (uint256);
  function convertToSharesDown(uint256 assetId, uint256 assets) external view returns (uint256);
}
