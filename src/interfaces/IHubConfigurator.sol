// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title IHubConfigurator
 * @author Aave Labs
 * @notice Interface for the HubConfigurator
 */
interface IHubConfigurator {
  /**
   * @notice Thrown when the the list of assets and spoke configs are not the same length in `addSpokeToAssets`.
   */
  error MismatchedConfigs();

  /**
   * @notice Adds a new asset to the hub.
   * @dev Retrieves the decimals of the underlying asset from its ERC20 contract.
   * @dev The fee receiver is automatically added as a spoke with maximum caps.
   * @param hub The address of the Hub contract.
   * @param underlying The address of the underlying asset.
   * @param feeReceiver The address of the fee receiver spoke.
   * @param irStrategy The address of the interest rate strategy contract.
   * @param data The interest rate data to apply to the given asset, all in bps, encoded in bytes.
   * @return The unique identifier of the added asset.
   */
  function addAsset(
    address hub,
    address underlying,
    address feeReceiver,
    address irStrategy,
    bytes calldata data
  ) external returns (uint256);

  /**
   * @notice Adds a new asset to the hub.
   * @dev Retrieves the decimals of the underlying asset from its ERC20 contract.
   * @dev The fee receiver is automatically added as a spoke with maximum caps.
   * @param hub The address of the Hub contract.
   * @param underlying The address of the underlying asset.
   * @param decimals The number of decimals of the asset.
   * @param feeReceiver The address of the fee receiver spoke.
   * @param irStrategy The address of the interest rate strategy contract.
   * @param data The interest rate data to apply to the given asset, all in bps, encoded in bytes.
   * @return The unique identifier of the added asset.
   */
  function addAsset(
    address hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata data
  ) external returns (uint256);

  /**
   * @notice Updates the liquidity fee of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param liquidityFee The new liquidity fee.
   */
  function updateLiquidityFee(address hub, uint256 assetId, uint256 liquidityFee) external;

  /**
   * @notice Updates the fee receiver of an asset.
   * @dev The fee receiver cannot be zero.
   * @dev Before updating the fee receiver, it adjusts the spoke config of the old and new fee receivers.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param feeReceiver The new fee receiver.
   */
  function updateFeeReceiver(address hub, uint256 assetId, address feeReceiver) external;

  /**
   * @notice Updates the liquidity fee and fee receiver of an asset.
   * @dev Before updating the fee receiver, it adjusts the spoke config of the old and new fee receivers.
   * @dev The fee receiver cannot be zero.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param liquidityFee The new liquidity fee.
   * @param feeReceiver The new fee receiver.
   */
  function updateFeeConfig(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external;

  /**
   * @notice Updates the interest rate strategy of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param irStrategy The new interest rate strategy.
   */
  function updateInterestRateStrategy(address hub, uint256 assetId, address irStrategy) external;

  /**
   * @notice Updates the config of an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param config The new asset config.
   */
  function updateAssetConfig(
    address hub,
    uint256 assetId,
    DataTypes.AssetConfig calldata config
  ) external;

  /**
   * @notice Freezes an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   */
  function freezeAsset(address hub, uint256 assetId) external;

  /**
   * @notice Pauses an asset.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   */
  function pauseAsset(address hub, uint256 assetId) external;

  /**
   * @notice Register the spoke for the specified asset in the hub.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset to register the spoke for.
   * @param spoke The address of the Spoke contract.
   * @param config The Spoke configuration to register.
   */
  function addSpoke(
    address hub,
    address spoke,
    uint256 assetId,
    DataTypes.SpokeConfig calldata config
  ) external;

  /**
   * @notice Registers the same spoke for multiple assets with the hub, each with their own configuration.
   * @dev The i-th asset identifier in `assetIds` corresponds to the i-th configuration in `configs`.
   * @param hub The address of the Hub contract.
   * @param assetIds The list of asset identifiers to register the spoke for.
   * @param spoke The address of the Spoke contract.
   * @param configs The list of Spoke configurations to register.
   */
  function addSpokeToAssets(
    address hub,
    address spoke,
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] calldata configs
  ) external;

  /**
   * @notice Updates the active flag of an asset's spoke.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @param active The new active flag.
   */
  function updateSpokeActive(address hub, uint256 assetId, address spoke, bool active) external;

  /**
   * @notice Updates the supply cap of an asset's spoke.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @param addCap The new supply cap.
   */
  function updateSpokeSupplyCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap
  ) external;

  /**
   * @notice Updates the draw cap of an asset's spoke.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @param drawCap The new draw cap.
   */
  function updateSpokeDrawCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 drawCap
  ) external;

  /**
   * @notice Updates the caps of an asset's spoke.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @param addCap The new supply cap.
   * @param drawCap The new draw cap.
   */
  function updateSpokeCaps(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) external;

  /**
   * @notice Updates the config of an asset's spoke.
   * @param hub The address of the Hub contract.
   * @param assetId The identifier of the asset.
   * @param spoke The address of the spoke.
   * @param config The new spoke config.
   */
  function updateSpokeConfig(
    address hub,
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata config
  ) external;
}
