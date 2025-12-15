// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {VaultSpoke} from 'src/spoke/VaultSpoke.sol';

contract MockVaultSpokeInstance is VaultSpoke {
  bool public constant IS_TEST = true;

  uint64 public immutable SPOKE_REVISION;

  /**
   * @dev Constructor.
   * @dev It sets the vault spoke revision and disables the initializers.
   * @param spokeRevision_ The revision of the vault spoke contract.
   * @param hub_ The address of the hub.
   * @param assetId_ The ID of the asset.
   */
  constructor(uint64 spokeRevision_, address hub_, uint256 assetId_) VaultSpoke(hub_, assetId_) {
    SPOKE_REVISION = spokeRevision_;
    _disableInitializers();
  }

  /// @inheritdoc VaultSpoke
  function initialize(
    string memory shareName,
    string memory shareSymbol
  ) external override reinitializer(SPOKE_REVISION) {
    __VaultSpoke_init(shareName, shareSymbol);
  }
}
