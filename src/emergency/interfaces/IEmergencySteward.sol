// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IEmergencySteward
/// @author Aave Labs
/// @notice Interface for the EmergencySteward, which runs the bulk emergency levers through the SpokeConfigurator.
interface IEmergencySteward {
  /// @notice Thrown when an address parameter is the zero address.
  error InvalidAddress();

  /// @notice Pauses all reserves of a Spoke.
  /// @dev Applies `SpokeConfigurator.holdPaused` to each reserve, which records the reserves this lever pauses so
  /// `unpauseAllReserves` unpauses only those. Reserves that were already paused are not recorded.
  /// @param spoke The address of the Spoke.
  function pauseAllReserves(address spoke) external;

  /// @notice Unpauses the reserves that `pauseAllReserves` paused on a Spoke.
  /// @dev Applies `SpokeConfigurator.releasePaused` to each reserve. Reserves paused before `pauseAllReserves`, or
  /// set later through `pauseReserve` or `updatePaused`, keep their paused flag. Changes made directly on the
  /// Spoke, bypassing the SpokeConfigurator, are not tracked.
  /// @param spoke The address of the Spoke.
  function unpauseAllReserves(address spoke) external;

  /// @notice Freezes all reserves of a Spoke and zeroes their collateral factors.
  /// @dev Applies `SpokeConfigurator.holdFrozen` to each reserve, skipping reserves already frozen with a zero
  /// collateral factor. Records the reserves it freezes so `unfreezeSpoke` unfreezes only those. Reserves that
  /// were already frozen are recorded only if `freezeAsset` froze them, so they stay frozen until both
  /// `unfreezeAsset` and `unfreezeSpoke` run.
  /// @param spoke The address of the Spoke.
  function freezeSpoke(address spoke) external;

  /// @notice Unfreezes the reserves that `freezeSpoke` froze on a Spoke.
  /// @dev Applies `SpokeConfigurator.releaseFrozen` to each reserve. Reserves also frozen by `freezeAsset` stay
  /// frozen until `unfreezeAsset` runs. Reserves frozen before `freezeSpoke`, or set later through
  /// `freezeReserve` or `unfreezeReserve`, keep their frozen flag. Changes made directly on the Spoke, bypassing
  /// the SpokeConfigurator, are not tracked.
  /// @dev Only clears the frozen flag; collateral factors are restored separately via `restoreCollateralFactor`.
  /// @param spoke The address of the Spoke.
  function unfreezeSpoke(address spoke) external;

  /// @notice Freezes the reserve of an asset and zeroes its collateral factor on every Spoke registered for that
  /// asset on a specified Hub.
  /// @dev Applies `SpokeConfigurator.holdFrozen` to the asset's reserve on each Spoke, skipping reserves already
  /// frozen with a zero collateral factor and Spokes without a reserve for the asset, such as the TreasurySpoke
  /// and TokenizationSpoke. Records the reserves it freezes so `unfreezeAsset` unfreezes only those. Reserves
  /// that were already frozen are recorded only if `freezeSpoke` froze them, so they stay frozen until both
  /// `unfreezeSpoke` and `unfreezeAsset` run.
  /// @dev Reverts if any Spoke with a reserve for the asset has not granted the SpokeConfigurator permission.
  /// @dev Reverts with the Spoke's error if its reserve lookup fails for a reason other than `ReserveNotListed` or
  /// a missing `getReserveId`.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function freezeAsset(address hub, address underlying) external;

  /// @notice Unfreezes the reserves that `freezeAsset` froze for an asset on a specified Hub.
  /// @dev Applies `SpokeConfigurator.releaseFrozen` to the asset's reserve on each Spoke. Reserves also frozen by
  /// `freezeSpoke` stay frozen until `unfreezeSpoke` runs. Reserves frozen before `freezeAsset`, or set later
  /// through `freezeReserve` or `unfreezeReserve`, keep their frozen flag. Changes made directly on a Spoke,
  /// bypassing the SpokeConfigurator, are not tracked.
  /// @dev Only clears the frozen flag; collateral factors are restored separately via `restoreCollateralFactor`.
  /// @dev Reverts if a Spoke whose reserve it unfreezes has not granted the SpokeConfigurator permission.
  /// @dev Reverts with the Spoke's error if its reserve lookup fails for a reason other than `ReserveNotListed` or
  /// a missing `getReserveId`.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function unfreezeAsset(address hub, address underlying) external;

  /// @notice Returns the address of the SpokeConfigurator that the levers call.
  /// @return The address of the SpokeConfigurator.
  function SPOKE_CONFIGURATOR() external view returns (address);
}
