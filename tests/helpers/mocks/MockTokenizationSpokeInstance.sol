// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TokenizationSpoke} from 'src/spoke/TokenizationSpoke.sol';

contract MockTokenizationSpokeInstance is TokenizationSpoke {
  bool public constant IS_TEST = true;

  uint64 public immutable SPOKE_REVISION;

  /**
   * @dev Constructor.
   * @dev It sets the vault spoke revision and disables the initializers.
   * @param spokeRevision_ The revision of the vault spoke contract.
   */
  constructor(uint64 spokeRevision_) {
    SPOKE_REVISION = spokeRevision_;
    _disableInitializers();
  }

  /// @inheritdoc TokenizationSpoke
  function initialize(
    address hub_,
    address underlying_,
    string memory shareName,
    string memory shareSymbol
  ) external override reinitializer(SPOKE_REVISION) {
    __TokenizationSpoke_init(hub_, underlying_, shareName, shareSymbol);

    emit SetTokenizationSpokeImmutables(address(_hub), _assetId);
  }
}
