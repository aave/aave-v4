// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';

/// @title IHub
/// @author Aave Labs
/// @notice Full interface for Hub.
interface IHub is IHubBase, IAccessManaged {
  struct Asset {
    uint128 liquidity;
    uint128 addedShares;
    //
    uint128 deficit;
    uint128 swept;
    //
    uint128 premiumShares;
    uint128 premiumOffset;
    //
    uint128 drawnShares;
    uint128 realizedPremium;
    //
    uint128 drawnIndex;
    uint96 drawnRate;
    uint32 lastUpdateTimestamp;
    //
    address underlying;
    //
    address irStrategy;
    //
    address reinvestmentController;
    //
    address feeReceiver;
    uint16 liquidityFee;
    uint8 decimals;
  }

  struct AssetConfig {
    address feeReceiver;
    uint16 liquidityFee;
    address irStrategy;
    address reinvestmentController;
  }

  struct SpokeData {
    uint128 premiumShares;
    uint128 premiumOffset;
    //
    uint128 realizedPremium;
    uint128 drawnShares;
    //
    uint128 addedShares;
    uint56 addCap;
    uint56 drawCap;
    bool active;
    //
    uint128 deficit;
  }

  struct SpokeConfig {
    bool active;
    uint56 addCap;
    uint56 drawCap;
  }

  /// @notice Emitted when a spoke is added.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  event AddSpoke(uint256 indexed assetId, address indexed spoke);

  /// @notice Emitted when an asset is added.
  /// @param assetId The identifier of the asset.
  /// @param underlying The address of the underlying asset.
  /// @param decimals The number of decimals of the asset.
  event AddAsset(uint256 indexed assetId, address indexed underlying, uint8 decimals);

  /// @notice Emitted when an asset configuration is updated.
  /// @param assetId The identifier of the asset.
  /// @param config The new asset configuration struct.
  event UpdateAssetConfig(uint256 indexed assetId, AssetConfig config);

  /// @notice Emitted when a spoke configuration is updated.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @param config The new spoke configuration struct.
  event UpdateSpokeConfig(uint256 indexed assetId, address indexed spoke, SpokeConfig config);

  /// @notice Emitted when an asset is updated.
  /// @param assetId The identifier of the asset.
  /// @param drawnIndex The new drawn index of the asset.
  /// @param drawnRate The new drawn rate of the asset.
  event UpdateAsset(uint256 indexed assetId, uint256 drawnIndex, uint256 drawnRate);

  /// @notice Emitted when fees are accrued to `feeReceiver`.
  /// @param assetId The identifier of the asset.
  /// @param shares The amount of shares accrued.
  event AccrueFees(uint256 indexed assetId, uint256 shares);

  /// @notice Emitted when an amount of liquidity is swept by the reinvestment controller.
  /// @param assetId The identifier of the asset.
  /// @param reinvestmentController The active asset controller.
  /// @param amount The amount swept.
  event Sweep(uint256 indexed assetId, address indexed reinvestmentController, uint256 amount);

  /// @notice Emitted when an amount of liquidity is reclaimed (from swept liquidity) by the reinvestment controller.
  /// @param assetId The identifier of the asset.
  /// @param reinvestmentController The active asset controller.
  /// @param amount The amount reclaimed.
  event Reclaim(uint256 indexed assetId, address indexed reinvestmentController, uint256 amount);

  /// @notice Emitted when deficit is eliminated.
  /// @param assetId The identifier of the asset.
  /// @param callerSpoke The spoke that eliminated the deficit using its supplied shares.
  /// @param coveredSpoke The spoke for which the deficit was eliminated.
  /// @param shares The amount of shares removed.
  /// @param amount The amount of deficit eliminated.
  event EliminateDeficit(
    uint256 indexed assetId,
    address indexed callerSpoke,
    address indexed coveredSpoke,
    uint256 shares,
    uint256 amount
  );

