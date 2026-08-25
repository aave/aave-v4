// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AddressesProvider} from 'src/addresses-provider/AddressesProvider.sol';

contract MockAddressesProviderInstance is AddressesProvider {
  bool public constant IS_TEST = true;

  uint64 public immutable ADDRESSES_PROVIDER_REVISION;

  /**
   * @dev Constructor.
   * @dev It sets the addresses provider revision and disables the initializers.
   * @param addressesProviderRevision_ The revision of the addresses provider contract.
   */
  constructor(uint64 addressesProviderRevision_) {
    ADDRESSES_PROVIDER_REVISION = addressesProviderRevision_;
    _disableInitializers();
  }

  /// @inheritdoc AddressesProvider
  function initialize(address owner) external override reinitializer(ADDRESSES_PROVIDER_REVISION) {
    __Ownable_init(owner);
    __Ownable2Step_init();
  }
}
