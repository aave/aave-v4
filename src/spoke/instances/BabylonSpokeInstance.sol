// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {BabylonSpoke} from 'src/spoke/BabylonSpoke.sol';

/// @title BabylonSpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the BabylonSpoke.
contract BabylonSpokeInstance is BabylonSpoke {
  uint64 public constant SPOKE_REVISION = 1;

  /// @dev Constructor.
  /// @dev During upgrade, must ensure that the new oracle is supporting existing assets on the Spoke and the replaced oracle.
  /// @param oracle_ The address of the oracle.
  constructor(address oracle_) BabylonSpoke(oracle_) {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority The address of the authority contract which manages permissions.
  function initialize(address authority) external override reinitializer(SPOKE_REVISION) {
    emit SetSpokeImmutables(ORACLE, MAX_USER_RESERVES_LIMIT);

    require(authority != address(0), InvalidAddress());
    __AccessManaged_init(authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }
  }
}
