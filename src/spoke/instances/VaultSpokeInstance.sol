// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {VaultSpoke} from 'src/spoke/VaultSpoke.sol';
import {IERC20Metadata, IERC20} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';

/// @title VaultSpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the VaultSpoke.
contract VaultSpokeInstance is VaultSpoke {
  uint64 public constant SPOKE_REVISION = 1;

  /// @dev Constructor.
  /// @param hub_ The address of the hub.
  /// @param assetId_ The ID of the asset.
  constructor(address hub_, uint256 assetId_) VaultSpoke(hub_, assetId_) {
    _disableInitializers();
  }

  /// @notice Initializer.
  function initialize(string memory prefix) external override reinitializer(SPOKE_REVISION) {
    // todo: upgrade validation that hub/assetId remains unchanged?
    __VaultSpoke_init(prefix);
  }
}
