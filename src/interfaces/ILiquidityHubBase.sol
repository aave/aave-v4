// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title ILiquidityHubBase
 * @author Aave Labs
 * @notice Minimal interface for LiquidityHub
 */
interface ILiquidityHubBase {
  event Add(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 suppliedShares,
    uint256 suppliedAmount
  );
  event Remove(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 withdrawnShares,
    uint256 withdrawnAmount
  );
  event Draw(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 drawnShares,
    uint256 drawnAmount
  );
  event Restore(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 baseRestoredShares,
    DataTypes.PremiumDelta premiumDelta,
    uint256 baseRestoredAmount,
    uint256 premiumRestoredAmount
  );

  /**
   * @notice Add/Supply asset on behalf of user.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of asset liquidity to add/supply.
   * @param from The address which we pull assets from (user).
   * @return The amount of shares added or supplied.
   */
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256);

  /**
   * @notice Remove/Withdraw supplied asset on behalf of user.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of asset liquidity to remove/withdraw.
   * @param to The address to transfer the assets to.
   * @return The amount of shares removed or withdrawn.
   */
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Draw/Borrow debt on behalf of user.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of debt to draw.
   * @param to The address to transfer the underlying assets to.
   * @return The amount of base shares drawn.
   */
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Restores/Repays debt on behalf of user.
   * @dev Only callable by active spokes.
   * @dev Interest is always paid off first from premium, then from base.
   * @param assetId The identifier of the asset.
   * @param baseAmount The base debt to repay.
   * @param premiumAmount The premium debt to repay.
   * @param premiumDelta The premium debt delta to apply which signal premium debt repayment.
   * @param from The address to pull assets from.
   * @return The amount of base debt shares restored.
   */
  function restore(
    uint256 assetId,
    uint256 baseAmount,
    uint256 premiumAmount,
    DataTypes.PremiumDelta calldata premiumDelta,
    address from
  ) external returns (uint256);
}
