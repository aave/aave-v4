// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {TokenizationSpoke} from 'src/spoke/TokenizationSpoke.sol';

/// @title TokenizationSpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the TokenizationSpoke.
contract TokenizationSpokeInstance is TokenizationSpoke {
  uint64 public constant SPOKE_REVISION = 2;

  /// @dev Constructor.
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @param hub The address of the associated Hub.
  /// @param underlying The address of the underlying asset to be tokenized.
  /// @param shareName The ERC20 name of the share issued by this vault.
  /// @param shareSymbol The ERC20 symbol of the share issued by this vault.
  function initialize(
    address hub,
    address underlying,
    string memory shareName,
    string memory shareSymbol
  ) external override reinitializer(SPOKE_REVISION) {
    __TokenizationSpoke_init(hub, underlying, shareName, shareSymbol);
  }
}
