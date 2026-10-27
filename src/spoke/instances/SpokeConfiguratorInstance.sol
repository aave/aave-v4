// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';

/// @title SpokeConfiguratorInstance
/// @author Aave Labs
/// @notice Implementation contract for the SpokeConfigurator.
contract SpokeConfiguratorInstance is SpokeConfigurator {
  uint64 public constant SPOKE_CONFIGURATOR_REVISION = 1;

  /// @dev Constructor.
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority The address of the authority contract which manages permissions.
  function initialize(
    address authority
  ) external override reinitializer(SPOKE_CONFIGURATOR_REVISION) {
    require(authority != address(0), InvalidAddress());
    __AccessManaged_init(authority);
  }
}
