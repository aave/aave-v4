// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';

/**
 * @title ILiquidityHub
 * @author Aave Labs
 * @notice Basic interface for LiquidityHub
 */
interface ILiquidityHub is IAccessManaged {
  event SpokeAdded(uint256 indexed assetId, address indexed spoke);
  event AssetAdded(uint256 indexed assetId, address indexed underlying, uint8 decimals);
  event AssetConfigUpdated(uint256 indexed assetId, DataTypes.AssetConfig config);
  event SpokeConfigUpdated(
    uint256 indexed assetId,
    address indexed spoke,
    DataTypes.SpokeConfig config
  );
  event DrawnIndexUpdate(uint256 indexed assetId, uint256 drawnIndex, uint256 lastUpdateTimestamp);
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
    uint256 totalRestoredAmount
  );
  event RefreshPremiumDebt(
    uint256 indexed assetId,
    address indexed spoke,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  );
  event AccrueFees(uint256 indexed assetId, uint256 shares);

  error InvalidSharesAmount();
  error InvalidSupplyAmount();
  error InvalidAddFromHub();
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
  error SpokeNotListed();
  error AssetPaused();
  error AssetFrozen();
  error InvalidIrStrategy();
  error InvalidAssetDecimals();
  error InvalidLiquidityFee();
  error InvalidUnderlying();
  error InvalidDebtChange();
  error InvalidFeeReceiver();
  error SpokeNotActive();
  error InvalidFeeShares();

  /**
   * @notice Adds a new asset to the hub.
   * @dev The same underlying asset address can be added as an asset multiple times.
   * @dev The fee receiver must be configured as a Spoke separately.
   * @param underlying The address of the underlying asset.
   * @param decimals The number of decimals of the asset.
   * @param feeReceiver The address of the fee receiver spoke.
   * @param irStrategy The address of the interest rate strategy contract.
   * @return The unique identifier of the added asset.
   */
  function addAsset(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy
  ) external returns (uint256);

  /**
   * @notice Updates the configuration of an asset.
   * @param assetId The identifier of the asset.
   * @param config The new configuration for the asset.
   */
  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig calldata config) external;

  function addSpoke(uint256 assetId, address spoke, DataTypes.SpokeConfig calldata params) external;

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
   * @notice Add/Supply asset on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of asset liquidity to add/supply.
   * @param from The address which we pull assets from (user).
   * @return The amount of shares added or supplied.
   */
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256);

  /**
   * @notice Remove/Withdraw supplied asset on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of asset liquidity to remove/withdraw.
   * @param to The address to transfer the assets to.
   * @return The amount of shares removed or withdrawn.
   */
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Draw/Borrow debt on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of debt to draw.
   * @param to The address to transfer the underlying assets to.
   * @return The amount of base shares drawn.
   */
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Restores/Repays debt on behalf of user.
   * @dev Only callable by spokes.
   * @dev Interest is always paid off first from premium, then from base.
   * @param assetId The identifier of the asset.
   * @param baseAmount The base debt to repay.
   * @param premiumAmount The premium debt to repay.
   * @param from The address to pull assets from.
   * @return The amount of debt restored.
   */
  function restore(
    uint256 assetId,
    uint256 baseAmount,
    uint256 premiumAmount,
    address from
  ) external returns (uint256);

  /**
   * @notice Refreshes premium debt accounting.
   * @dev To be called when moving accrued premium to realized premium.
   * @dev Only callable by spokes.
   * @dev Premium debt can only decrease by at most the amount of realized premium taken.
   * @param assetId The identifier of the asset.
   * @param premiumDrawnSharesDelta The change in premium drawn shares.
   * @param premiumOffsetDelta The change in premium offset.
   * @param realizedPremiumAdded The increase of realized premium.
   * @param realizedPremiumTaken The decrease of realized premium.
   */
  function refreshPremiumDebt(
    uint256 assetId,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  ) external;

  /**
   * @notice Pay existing liquidity to feeReceiver.
   * @dev Only callable by spokes.
   * @param assetId The identifier of the asset.
   * @param shares The amount of shares to pay to feeReceiver.
   */
  function payFee(uint256 assetId, uint256 shares) external;

  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256);

  function convertToSuppliedAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  function convertToSuppliedAssetsUp(
    uint256 assetId,
    uint256 shares
  ) external view returns (uint256);

  function convertToSuppliedShares(uint256 assetId, uint256 assets) external view returns (uint256);

  function convertToSuppliedSharesUp(
    uint256 assetId,
    uint256 assets
  ) external view returns (uint256);

  function previewOffset(uint256 assetId, uint256 shares) external view returns (uint256);

  function previewDrawnIndex(uint256 assetId) external view returns (uint256);

  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory);

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory);

  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256);

  function getAssetSuppliedAmount(uint256 assetId) external view returns (uint256);

  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256);

  function getAssetTotalDebt(uint256 assetId) external view returns (uint256);

  function getTotalSuppliedAssets(uint256 assetId) external view returns (uint256);

  function getTotalSuppliedShares(uint256 assetId) external view returns (uint256);

  function getAvailableLiquidity(uint256 assetId) external view returns (uint256);

  function getBaseInterestRate(uint256 assetId) external view returns (uint256);

  function getSpoke(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeData memory);

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory);

  function getSpokeDebt(uint256 assetId, address spoke) external view returns (uint256, uint256);

  function getSpokeSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256);

  function getSpokeSuppliedShares(uint256 assetId, address spoke) external view returns (uint256);

  function getSpokeTotalDebt(uint256 assetId, address spoke) external view returns (uint256);

  function getAssetCount() external view returns (uint256);

  function MAX_ALLOWED_ASSET_DECIMALS() external view returns (uint8);
}
