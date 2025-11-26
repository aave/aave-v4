// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title IVaultSpoke
/// @author Aave Labs
interface IVaultSpoke {
  /// @notice Thrown when the given address is invalid.
  error InvalidAddress();

  /// @notice Returns the address of the associated Hub.
  function HUB() external view returns (IHub);

  /// @notice Returns the identifier of the associated asset.
  function ASSET_ID() external view returns (uint256);
}
