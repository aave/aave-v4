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

  // todo: remove explicit rounding
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

/**
 * @title Liquidity Hub Errors Library
 * @author Aave Labs
 * @notice Defines the error messages emitted by the LiquidityHub
 */
library LiquidityHubErrors {
  string public constant MISMATCHED_CONFIGS = 'MISMATCHED_CONFIGS';
  string public constant INVALID_SHARES_AMOUNT = 'INVALID_SHARES_AMOUNT';
  string public constant INVALID_SUPPLY_AMOUNT = 'INVALID_SUPPLY_AMOUNT';
  string public constant ASSET_NOT_LISTED = 'ASSET_NOT_LISTED';
  string public constant ASSET_NOT_ACTIVE = 'ASSET_NOT_ACTIVE';
  string public constant SUPPLY_CAP_EXCEEDED = 'SUPPLY_CAP_EXCEEDED';
  string public constant INVALID_WITHDRAW_AMOUNT = 'INVALID_WITHDRAW_AMOUNT';
  string public constant SUPPLIED_AMOUNT_EXCEEDED = 'SUPPLIED_AMOUNT_EXCEEDED';
  string public constant NOT_AVAILABLE_LIQUIDITY = 'NOT_AVAILABLE_LIQUIDITY';
  string public constant INVALID_DRAW_AMOUNT = 'INVALID_DRAW_AMOUNT';
  string public constant DRAW_CAP_EXCEEDED = 'DRAW_CAP_EXCEEDED';
  string public constant INVALID_RESTORE_AMOUNT = 'INVALID_RESTORE_AMOUNT';
  string public constant INVALID_SPOKE = 'INVALID_SPOKE';
  string public constant INVALID_BPS = 'INVALID_BPS';
}
