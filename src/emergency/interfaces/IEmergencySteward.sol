// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IEmergencySteward
/// @author Aave Labs
/// @notice Interface for the EmergencySteward.
interface IEmergencySteward {
  /// @notice Thrown when an address parameter is the zero address.
  error InvalidAddress();

  /// @notice Pauses all reserves of a Spoke.
  /// @dev Records the reserves it pauses so `unpauseAllReserves` unpauses only those.
  /// @param spoke The address of the Spoke.
  function pauseAllReserves(address spoke) external;

  /// @notice Unpauses the reserves that `pauseAllReserves` paused on a Spoke.
  /// @param spoke The address of the Spoke.
  function unpauseAllReserves(address spoke) external;

  /// @notice Freezes all reserves of a Spoke and zeroes their collateral factors.
  /// @dev Records the reserves it freezes so `unfreezeSpoke` unfreezes only those, and the collateral factors it
  /// zeroes so `restoreSpokeCollateralFactor` restores only those.
  /// @param spoke The address of the Spoke.
  function freezeSpoke(address spoke) external;

  /// @notice Unfreezes the reserves that `freezeSpoke` froze on a Spoke.
  /// @dev Reserves also frozen by `freezeAsset` stay frozen. Does not restore collateral factors; see
  /// `restoreSpokeCollateralFactor`.
  /// @param spoke The address of the Spoke.
  function unfreezeSpoke(address spoke) external;

  /// @notice Restores the collateral factors that `freezeSpoke` zeroed on a Spoke.
  /// @dev Collateral factors also zeroed by another lever stay at zero. Skips reserves that are paused or still
  /// frozen by a bulk lever; call again once they are released.
  /// @param spoke The address of the Spoke.
  function restoreSpokeCollateralFactor(address spoke) external;

  /// @notice Freezes the reserve of an asset and zeroes its collateral factor on every Spoke registered for that
  /// asset on a specified Hub.
  /// @dev Records the reserves it freezes so `unfreezeAsset` unfreezes only those, and the collateral factors it
  /// zeroes so `restoreAssetCollateralFactor` restores only those. Skips Spokes without a reserve for the asset.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function freezeAsset(address hub, address underlying) external;

  /// @notice Unfreezes the reserves that `freezeAsset` froze for an asset on a specified Hub.
  /// @dev Reserves also frozen by `freezeSpoke` stay frozen. Does not restore collateral factors; see
  /// `restoreAssetCollateralFactor`.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function unfreezeAsset(address hub, address underlying) external;

  /// @notice Zeroes the collateral factor of an asset on every Spoke registered for that asset on a specified Hub,
  /// without freezing it.
  /// @dev Records the collateral factors it zeroes so `restoreAssetCollateralFactor` restores only those. Skips
  /// Spokes without a reserve for the asset.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function zeroAssetCollateralFactor(address hub, address underlying) external;

  /// @notice Restores the collateral factors that `zeroAssetCollateralFactor` or `freezeAsset` zeroed for an asset
  /// on a specified Hub.
  /// @dev Collateral factors also zeroed by another lever stay at zero. Skips reserves that are paused or still
  /// frozen by a bulk lever; call again once they are released.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function restoreAssetCollateralFactor(address hub, address underlying) external;

  /// @notice Disables borrowing of an asset on every Spoke registered for that asset on a specified Hub.
  /// @dev Skips Spokes without a reserve for the asset. Re-enabling is done through
  /// `SpokeConfigurator.updateBorrowable`.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  function disableAssetBorrowing(address hub, address underlying) external;

  /// @notice Deactivates a position manager on each of the specified Spokes.
  /// @dev Re-activating is done through `SpokeConfigurator.updatePositionManager`.
  /// @param spokes The addresses of the Spokes.
  /// @param positionManager The address of the position manager.
  function deactivatePositionManager(address[] calldata spokes, address positionManager) external;

  /// @notice Returns the address of the SpokeConfigurator.
  /// @return The address of the SpokeConfigurator.
  function SPOKE_CONFIGURATOR() external view returns (address);
}
