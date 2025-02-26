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

  error MismatchedConfigs();
  error InvalidSharesAmount(uint256 sharesAmount);
  error InvalidSupplyAmount(uint256 suppliedAmount);
  error AssetNotListed(uint256 assetId);
  error AssetNotActive(uint256 assetId);
  error SupplyCapExceeded(uint256 supplyCap);
  error InvalidWithdrawAmount(uint256 withdrawAmount);
  error SuppliedAmountExceeded(uint256 suppliedAmount);
  error NotAvailableLiquidity(uint256 availableLiquidity);
  error InvalidDrawAmount(uint256 drawAmount);
  error DrawCapExceeded(uint256 drawCap);
  error InvalidRestoreAmount(uint256 restoreAmount);
  error InvalidSpoke(address spoke);
  error InvalidBps(uint256 bps);

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
   * @param to The address to draw debt to (user).
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

  function addAsset(DataTypes.AssetConfig memory params, address asset) external;
  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) external;
  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig memory config) external;
  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory config
  ) external;

  function accrueInterest(uint256 assetId, uint32 riskPremium) external;
  function previewNextBorrowIndex(uint256 assetId) external view returns (uint256);
  function getBaseInterestRate(uint256 assetId) external view returns (uint256);

  function convertToAssets(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToShares(uint256 assetId, uint256 assets) external view returns (uint256);

  function getSpokeDebt(uint256 assetId, address spoke) external view returns (uint256, uint256);
  function getSpokeCumulativeDebt(uint256 assetId, address spoke) external view returns (uint256);
  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256);
  function getAssetCumulativeDebt(uint256 assetId) external view returns (uint256);
  function getSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256);
  function getSuppliedShares(uint256 assetId, address spoke) external view returns (uint256);
  function getAssetRiskPremium(uint256 assetId) external view returns (uint256);
  function getSpokeRiskPremium(uint256 assetId, address spoke) external view returns (uint256);
  function assetCount() external view returns (uint256);
  function assetsList(uint256 assetId) external view returns (IERC20);
  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory);
  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory);

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory);

  // todo: remove explicit rounding
  function convertToAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToAssetsDown(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToSharesUp(uint256 assetId, uint256 assets) external view returns (uint256);
  function convertToSharesDown(uint256 assetId, uint256 assets) external view returns (uint256);
}
