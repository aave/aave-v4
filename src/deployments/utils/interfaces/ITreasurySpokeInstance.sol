// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';

/// @title ITreasurySpokeInstance
/// @author Aave Labs
/// @notice TreasurySpoke instance interface exposing the initializer, owner and revision.
interface ITreasurySpokeInstance is ITreasurySpoke {
  /// @notice Initializes the TreasurySpoke instance with the given owner.
  /// @param owner The address of the owner.
  function initialize(address owner) external;

  /// @notice Returns the owner of the TreasurySpoke.
  function owner() external view returns (address);

  /// @notice Returns the revision number of this TreasurySpoke implementation.
  function SPOKE_REVISION() external view returns (uint64);
}
