// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IHubBase} from 'src/interfaces/IHubBase.sol';

/**
 * @title IHub
 * @author Aave Labs
 * @notice Full interface for Hub
 */
interface IHub is IHubBase, IAccessManaged {
  event AddSpoke(uint256 indexed assetId, address indexed spoke);
  event AddAsset(uint256 indexed assetId, address indexed underlying, uint8 decimals);
  event AssetConfigUpdate(uint256 indexed assetId, DataTypes.AssetConfig config);
  event SpokeConfigUpdate(
    uint256 indexed assetId,
    address indexed spoke,
    DataTypes.SpokeConfig config
  );
  event AssetUpdate(
    uint256 indexed assetId,
    uint256 drawnIndex,
    uint256 drawnRate,
    uint256 latestUpdateTimestamp
  );
  event RefreshPremium(
    uint256 indexed assetId,
    address indexed spoke,
    DataTypes.PremiumDelta premiumDelta
  );
  event ReportDeficit(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 drawnShares,
    DataTypes.PremiumDelta premiumDelta,
    uint256 drawnAmount
  );
  event AccrueFees(uint256 indexed assetId, uint256 shares);
  event TransferShares(uint256 indexed assetId, uint256 shares, address sender, address receiver);

  /**
   * @notice Emitted when an amount of liquidity is swept/reinvested.
   * @param assetId The identifier of the asset.
   * @param amount The amount swept.
   */
  event Sweep(uint256 indexed assetId, uint256 amount);

  /**
   * @notice Emitted when an amount of liquidity is reclaimed (from swept/reinvested liquidity).
   * @param assetId The identifier of the asset.
   * @param amount The amount reclaimed.
   */
  event Reclaim(uint256 indexed assetId, uint256 amount);

  /**
   * @notice Emitted when deficit is eliminated.
   * @param assetId The identifier of the asset.
   * @param spoke The spoke that eliminated the deficit, and had supplied shares removed.
   * @param shares The amount of shares removed.
   * @param amount The amount of deficit eliminated.
   */
  event EliminateDeficit(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 shares,
    uint256 amount
  );

  error AssetNotListed();
  error AddCapExceeded(uint256 addCap);
  error AddedAmountExceeded(uint256 addedAmount);
  error AddedSharesExceeded(uint256 addedShares);
  error InsufficientLiquidity(uint256 liquidity);
  error DrawCapExceeded(uint256 drawCap);
  error SurplusAmountRestored(uint256 maxAllowedRestore);
  error InvalidPremiumChange();
  error SurplusDeficitReported(uint256 amount);
  error SpokeNotActive();
  error InvalidReinvestmentController();
  error OnlyReinvestmentController();
  error SpokeAlreadyListed();
  error SpokeNotListed();
  error InvalidAmount();
  error InvalidShares();
  error InvalidAddress();
  error InvalidLiquidityFee();
  error InvalidAssetDecimals();

  /**
   * @notice Adds a new asset to the hub.
   * @dev The same underlying asset address can be added as an asset multiple times.
   * @dev The fee receiver is added as a new spoke with maximum add cap and zero draw cap.
   * @param underlying The address of the underlying asset.
   * @param decimals The number of decimals of the asset.
   * @param feeReceiver The address of the fee receiver spoke.
   * @param irStrategy The address of the interest rate strategy contract.
   * @param data The interest rate data to apply to the given asset, all in bps, encoded in bytes.
   * @return The unique identifier of the added asset.
   */
  function addAsset(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata data
  ) external returns (uint256);