  /// @notice Thrown when an asset is not listed.
  error AssetNotListed();

  /// @notice Thrown when the add cap is exceeded.
  /// @param addCap The current `addCap` of the asset.
  error AddCapExceeded(uint256 addCap);

  /// @notice Thrown when the added amount is exceeded.
  /// @param addedAmount The current removable asset balance.
  error AddedAmountExceeded(uint256 addedAmount);

  /// @notice Thrown when the added shares are exceeded.
  /// @param addedShares The current removable shares balance.
  error AddedSharesExceeded(uint256 addedShares);

  /// @notice Thrown when the liquidity is insufficient.
  /// @param liquidity The current available liquidity.
  error InsufficientLiquidity(uint256 liquidity);

  /// @notice Thrown when the draw cap is exceeded.
  /// @param drawCap The current `drawCap` of the asset.
  error DrawCapExceeded(uint256 drawCap);

  /// @notice Thrown when a surplus amount is restored.
  /// @param maxAllowedRestore The maximum allowed restore amount.
  error SurplusAmountRestored(uint256 maxAllowedRestore);

  /// @notice Thrown when the premium change is invalid.
  error InvalidPremiumChange();

  /// @notice Thrown when a surplus deficit is reported.
  /// @param amount The amount of surplus deficit assets.
  error SurplusDeficitReported(uint256 amount);

  /// @notice Thrown when a spoke is not active.
  error SpokeNotActive();

  /// @notice Thrown when a new reinvestment controller is the zero address and the asset has existing swept liquidity.
  error InvalidReinvestmentController();

  /// @notice Thrown when an invalid reinvestment controller attempts to perform a `sweep` action.
  error OnlyReinvestmentController();

  /// @notice Thrown when a spoke being added is already listed.
  error SpokeAlreadyListed();

  /// @notice Thrown when a spoke being updated is not listed.
  error SpokeNotListed();

  /// @notice Thrown when the amount is invalid.
  error InvalidAmount();

  /// @notice Thrown when the shares amount is invalid.
  error InvalidShares();

  /// @notice Thrown when an input address is invalid.
  error InvalidAddress();

  /// @notice Thrown if the liquidity fee is invalid when updating an asset configuration.
  error InvalidLiquidityFee();

  /// @notice Thrown when the asset decimals exceed the maximum allowed decimals.
  error InvalidAssetDecimals();

  /// @notice Thrown if the interest rate strategy or data are invalid when updating an asset configuration.
  /// @dev The `irData` must be empty if the interest rate strategy is not updated.
  error InvalidInterestRateStrategy();

  /// @notice Adds a new asset to the hub.
  /// @dev The same underlying asset address can be added as an asset multiple times.
  /// @dev The fee receiver is added as a new spoke with maximum add cap and zero draw cap.
  /// @param underlying The address of the underlying asset.
  /// @param decimals The number of decimals of `underlying`.
  /// @param feeReceiver The address of the fee receiver spoke.
  /// @param irStrategy The address of the interest rate strategy contract.
  /// @param irData The interest rate data to apply to the given asset encoded in bytes.
  /// @return The unique identifier of the added asset.
  function addAsset(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata irData
  ) external returns (uint256);

  /// @notice Updates the configuration of an asset.
  /// @dev If the fee receiver is updated, adds it as a new spoke with maximum add cap and zero draw cap, and sets old fee receiver caps to zero.
  /// @dev If the interest rate strategy is updated, it is configured with `irData`. Otherwise, `irData` must be empty.
  /// @param assetId The identifier of the asset.
  /// @param config The new configuration for the asset.
  /// @param irData The interest rate data to apply to the given asset, encoded in bytes.
  function updateAssetConfig(
    uint256 assetId,
    AssetConfig calldata config,
    bytes calldata irData
  ) external;

