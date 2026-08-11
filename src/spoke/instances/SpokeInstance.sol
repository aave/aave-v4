// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeInstanceBase} from 'src/spoke/instances/SpokeInstanceBase.sol';

/// @title SpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the Spoke.
contract SpokeInstance is SpokeInstanceBase {
  /// @dev Constructor.
  /// @param oracle_ The address of the oracle.
  /// @param maxUserReservesLimit_ The maximum number of collateral and borrow reserves a user can have.
  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_
  ) SpokeInstanceBase(oracle_, maxUserReservesLimit_) {}
}
