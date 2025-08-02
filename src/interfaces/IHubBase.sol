// SPDX-License-Identifier: MIT
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
}