  /// @notice Registers a new spoke for a specific asset in the hub.
  /// @dev Reverts with `SpokeAlreadyListed` if spoke is already listed.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke to add.
  /// @param params The configuration parameters for the spoke.
  function addSpoke(uint256 assetId, address spoke, SpokeConfig calldata params) external;

  /// @notice Updates the configuration of a spoke for a specific asset.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke to update.
  /// @param config The new configuration for the spoke.
  function updateSpokeConfig(uint256 assetId, address spoke, SpokeConfig calldata config) external;

  /// @notice Updates the interest rate strategy for a specified asset.
  /// @param assetId The identifier of the asset.
  /// @param irData The interest rate data to apply to the given asset, encoded in bytes.
  function setInterestRateData(uint256 assetId, bytes calldata irData) external;

  /// @notice Allows a spoke to transfer its supplied shares of an asset to another spoke.
  /// @dev Only callable by spokes.
  /// @param assetId The identifier of the asset.
  /// @param shares The amount of shares to move.
  /// @param toSpoke The address of the recipient spoke.
  function transferShares(uint256 assetId, uint256 shares, address toSpoke) external;

  /// @notice Eliminates deficit by removing supplied shares of caller spoke.
  /// @dev Only callable by active spokes.
  /// @param assetId The identifier of the asset.
  /// @param amount The amount of deficit to eliminate.
  /// @param spoke The spoke for which the deficit is eliminated.
  /// @return The amount of shares removed.
  function eliminateDeficit(
    uint256 assetId,
    uint256 amount,
    address spoke
  ) external returns (uint256);

  /// @notice Sweeps an amount of liquidity of the corresponding asset and sends it to the configured reinvestment controller.
  /// @dev The controller handles the actual reinvestment of funds, redistribution of interest, and investment caps.
  /// @param assetId The identifier of the asset.
  /// @param amount The amount to sweep.
  function sweep(uint256 assetId, uint256 amount) external;

  /// @notice Reclaims an amount of liquidity of the corresponding asset from the configured reinvestment controller.
  /// @dev The controller can only reclaim up to swept amount. All accrued interest is distributed offchain.
  /// @param assetId The identifier of the asset.
  /// @param amount The amount to reclaim.
  function reclaim(uint256 assetId, uint256 amount) external;

  /// @notice Returns the maximum allowed number of decimals for the underlying asset.
  /// @return The maximum number of decimals (inclusive).
  function MAX_ALLOWED_UNDERLYING_DECIMALS() external view returns (uint8);

  /// @notice Returns the minimum allowed number of decimals for the underlying asset.
  /// @return The minimum number of decimals (inclusive).
  function MIN_ALLOWED_UNDERLYING_DECIMALS() external view returns (uint8);

  /// @notice Returns the maximum value for any spoke cap (add or draw).
  /// @dev The value is not inclusive; using the maximum value indicates no cap.
  /// @return The maximum cap value, expressed in asset units.
  function MAX_ALLOWED_SPOKE_CAP() external view returns (uint56);

  /// @notice Converts the given amount of supplied shares to assets amount for the specified asset.
  /// @dev Rounds down to the nearest assets amount.
  /// @param assetId The identifier of the asset.
  /// @param shares The amount of supplied shares to convert to assets amount.
  /// @return The amount of supplied assets converted from shares amount.
  function convertToAddedAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  /// @notice Converts the given amount of supplied assets to shares amount for the specified asset.
  /// @dev Rounds down to the nearest shares amount.
  /// @param assetId The identifier of the asset.
  /// @param assets The amount of supplied assets to convert to shares amount.
  /// @return The amount of supplied shares converted from assets amount.
  function convertToAddedShares(uint256 assetId, uint256 assets) external view returns (uint256);

