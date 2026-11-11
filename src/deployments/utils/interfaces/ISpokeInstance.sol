// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title ISpokeInstance
/// @author Aave Labs
/// @notice Spoke instance interface exposing the initializer and revision.
interface ISpokeInstance is ISpoke {
  /// @notice Initializes the Spoke instance with the given authority, oracle and max user reserves limit.
  /// @param _authority The address of the access-control authority contract.
  /// @param _oracle The address of the AaveOracle contract.
  /// @param _maxUserReservesLimit The maximum number of collateral and borrow reserves a user can have.
  function initialize(address _authority, address _oracle, uint16 _maxUserReservesLimit) external;

  /// @notice Returns the revision number of this Spoke implementation.
  function SPOKE_REVISION() external view returns (uint64);
}
