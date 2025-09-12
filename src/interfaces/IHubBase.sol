// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title IHubBase
 * @author Aave Labs
 * @notice Minimal interface for Hub
 */
interface IHubBase {
  event Add(uint256 indexed assetId, address indexed spoke, uint256 shares, uint256 amount);
  event Remove(uint256 indexed assetId, address indexed spoke, uint256 shares, uint256 amount);
  event Draw(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 drawnShares,
    uint256 drawnAmount
  );
  event Restore(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 drawnShares,
    DataTypes.PremiumDelta premiumDelta,
    uint256 drawnAmount,
    uint256 premiumAmount
  );

  /**
   * @notice Add asset on behalf of user.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of asset liquidity to add.
   * @param from The address which we pull assets from (user).
   * @return The amount of shares added.
   */
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256);

  /**
   * @notice Remove added asset on behalf of user.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of asset liquidity to remove.
   * @param to The address to transfer the assets to.
   * @return The amount of shares removed.
   */
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Draw assets on behalf of user.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of assets to draw.
   * @param to The address to transfer the underlying assets to.
   * @return The amount of drawn shares.
   */
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Restore assets on behalf of user.
   * @dev Only callable by active spokes.
   * @dev Interest is always paid off first from premium, then from drawn.
   * @param assetId The identifier of the asset.
   * @param drawnAmount The drawn amount to restore.
   * @param premiumAmount The premium amount to repay.
   * @param premiumDelta The premium delta to apply which signal premium repayment.
   * @param from The address to pull assets from.
   * @return The amount of drawn shares restored.
   */
  function restore(
    uint256 assetId,
    uint256 drawnAmount,
    uint256 premiumAmount,
    DataTypes.PremiumDelta calldata premiumDelta,
    address from
  ) external returns (uint256);

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
   * @notice Returns the underlying address and decimals of the specified asset.
   * @param assetId The identifier of the asset.
   * @return The underlying address of the asset.
   * @return The decimals of the asset.
   */
  function getAssetUnderlyingAndDecimals(uint256 assetId) external view returns (address, uint8);

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
   * @notice Returns the amount of owed drawn and premium assets for the specified asset.
   * @param assetId The identifier of the asset.
   * @return The amount of owed drawn assets.
   * @return The amount of owed premium assets.
   */
  function getAssetOwed(uint256 assetId) external view returns (uint256, uint256);

  /**
   * @notice Returns the total amount of the specified asset owed to the hub.
   * @param assetId The identifier of the asset.
   * @return The total amount of the asset owed.
   */
  function getAssetTotalOwed(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the amount of drawn shares of the specified asset.
   * @param assetId The identifier of the asset.
   * @return The amount of drawn shares.
   */
  function getAssetDrawnShares(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the information regarding premium shares of the specified asset.
   * @param assetId The identifier of the asset.
   * @return The amount of premium shares owed to the asset.
   * @return The premium offset of the asset.
   * @return The realized premium of the asset.
   */
  function getAssetPremiumData(uint256 assetId) external view returns (uint256, uint256, uint256);

  /**
   * @notice Returns the amount of the specified assets owed to the hub by the specified spoke.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @return The amount of owed drawn assets.
   * @return The amount of owed premium assets.
   */
  function getSpokeOwed(uint256 assetId, address spoke) external view returns (uint256, uint256);

  /**
   * @notice Returns the total amount of the specified asset owed to the hub by the specified spoke.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @return The total amount of the asset owed.
   */
  function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256);

  /**
   * @notice Returns the amount of drawn shares of the specified asset by the specified spoke.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @return The amount of drawn shares.
   */
  function getSpokeDrawnShares(uint256 assetId, address spoke) external view returns (uint256);

  /**
   * @notice Returns the information regarding premium shares of the specified asset for the specified spoke.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @return The amount of premium shares.
   * @return The premium offset.
   * @return The realized premium.
   */
  function getSpokePremiumData(
    uint256 assetId,
    address spoke
  ) external view returns (uint256, uint256, uint256);

  /**
   * @notice Returns the total amount of the specified asset added to the hub.
   * @param assetId The identifier of the asset.
   * @return The amount of the asset added.
   */
  function getAssetAddedAmount(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the total amount of shares of the specified asset added to the hub.
   * @param assetId The identifier of the asset.
   * @return The amount of shares of the asset added.
   */
  function getAssetAddedShares(uint256 assetId) external view returns (uint256);

  /**
   * @notice Returns the total amount of the specified assets added to the hub by the specified spoke.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @return The amount of added assets.
   */
  function getSpokeAddedAssets(uint256 assetId, address spoke) external view returns (uint256);

  /**
   * @notice Returns the total amount of shares of the specified asset added to the hub by the specified spoke.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @return The amount of added shares.
   */
  function getSpokeAddedShares(uint256 assetId, address spoke) external view returns (uint256);
}