  /// @notice Converts the given amount of drawn shares to assets amount for the specified asset.
  /// @dev Rounds up to the nearest assets amount.
  /// @param assetId The identifier of the asset.
  /// @param shares The amount of drawn shares to convert to assets amount.
  /// @return The amount of drawn assets converted from shares amount.
  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  /// @notice Converts the specified amount of drawn assets to shares amount.
  /// @dev Rounds up to the nearest shares amount.
  /// @param assetId The identifier of the asset.
  /// @param assets The amount of drawn assets to convert to shares amount.
  /// @return The amount of drawn shares converted from assets amount.
  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256);

  /// @notice Calculates the current drawn index for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The current drawn index of the asset.
  function getAssetDrawnIndex(uint256 assetId) external view returns (uint256);

  /// @notice Returns the current drawn rate for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The current drawn rate of the asset.
  function getAssetDrawnRate(uint256 assetId) external view returns (uint256);

  /// @notice Returns information regarding the specified asset.
  /// @dev `drawnIndex`, `drawnRate` and `lastUpdateTimestamp` can be outdated due to passage of time.
  /// @param assetId The identifier of the asset.
  /// @return The asset struct.
  function getAsset(uint256 assetId) external view returns (Asset memory);

  /// @notice Returns the asset configuration for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The asset configuration struct.
  function getAssetConfig(uint256 assetId) external view returns (AssetConfig memory);

  /// @notice Returns the amount of drawn and premium assets owed for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The amount of drawn assets owed.
  /// @return The amount of premium assets owed.
  function getAssetOwed(uint256 assetId) external view returns (uint256, uint256);

  /// @notice Returns the total amount of assets owed for the specified asset.
  /// @dev The total amount of assets owed is the sum of the drawn and premium assets owed.
  /// @param assetId The identifier of the asset.
  /// @return The total amount of the assets owed.
  function getAssetTotalOwed(uint256 assetId) external view returns (uint256);

  /// @notice Returns the amount of drawn shares for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The amount of drawn shares.
  function getAssetDrawnShares(uint256 assetId) external view returns (uint256);

  /// @notice Returns the premium data for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The premium shares of the asset.
  /// @return The premium offset of the asset.
  /// @return The realized premium of the asset.
  function getAssetPremiumData(uint256 assetId) external view returns (uint256, uint256, uint256);

  /// @notice Returns the amount of available liquidity for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The amount of available liquidity.
  function getLiquidity(uint256 assetId) external view returns (uint256);

  /// @notice Returns the amount of liquidity swept by the reinvestment controller for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The amount of liquidity swept.
  function getSwept(uint256 assetId) external view returns (uint256);

  /// @notice Returns the amount of deficit of the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The amount of deficit.
  function getAssetDeficit(uint256 assetId) external view returns (uint256);

  /// @notice Returns the number of spokes listed for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @return The number of spokes.
  function getSpokeCount(uint256 assetId) external view returns (uint256);

  /// @notice Returns the address of the spoke for an asset at the given index.
  /// @param assetId The identifier of the asset.
  /// @param index The index of the spoke.
  /// @return The address of the spoke.
  function getSpokeAddress(uint256 assetId, uint256 index) external view returns (address);

  /// @notice Returns whether the spoke is listed for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @return True if the spoke is listed, false otherwise.
  function isSpokeListed(uint256 assetId, address spoke) external view returns (bool);

  /// @notice Returns the spoke data struct.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @return The spoke data struct.
  function getSpoke(uint256 assetId, address spoke) external view returns (SpokeData memory);

  /// @notice Returns the amount of a given spoke's deficit for the specified asset.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @return The amount of deficit.
  function getSpokeDeficit(uint256 assetId, address spoke) external view returns (uint256);

  /// @notice Returns the spoke configuration struct.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @return The spoke configuration struct.
  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (SpokeConfig memory);

  /// @notice Returns the total asset amount owed to the hub by the spoke for the specified asset.
  /// @dev The total amount owed is the sum of the drawn and premium assets owed.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @return The total amount of assets owed.
  function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256);

  /// @notice Returns the number of listed assets.
  /// @return The number of listed assets.
  function getAssetCount() external view returns (uint256);
}
