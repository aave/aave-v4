// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {AutomationCompatibleInterface} from 'src/dependencies/chainlink/AutomationCompatibleInterface.sol';

/// @title IFeeSharesMinter
/// @author Aave Labs
/// @notice Interface for the FeeSharesMinter contract
interface IFeeSharesMinter is AutomationCompatibleInterface {
  /// @notice Emitted when the configuration for an asset is updated.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param minAccruedFeesPercent The new minimum ratio of accrued fees to total added assets, in BPS.
  event ConfigUpdated(address indexed hub, uint256 indexed assetId, uint16 minAccruedFeesPercent);

  /// @notice Thrown upon minting when the required conditions are not met.
  error ConditionsNotMet();

  /// @notice Thrown when `setConfig` is called with an invalid value.
  error InvalidConfig();

  /// @notice Sets the minimum accrued fees percent for a specific asset.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param minAccruedFeesPercent Minimum ratio of accrued fees to total added assets, in BPS. Must be greater than zero.
  function setConfig(address hub, uint256 assetId, uint16 minAccruedFeesPercent) external;

  /// @notice Chainlink Automation on-chain execution entry point.
  /// @dev performData must be abi.encoded as (address hub, uint256 assetId).
  /// @inheritdoc AutomationCompatibleInterface
  function performUpkeep(bytes calldata performData) external;

  /// @notice Chainlink Automation off-chain simulation check.
  /// @dev checkData must be abi.encoded as (address hub, uint256 assetId).
  /// @dev Returns whether upkeep is needed and the performData in bytes when conditions are met.
  /// @inheritdoc AutomationCompatibleInterface
  function checkUpkeep(
    bytes calldata checkData
  ) external view returns (bool upkeepNeeded, bytes memory performData);

  /// @notice Returns the minimum accrued fees percent for a specific asset.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @return The minimum ratio of accrued fees to total added assets, in BPS.
  function getConfig(address hub, uint256 assetId) external view returns (uint16);
}
