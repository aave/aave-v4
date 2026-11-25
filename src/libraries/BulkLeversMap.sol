// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.20;

/// @title BulkLeversMap Library
/// @author Aave Labs
/// @notice Implements the bitmap logic that records which bulk emergency levers hold a flag, so each bulk
/// release only clears the flags that its own bulk brake set.
/// @dev Each bit marks one bulk lever. A flag that is already set while no bulk lever holds it, because it was
/// set manually or before any bulk brake, is never recorded, so no bulk release clears it.
library BulkLeversMap {
  /// @dev Mask for the asset-wide bulk levers, such as `haltAsset` and `freezeAsset`.
  uint8 internal constant ASSET_MASK = 0x01;
  /// @dev Mask for the Spoke-wide bulk levers, such as `haltSpoke`, `freezeSpoke` and `pauseAllReserves`.
  uint8 internal constant SPOKE_MASK = 0x02;

  /// @notice Returns the bulk levers holding a flag after a bulk brake.
  /// @dev A brake that sets the flag replaces the bitmap with its own mask, dropping bits left over from a flag
  /// that was cleared outside the configurator. A brake that finds the flag already set adds its mask only if
  /// another bulk lever already holds the flag.
  /// @param bulkLevers The bulk levers holding the flag before the brake.
  /// @param mask The mask of the bulk lever.
  /// @param flagUpdated True if the brake set the flag, false if the flag was already set.
  /// @return The bulk levers holding the flag after the brake.
  function brake(uint8 bulkLevers, uint8 mask, bool flagUpdated) internal pure returns (uint8) {
    if (flagUpdated) {
      return mask;
    }
    return bulkLevers == 0 ? 0 : bulkLevers | mask;
  }

  /// @notice Returns the bulk levers holding a flag after a bulk release, and whether to clear the flag.
  /// @dev The flag is cleared only if the releasing bulk lever held it and no other bulk lever still does.
  /// @param bulkLevers The bulk levers holding the flag before the release.
  /// @param mask The mask of the bulk lever.
  /// @return The bulk levers holding the flag after the release.
  /// @return True if the flag should be cleared.
  function release(uint8 bulkLevers, uint8 mask) internal pure returns (uint8, bool) {
    if (!isHeld(bulkLevers, mask)) {
      return (bulkLevers, false);
    }
    uint8 remaining = bulkLevers & ~mask;
    return (remaining, remaining == 0);
  }

  /// @notice Returns whether a bulk lever holds a flag.
  /// @param bulkLevers The bulk levers holding the flag.
  /// @param mask The mask of the bulk lever.
  /// @return True if the bulk lever holds the flag.
  function isHeld(uint8 bulkLevers, uint8 mask) internal pure returns (bool) {
    return (bulkLevers & mask) != 0;
  }
}
