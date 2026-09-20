// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {IReceiver} from 'src/dependencies/chainlink/IReceiver.sol';

/// @title IFeeSharesMinter
/// @author Aave Labs
/// @notice Interface for the FeeSharesMinter contract.
/// @dev `report` for the inherited `onReport` function must be abi-encoded as `(address hub, uint256 assetId)`.
interface IFeeSharesMinter is IReceiver {
  /// @notice Authorization parameters for a CRE workflow allowed to trigger fee share minting.
  /// @dev forwarder The Keystone forwarder address authorized to deliver this workflow's reports.
  /// @dev owner The expected workflow owner, validated against the report metadata.
  /// @dev name The expected workflow name, validated against the report metadata.
  /// @dev isActive Whether this workflow is currently allowed to trigger minting.
  struct WorkflowConfig {
    address forwarder;
    address owner;
    bytes10 name;
    bool isActive;
  }

  /// @notice Emitted when the minting threshold for a hub/asset pair is updated.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param minAccruedFeesPercent The new minimum ratio of accrued fees to total added assets, in BPS.
  event ConfigUpdated(address indexed hub, uint256 indexed assetId, uint16 minAccruedFeesPercent);

  /// @notice Emitted when a workflow authorization is updated.
  /// @param workflowId The CRE workflow identifier.
  /// @param forwarder The forwarder address authorized for this workflow.
  /// @param owner The workflow owner.
  /// @param name The workflow name.
  /// @param isActive Whether the workflow is active.
  event WorkflowConfigUpdated(
    bytes32 indexed workflowId,
    address forwarder,
    address owner,
    bytes10 name,
    bool isActive
  );

  /// @notice Thrown when `onReport` is called but the minting threshold conditions are not met.
  error ConditionsNotMet();

  /// @notice Thrown when `setConfig` is called with a value above `PercentageMath.PERCENTAGE_FACTOR`.
  /// @param minAccruedFeesPercent The rejected value.
  error InvalidConfig(uint16 minAccruedFeesPercent);

  /// @notice Thrown when `onReport` receives a report for a workflow that is not active or not registered.
  /// @param workflowId The workflow identifier carried in the report metadata.
  error WorkflowNotActive(bytes32 workflowId);

  /// @notice Thrown when `onReport` is called by an address other than the workflow's configured forwarder.
  /// @param received The actual `msg.sender`.
  /// @param expected The forwarder address configured for the workflow.
  error InvalidWorkflowForwarder(address received, address expected);

  /// @notice Thrown when the workflow owner in the report metadata does not match the configured owner.
  /// @param received The owner address carried in the report metadata.
  /// @param expected The owner address configured for the workflow.
  error InvalidWorkflowOwner(address received, address expected);

  /// @notice Thrown when the workflow name in the report metadata does not match the configured name.
  /// @param received The workflow name carried in the report metadata.
  /// @param expected The workflow name configured for the workflow.
  error InvalidWorkflowName(bytes10 received, bytes10 expected);

  /// @notice Sets the minimum accrued fees percent for a specific asset.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param minAccruedFeesPercent Minimum ratio of accrued fees to total added assets, in BPS. Must be at most `PercentageMath.PERCENTAGE_FACTOR`; set to 0 to disable minting.
  function setConfig(address hub, uint256 assetId, uint16 minAccruedFeesPercent) external;

  /// @notice Registers or updates a CRE workflow authorized to trigger fee share minting.
  /// @param workflowId The workflow identifier.
  /// @param config The workflow configuration. Set `isActive` to false to disable.
  function setWorkflowConfig(bytes32 workflowId, WorkflowConfig calldata config) external;

  /// @notice Returns the minimum accrued fees percent for a specific asset.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @return The minimum ratio of accrued fees to total added assets, in BPS.
  function getConfig(address hub, uint256 assetId) external view returns (uint16);

  /// @notice Returns the configuration for a registered CRE workflow.
  /// @param workflowId The workflow identifier.
  /// @return The workflow configuration.
  function getWorkflowConfig(bytes32 workflowId) external view returns (WorkflowConfig memory);

  /// @notice Returns whether mint conditions are currently met for a specific asset.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @return True if `onReport` would succeed for this hub/asset pair given current state.
  function canMint(address hub, uint256 assetId) external view returns (bool);
}
