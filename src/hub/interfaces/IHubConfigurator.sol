// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title IHubConfigurator
/// @author Aave Labs
/// @notice Interface for HubConfigurator.
interface IHubConfigurator {
  /// @notice Thrown when the list of assets and spoke configs are not the same length in `addSpokeToAssets`.
  error MismatchedConfigs();

  /// @notice Adds a new asset to the hub.
  /// @dev Retrieves the decimals of the underlying asset from its ERC20 contract.
  /// @dev The fee receiver is automatically added as a spoke with maximum caps.
  /// @param hub The address of the Hub contract.
  /// @param underlying The address of the underlying asset.
  /// @param feeReceiver The address of the fee receiver spoke.
  /// @param irStrategy The address of the interest rate strategy contract.
  /// @param irData The interest rate data to apply to the given asset, encoded in bytes.
  /// @return The unique identifier of the added asset.
  function addAsset(
    address hub,
    address underlying,
    address feeReceiver,
    address irStrategy,
    bytes calldata irData
  ) external returns (uint256);

  /// @notice Adds a new asset to the hub.
  /// @dev Retrieves the decimals of the underlying asset from its ERC20 contract.
  /// @dev The fee receiver is automatically added as a spoke with maximum caps.
  /// @param hub The address of the Hub contract.
  /// @param underlying The address of the underlying asset.
  /// @param decimals The number of decimals of the asset.
  /// @param feeReceiver The address of the fee receiver spoke.
  /// @param irStrategy The address of the interest rate strategy contract.
  /// @param irData The interest rate data to apply to the given asset, encoded in bytes.
  /// @return The unique identifier of the added asset.
  function addAsset(
    address hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address irStrategy,
    bytes calldata irData
  ) external returns (uint256);

  /// @notice Updates the liquidity fee of an asset.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param liquidityFee The new liquidity fee.
  function updateLiquidityFee(address hub, uint256 assetId, uint256 liquidityFee) external;

  /// @notice Updates the fee receiver of an asset.
  /// @dev The fee receiver cannot be zero.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param feeReceiver The new fee receiver.
  function updateFeeReceiver(address hub, uint256 assetId, address feeReceiver) external;

  /// @notice Updates the liquidity fee and fee receiver of an asset.
  /// @dev The fee receiver cannot be zero.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param liquidityFee The new liquidity fee.
  /// @param feeReceiver The new fee receiver.
  function updateFeeConfig(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external;

  /// @notice Updates the interest rate strategy of an asset.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param irStrategy The new interest rate strategy.
  /// @param irData The interest rate data to apply to the given asset, encoded in bytes.
  function updateInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy,
    bytes calldata irData
  ) external;

  /// @notice Updates the reinvestment controller of an asset.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param reinvestmentController The new reinvestment controller.
  function updateReinvestmentController(
    address hub,
    uint256 assetId,
    address reinvestmentController
  ) external;

  /// @notice Freezes an asset.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  function freezeAsset(address hub, uint256 assetId) external;

  /// @notice Pauses an asset.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  function pauseAsset(address hub, uint256 assetId) external;

  /// @notice Register the spoke for the specified asset in the hub.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset to register the spoke for.
  /// @param spoke The address of the Spoke contract.
  /// @param config The Spoke configuration to register.
  function addSpoke(
    address hub,
    address spoke,
    uint256 assetId,
    IHub.SpokeConfig calldata config
  ) external;

  /// @notice Registers the same spoke for multiple assets with the hub, each with their own configuration.
  /// @dev The i-th asset identifier in `assetIds` corresponds to the i-th configuration in `configs`.
  /// @param hub The address of the Hub contract.
  /// @param spoke The address of the Spoke contract.
  /// @param assetIds The list of asset identifiers to register the spoke for.
  /// @param configs The list of Spoke configurations to register.
  function addSpokeToAssets(
    address hub,
    address spoke,
    uint256[] calldata assetIds,
    IHub.SpokeConfig[] calldata configs
  ) external;

  /// @notice Updates the active flag of an asset's spoke.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @param active The new active flag.
  function updateSpokeActive(address hub, uint256 assetId, address spoke, bool active) external;

  /// @notice Updates the supply cap of an asset's spoke.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @param addCap The new supply cap.
  function updateSpokeSupplyCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap
  ) external;

  /// @notice Updates the draw cap of an asset's spoke.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @param drawCap The new draw cap.
  function updateSpokeDrawCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 drawCap
  ) external;

  /// @notice Updates the caps of an asset's spoke.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the spoke.
  /// @param addCap The new supply cap.
  /// @param drawCap The new draw cap.
  function updateSpokeCaps(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) external;

  /// @notice Pauses all assets of a spoke by setting the active flag to false.
  /// @param hub The address of the Hub contract.
  /// @param spoke The address of the spoke.
  function pauseSpoke(address hub, address spoke) external;

  /// @notice Freezes all assets of a spoke by setting the add and draw caps to zero.
  /// @param hub The address of the Hub contract.
  /// @param spoke The address of the spoke.
  function freezeSpoke(address hub, address spoke) external;

  /// @notice Updates the interest rate data for an asset.
  /// @param hub The address of the Hub contract.
  /// @param assetId The identifier of the asset.
  /// @param irData The interest rate data to apply to the given asset, encoded in bytes.
  function updateInterestRateData(address hub, uint256 assetId, bytes calldata irData) external;
}