  /**
   * @notice Updates the configuration of an asset.
   * @dev If the fee receiver is updated, it is added as a new spoke with maximum add cap and zero draw cap.
   * @param assetId The identifier of the asset.
   * @param config The new configuration for the asset.
   */
  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig calldata config) external;

  /**
   * @notice Registers a new spoke for a specific asset in the hub.
   * @dev Reverts if spoke is already listed with SpokeAlreadyListed.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke to add.
   * @param params The configuration parameters for the spoke.
   */
  function addSpoke(uint256 assetId, address spoke, DataTypes.SpokeConfig calldata params) external;

  /**
   * @notice Updates the configuration of a spoke for a specific asset.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke to update.
   * @param config The new configuration for the spoke.
   */
  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external;

  /**
   * @notice Updates the interest rate strategy for a specified asset.
   * @param assetId The identifier of the asset.
   * @param data The interest rate data to apply to the given asset, all in bps, encoded in bytes.
   */
  function setInterestRateData(uint256 assetId, bytes calldata data) external;

  /**
   * @notice Refreshes premium accounting.
   * @dev Only callable by active spokes, reverts with `SpokeNotActive` otherwise.
   * @dev Overall premium should not decrease, reverts with `InvalidPremiumChange` otherwise.
   * @param assetId The identifier of the asset.
   * @param premiumDelta The change in premium.
   */
  function refreshPremium(uint256 assetId, DataTypes.PremiumDelta calldata premiumDelta) external;

  /**
   * @notice Pay existing liquidity to feeReceiver.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param shares The amount of shares to pay to feeReceiver.
   */
  function payFee(uint256 assetId, uint256 shares) external;

  /**
   * @notice Reports deficit.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param drawnAmount The drawn amount to report as deficit.
   * @param premiumAmount The premium amount to report as deficit.
   * @param premiumDelta The premium delta to apply which signal premium deficit.
   * @return The amount of drawn shares reported as deficit.
   */
  function reportDeficit(
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount,
    DataTypes.PremiumDelta calldata premiumDelta
  ) external returns (uint256);

  /**
   * @notice Allows a spoke to transfer its supplied shares of an asset to another spoke.
   * @dev Only callable by spokes.
   * @param assetId The identifier of the asset.
   * @param shares The amount of shares to move.
   * @param toSpoke The address of the spoke to move shares to.
   */
  function transferShares(uint256 assetId, uint256 shares, address toSpoke) external;

  /**
   * @notice Eliminates deficit by removing supplied shares of caller spoke.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of deficit to eliminate.
   * @return The amount of shares removed.
   */
  function eliminateDeficit(uint256 assetId, uint256 amount) external returns (uint256);

  /**
   * @notice Sweeps an amount of liquidity of the corresponding asset and sends it to the configured reinvestment controller.
   * @dev The controller handles the actual reinvestment of funds, redistribution of interest, and investment caps.
   * @param assetId The identifier of the asset.
   * @param amount The amount to sweep.
   */
  function sweep(uint256 assetId, uint256 amount) external;

  /**
   * @notice Reclaims an amount of liquidity of the corresponding asset from the configured reinvestment controller.
   * @dev The controller can only reclaim up to swept amount. All accrued interest is distributed offchain.
   * @param assetId The identifier of the asset.
   * @param amount The amount to reclaim.
   */
  function reclaim(uint256 assetId, uint256 amount) external;

  /**
   * @notice Converts the specified amount of assets to shares amount added upon an Add action.
   * @dev Rounds down to the nearest shares amount.
   * @param assetId The identifier of the asset.
   * @param assets The amount of assets to convert to shares amount.
   * @return The amount of shares converted from assets amount.
   */
  function previewAddByAssets(uint256 assetId, uint256 assets) external view returns (uint256);

  /**
   * @notice Converts the specified shares amount to assets amount added upon an Add action.
   * @dev Rounds up to the nearest assets amount.
   * @param assetId The identifier of the asset.
   * @param shares The amount of shares to convert to assets amount.
   * @return The amount of assets converted from shares amount.
   */
  function previewAddByShares(uint256 assetId, uint256 shares) external view returns (uint256);

  /**
   * @notice Converts the specified amount of assets to shares amount removed upon a Remove action.
   * @dev Rounds up to the nearest shares amount.
   * @param assetId The identifier of the asset.
   * @param assets The amount of assets to convert to shares amount.
   * @return The amount of shares converted from assets amount.
   */
  function previewRemoveByAssets(uint256 assetId, uint256 assets) external view returns (uint256);

  /**
   * @notice Converts the specified amount of shares to assets amount removed upon a Remove action.
   * @dev Rounds down to the nearest assets amount.
   * @param assetId The identifier of the asset.
   * @param shares The amount of shares to convert to assets amount.
   * @return The amount of assets converted from shares amount.
   */
  function previewRemoveByShares(uint256 assetId, uint256 shares) external view returns (uint256);

  /**
   * @notice Converts the specified amount of assets to shares amount drawn upon a Draw action.
   * @dev Rounds up to the nearest shares amount.
   * @param assetId The identifier of the asset.
   * @param assets The amount of assets to convert to shares amount.
   * @return The amount of shares converted from assets amount.
   */
  function previewDrawByAssets(uint256 assetId, uint256 assets) external view returns (uint256);

  /**
   * @notice Converts the specified amount of shares to assets amount drawn upon a Draw action.
   * @dev Rounds down to the nearest assets amount.
   * @param assetId The identifier of the asset.
   * @param shares The amount of shares to convert to assets amount.
   * @return The amount of assets converted from shares amount.
   */
  function previewDrawByShares(uint256 assetId, uint256 shares) external view returns (uint256);

  /**
   * @notice Converts the specified amount of assets to shares amount restored upon a Restore action.
   * @dev Rounds down to the nearest shares amount.
   * @param assetId The identifier of the asset.
   * @param assets The amount of assets to convert to shares amount.
   * @return The amount of shares converted from assets amount.
   */
  function previewRestoreByAssets(uint256 assetId, uint256 assets) external view returns (uint256);

  /**
   * @notice Converts the specified amount of shares to assets amount restored upon a Restore action.
   * @dev Rounds up to the nearest assets amount.
   * @param assetId The identifier of the asset.
   * @param shares The amount of drawn shares to convert to assets amount.
   * @return The amount of assets converted from shares amount.
   */
  function previewRestoreByShares(uint256 assetId, uint256 shares) external view returns (uint256);

  /**
   * @notice Converts the specified amount of supplied shares to assets amount.
   * @dev Rounds down to the nearest assets amount.
   * @param assetId The identifier of the asset.
   * @param shares The amount of supplied shares to convert to assets amount.
   * @return The amount of supplied assets converted from shares amount.
   */
  function convertToAddedAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  /**
   * @notice Converts the specified amount of supplied assets to shares amount.
   * @dev Rounds down to the nearest shares amount.
   * @param assetId The identifier of the asset.
   * @param assets The amount of supplied assets to convert to shares amount.
   * @return The amount of supplied shares converted from assets amount.
   */
  function convertToAddedShares(uint256 assetId, uint256 assets) external view returns (uint256);

  /**
   * @notice Converts the specified amount of drawn shares to assets amount.
   * @dev Rounds up to the nearest assets amount.
   * @param assetId The identifier of the asset.
   * @param shares The amount of drawn shares to convert to assets amount.
   * @return The amount of drawn assets converted from shares amount.
   */
  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  /**
   * @notice Converts the specified amount of drawn assets to shares amount.
   * @dev Rounds down to the nearest shares amount.
   * @param assetId The identifier of the asset.
   * @param assets The amount of drawn assets to convert to shares amount.
   * @return The amount of drawn shares converted from assets amount.
   */
  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256);

  /**
   * @notice Calculates the current drawn index of the specified asset.
   * @param assetId The identifier of the asset.
   * @return The calculated current drawn index of the asset.
   */
  function getAssetDrawnIndex(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the current drawn rate of the specified asset.
   * @param assetId The identifier of the asset.
   * @return The current drawn rate of the asset.
   */
  function getAssetDrawnRate(uint256 assetId) external view returns (uint256);

  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory);

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory);

  function getAssetOwed(uint256 assetId) external view returns (uint256, uint256);

  function getAssetTotalOwed(uint256 assetId) external view returns (uint256);

  function getTotalAddedAssets(uint256 assetId) external view returns (uint256);

  function getTotalAddedShares(uint256 assetId) external view returns (uint256);

  function getLiquidity(uint256 assetId) external view returns (uint256);

  /**
   * @notice Return the amount swept (reinvested) for a certain assetId.
   * @param assetId The identifier of the asset.
   * @return The swept amount for the asset.
   */
  function getSwept(uint256 assetId) external view returns (uint256);

  function getDeficit(uint256 assetId) external view returns (uint256);

  function getSpokeCount(uint256 assetId) external view returns (uint256);

  function getSpokeAddress(uint256 assetId, uint256 index) external view returns (address);

  function isSpokeListed(uint256 assetId, address spoke) external view returns (bool);

  function getSpoke(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeData memory);

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory);

  function getSpokeOwed(uint256 assetId, address spoke) external view returns (uint256, uint256);

  function getSpokeAddedAmount(uint256 assetId, address spoke) external view returns (uint256);

  function getSpokeAddedShares(uint256 assetId, address spoke) external view returns (uint256);

  function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256);

  function getAssetCount() external view returns (uint256);
}
