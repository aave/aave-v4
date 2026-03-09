// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {TokenizationSpoke} from 'src/spoke/TokenizationSpoke.sol';

/// @title TokenizationSpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the TokenizationSpoke.
contract TokenizationSpokeInstance is TokenizationSpoke {
  uint64 public constant SPOKE_REVISION = 1;

  /// @dev Constructor.
  /// @param hub_ The address of the associated Hub.
  /// @param underlying_ The address of the underlying asset to be tokenized.
  constructor(address hub_, address underlying_) TokenizationSpoke(hub_, underlying_) {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @param shareName The ERC20 name of the share issued by this vault.
  /// @param shareSymbol The ERC20 symbol of the share issued by this vault.
  function initialize(
    string memory shareName,
    string memory shareSymbol
  ) external override reinitializer(SPOKE_REVISION) {
    __TokenizationSpoke_init(shareName, shareSymbol);
  }
}
