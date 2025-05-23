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
  event AssetConfigUpdated(uint256 indexed assetId);
  event SpokeConfigUpdated(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 drawCap,
    uint256 supplyCap
  );

  event DrawnIndexUpdate(
    uint256 indexed assetId, 
    uint256 drawnIndex,
    uint256 lastUpdateTimestamp
  );
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
    int256 realizedPremiumDelta
  );

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
  error AssetPaused();
  error AssetFrozen();
  error InvalidIrStrategy();
  error InvalidAssetDecimals();
  error InvalidAssetAddress();
  error InvalidDebtChange();

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
   * @notice Add/Supply asset on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of asset liquidity to add/supply.
   * @param from The address which we pull assets from (user).
   * @return The amount of shares added or supplied.
   */
  function add(uint256 assetId, uint256 amount, address from) external returns (uint256);

  /**
   * @notice Remove/Withdraw supplied asset on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of asset liquidity to remove/withdraw.
   * @param to The address to transfer the assets to.
   * @return The amount of shares removed or withdrawn.
   */
  function remove(uint256 assetId, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Draw/Borrow debt on behalf of user.
   * @dev Only callable by spokes.
   * @param assetId The asset id.
   * @param amount The amount of debt to draw.
   * @param to The address to transfer the underlying assets to.
   * @return The amount of base shares drawn.
   */
  function draw(uint256 assetId, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Restores/Repays debt on behalf of user.
   * @dev Only callable by spokes.
   * @dev Interest is always paid off first from premium, then from base.
   * @param assetId The asset id.
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
   * @dev Total debt should not change, reverts with `InvalidDebtChange` when violated.
   * @param assetId The asset id.
   * @param premiumDrawnSharesDelta The change in premium drawn shares.
   * @param premiumOffsetDelta The change in premium offset.
   * @param realizedPremiumDelta The change in realized premium.
   */
  function refreshPremiumDebt(
    uint256 assetId,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  ) external;

  /**
   * @notice Settles premium debt restored.
   * @dev To be called in conjunction with repay to pay premium debt, restore must account for
   * the premium restored in the available liquidity.
   * @dev Only callable by spokes.
   * @dev Base debt should not change, reverts with `InvalidDebtChange` when violated, and
   * premium debt can only decrease by at most the amount of premium restored on restore.
   * @param assetId The asset id.
   * @param premiumDrawnSharesDelta The change in premium drawn shares.
   * @param premiumOffsetDelta The change in premium offset.
   * @param realizedPremiumDelta The change in realized premium.
   */
  function settlePremiumDebt(
    uint256 assetId,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  ) external;

  function convertToDrawnAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  function convertToDrawnShares(uint256 assetId, uint256 assets) external view returns (uint256);

  function convertToSuppliedAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  function convertToSuppliedShares(uint256 assetId, uint256 assets) external view returns (uint256);

  function previewOffset(uint256 assetId, uint256 shares) external view returns (uint256);

  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory);

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory);

  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256);

  function getAssetSuppliedAmount(uint256 assetId) external view returns (uint256);

  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256);

  function getAssetTotalDebt(uint256 assetId) external view returns (uint256);

  function getTotalSuppliedAssets(uint256 assetId) external view returns (uint256);

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

  function assetCount() external view returns (uint256);

  function assetsList(uint256 assetId) external view returns (IERC20);

  function MAX_ALLOWED_ASSET_DECIMALS() external view returns (uint256);
}
