// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title SpokeStorage
/// @author Aave Labs
/// @notice Storage layout for the Spoke contract.
/// @dev This contract defines all storage variables used by Spoke.
abstract contract SpokeStorage {
  struct Data {
    /// @dev Number of reserves listed in the Spoke.
    uint256 reserveCount;
    /// @dev Liquidation configuration for the Spoke.
    ISpoke.LiquidationConfig liquidationConfig;
    /// @dev Map of reserve identifiers to their Reserve data.
    mapping(uint256 reserveId => ISpoke.Reserve) reserves;
    /// @dev Map of hub addresses and asset identifiers to whether the reserve exists.
    mapping(address hub => mapping(uint256 assetId => bool)) reserveExists;
    /// @dev Map of reserve identifiers and dynamic configuration keys to the dynamic configuration data.
    mapping(uint256 reserveId => mapping(uint24 dynamicConfigKey => ISpoke.DynamicReserveConfig)) dynamicConfig;
    /// @dev Map of user addresses to their position status.
    mapping(address user => ISpoke.PositionStatus) positionStatus;
    /// @dev Map of user addresses and reserve identifiers to user positions.
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) userPositions;
    /// @dev Map of position manager addresses to their configuration data.
    mapping(address positionManager => ISpoke.PositionManagerConfig) positionManager;
  }

  Data internal _storage;

  /// @dev Reserved storage space to allow for future layout updates.
  uint256[50] private __gap;
}
