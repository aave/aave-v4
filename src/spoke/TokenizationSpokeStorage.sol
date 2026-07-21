// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title TokenizationSpokeStorage
/// @author Aave Labs
/// @notice Storage layout for the TokenizationSpoke contract.
/// @dev This contract defines all storage variables used by TokenizationSpoke.
abstract contract TokenizationSpokeStorage {
  /// @dev The associated Hub contract.
  IHub internal _hub;

  /// @dev The identifier of the tokenized asset on the Hub.
  uint256 internal _assetId; // todo: change to 96 to save an sload, prob ok limitation

  /// @dev The address of the underlying asset to be tokenized.
  address internal _asset;

  /// @dev The decimals of the share token, mirroring the underlying asset decimals.
  uint8 internal _decimals;

  /// @dev Reserved storage space to allow for future layout updates.
  uint256[50] private __gap;
}
