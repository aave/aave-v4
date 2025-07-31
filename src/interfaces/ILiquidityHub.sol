// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

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
  event AssetUpdated(
    uint256 indexed assetId,
    uint256 drawnIndex,
    uint256 baseBorrowRate,
    uint256 latestUpdateTimestamp
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
    DataTypes.PremiumDelta premiumDelta,
    uint256 baseRestoredAmount,
    uint256 premiumRestoredAmount
  );
  event RefreshPremiumDebt(
    uint256 indexed assetId,
    address indexed spoke,
    DataTypes.PremiumDelta premiumDelta
  );
  event DeficitReported(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 baseRestoredShares,
    DataTypes.PremiumDelta premiumDelta,
    uint256 totalRestoredAmount
  );
  event AccrueFees(uint256 indexed assetId, uint256 shares);

  /**
   * @notice Emitted when some deficit is eliminated.
   * @param assetId The identifier of the asset.
   * @param spoke The spoke that eliminated the deficit, and had supplied shares removed.
   * @param removedShares The amount of shares removed.
   * @param amount The amount of deficit eliminated.
   */
  event DeficitEliminated(
    uint256 indexed assetId,
    address indexed spoke,
    uint256 removedShares,
    uint256 amount
  );

  error InvalidSharesAmount();
  error InvalidAddAmount();
  error InvalidFromAddress();
  error InvalidToAddress();
  error AssetNotListed();
  error SupplyCapExceeded(uint256 supplyCap);
  error InvalidRemoveAmount();
  error InvalidRestoreAmount();
  error SuppliedAmountExceeded(uint256 suppliedAmount);
  error NotAvailableLiquidity(uint256 availableLiquidity);
  error InvalidDrawAmount();
  error DrawCapExceeded(uint256 drawCap);
  error SurplusAmountRestored(uint256 maxAllowedRestore);
  error InvalidSpoke();
  error SpokeNotListed();
  error SpokeAlreadyListed();
  error InvalidIrStrategy();
  error InvalidAssetDecimals();
  error InvalidLiquidityFee();
  error InvalidUnderlying();
  error InvalidDebtChange();
  error InvalidDeficitAmount();
  error InvalidFeeReceiver();
  error SurplusDeficitReported(uint256 amount);
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

  /**
   * @notice Refreshes premium debt accounting.
   * @dev Only callable by active spokes, reverts with `SpokeNotActive` otherwise.
   * @dev Overall premium debt should not decrease, reverts with `InvalidDebtChange` otherwise.
   * @param assetId The identifier of the asset.
   * @param premiumDelta The change in premium debt.
   */
  function refreshPremiumDebt(
    uint256 assetId,
    DataTypes.PremiumDelta calldata premiumDelta
  ) external;

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
   * @param baseAmount The base debt to report as deficit.
   * @param premiumAmount The premium debt to report as deficit.
   * @param premiumDelta The premium debt delta to apply which signal premium debt deficit.
   * @return The amount of base debt shares reported as deficit.
   */
  function reportDeficit(
    uint256 assetId,
    uint256 baseAmount,
    uint256 premiumAmount,
    DataTypes.PremiumDelta calldata premiumDelta
  ) external returns (uint256);

  /**
   * @notice Eliminates deficit by removing supplied shares of caller spoke.
   * @dev Only callable by active spokes.
   * @param assetId The identifier of the asset.
   * @param amount The amount of deficit to eliminate.
   * @return The amount of shares removed.
   */
  function eliminateDeficit(uint256 assetId, uint256 amount) external returns (uint256);

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
  function convertToSuppliedAssets(uint256 assetId, uint256 shares) external view returns (uint256);

  /**
   * @notice Converts the specified amount of supplied assets to shares amount.
   * @dev Rounds down to the nearest shares amount.
   * @param assetId The identifier of the asset.
   * @param assets The amount of supplied assets to convert to shares amount.
   * @return The amount of supplied shares converted from assets amount.
   */
  function convertToSuppliedShares(uint256 assetId, uint256 assets) external view returns (uint256);

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

  function getAsset(uint256 assetId) external view returns (DataTypes.Asset memory);

  function getAssetConfig(uint256 assetId) external view returns (DataTypes.AssetConfig memory);

  function getAssetDebt(uint256 assetId) external view returns (uint256, uint256);

  function getAssetSuppliedAmount(uint256 assetId) external view returns (uint256);

  function getAssetSuppliedShares(uint256 assetId) external view returns (uint256);

  function getAssetTotalDebt(uint256 assetId) external view returns (uint256);

  function getTotalSuppliedAssets(uint256 assetId) external view returns (uint256);

  function getTotalSuppliedShares(uint256 assetId) external view returns (uint256);

  function getAvailableLiquidity(uint256 assetId) external view returns (uint256);

  function getDeficit(uint256 assetId) external view returns (uint256);

  function getBaseInterestRate(uint256 assetId) external view returns (uint256);

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

  function getSpokeDebt(uint256 assetId, address spoke) external view returns (uint256, uint256);

  function getSpokeSuppliedAmount(uint256 assetId, address spoke) external view returns (uint256);

  function getSpokeSuppliedShares(uint256 assetId, address spoke) external view returns (uint256);

  function getSpokeTotalDebt(uint256 assetId, address spoke) external view returns (uint256);

  function getAssetCount() external view returns (uint256);

  function MAX_ALLOWED_ASSET_DECIMALS() external view returns (uint8);
}
