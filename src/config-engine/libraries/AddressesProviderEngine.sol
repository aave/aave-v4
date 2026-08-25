// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAddressesProvider} from 'src/addresses-provider/interfaces/IAddressesProvider.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title AddressesProviderEngine
/// @author Aave Labs
/// @notice Library containing AddressesProvider logic for AaveV4ConfigEngine.
library AddressesProviderEngine {
  /// @notice Updates entries on the AddressesProvider.
  /// @param updates The entry updates to execute.
  /// @param addressesProvider The AddressesProvider to update.
  function executeAddressesProviderEntryUpdates(
    IAaveV4ConfigEngine.AddressesProviderEntryUpdate[] calldata updates,
    IAddressesProvider addressesProvider
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      addressesProvider.setEntry(updates[i].name, updates[i].tag, updates[i].addr);
    }
  }
}
