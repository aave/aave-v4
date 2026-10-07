// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

/// @title TokenizationSpokeStorage
/// @author Aave Labs
/// @notice Storage layout for the TokenizationSpoke contract.
/// @dev This contract defines all storage variables used by the TokenizationSpoke.
abstract contract TokenizationSpokeStorage {
  /// @dev Address of the associated Hub.
  address internal _hub;

  /// @dev Decimals of the tokenized asset, shared by the vault share token.
  uint8 internal _decimals;

  /// @dev Maximum allowed spoke cap of the associated Hub.
  uint40 internal _maxAllowedSpokeCap;

  /// @dev Address of the tokenized asset.
  address internal _asset;

  /// @dev Identifier of the tokenized asset on the associated Hub.
  uint96 internal _assetId;

  /// @dev Reserved storage space to allow for future layout updates.
  uint256[48] private __gap;
}
