// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {FlashLoanSpoke} from 'src/spoke/FlashLoanSpoke.sol';

/// @title FlashLoanSpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the FlashLoanSpoke.
contract FlashLoanSpokeInstance is FlashLoanSpoke {
  uint64 public constant SPOKE_REVISION = 1;

  /// @dev Constructor.
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority The address of the authority contract which manages permissions.
  /// @param hub The address of the associated Hub.
  function initialize(
    address authority,
    address hub
  ) external override reinitializer(SPOKE_REVISION) {
    require(authority != address(0) && hub != address(0), InvalidAddress());
    __AccessManaged_init(authority);
    _hub = IHubBase(hub);
    emit UpdateHub(hub);
  }
}
