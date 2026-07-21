// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title EngineUtils
/// @author Aave Labs
/// @notice Library containing shared helpers for the AaveV4ConfigEngine libraries.
library EngineUtils {
  /// @dev Returns whether an optional AddressesProvider registration is consistent: all fields must
  /// be set when registering, and left unset otherwise.
  function isConsistentRegistration(
    IAaveV4ConfigEngine.AddressesProviderRegistration calldata registration
  ) internal pure returns (bool) {
    return
      registration.register
        ? address(registration.addressesProvider) != address(0) &&
          bytes(registration.name).length > 0
        : address(registration.addressesProvider) == address(0) &&
          bytes(registration.name).length == 0;
  }
}
