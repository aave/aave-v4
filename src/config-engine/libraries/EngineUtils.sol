// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAddressesProvider} from 'src/addresses-provider/interfaces/IAddressesProvider.sol';

/// @title EngineUtils
/// @author Aave Labs
/// @notice Library containing shared helpers for the AaveV4ConfigEngine libraries.
library EngineUtils {
  /// @dev Thrown when a Hub targeted by an engine action is not registered on the
  /// AddressesProvider as a canonical Hub.
  error HubNotRegistered(address hub);

  /// @dev Thrown when a Spoke targeted by an engine action is not registered on the
  /// AddressesProvider under a spoke tag.
  error SpokeNotRegistered(address spoke);

  /// @dev Thrown when a Spoke targeted by an engine action that only supports canonical Spokes is
  /// not registered on the AddressesProvider as a canonical Spoke.
  error CanonicalSpokeNotRegistered(address spoke);

  /// @dev Reverts unless the Hub is registered on the AddressesProvider as a canonical Hub.
  function requireRegisteredHub(IAddressesProvider addressesProvider, address hub) internal view {
    require(
      addressesProvider.isRegistered(hub, addressesProvider.CANONICAL_HUB_TAG()),
      HubNotRegistered(hub)
    );
  }

  /// @dev Reverts unless the Spoke is registered on the AddressesProvider under a spoke tag
  /// (canonical, tokenization or treasury). For flows supporting any spoke participant.
  function requireRegisteredSpoke(
    IAddressesProvider addressesProvider,
    address spoke
  ) internal view {
    require(
      addressesProvider.isRegistered(spoke, addressesProvider.CANONICAL_SPOKE_TAG()) ||
        addressesProvider.isRegistered(spoke, addressesProvider.TOKENIZATION_SPOKE_TAG()) ||
        addressesProvider.isRegistered(spoke, addressesProvider.TREASURY_SPOKE_TAG()),
      SpokeNotRegistered(spoke)
    );
  }

  /// @dev Reverts unless the Spoke is registered on the AddressesProvider as a canonical Spoke.
  /// For flows that only canonical Spokes support (reserves, liquidations, position managers).
  function requireRegisteredCanonicalSpoke(
    IAddressesProvider addressesProvider,
    address spoke
  ) internal view {
    require(
      addressesProvider.isRegistered(spoke, addressesProvider.CANONICAL_SPOKE_TAG()),
      CanonicalSpokeNotRegistered(spoke)
    );
  }
}
