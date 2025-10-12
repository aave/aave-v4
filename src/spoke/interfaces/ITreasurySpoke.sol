// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';

/// @title ITreasurySpoke
/// @author Aave Labs
/// @notice Interface for the TreasurySpoke.
interface ITreasurySpoke is ISpokeBase {
  /// @notice Thrown when an unsupported action is attempted.
  error UnsupportedAction();

  /// @notice Thrown when the given address is invalid.
  error InvalidAddress();

  /// @notice Supplies a specified amount of the underlying asset to a given reserve.
  /// @dev The hub pulls the underlying asset from the caller, so prior approval is required.
  /// @dev The reserve identifier must match the asset identifier in the hub.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of asset to supply.
  /// @param onBehalfOf Unused parameter for this spoke.
  function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /// @notice Withdraws a specified amount of underlying asset from the given reserve.
  /// @dev Providing an amount greater than the maximum withdrawable value signals a full withdrawal.
  /// @dev The reserve identifier must match the asset identifier in the hub.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of asset to withdraw.
  /// @param onBehalfOf Unused parameter for this spoke.
  function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /// @notice Transfers a specified amount of ERC20 tokens from this contract.
  /// @param token The address of the ERC20 token to transfer.
  /// @param to The recipient address.
  /// @param amount The amount of tokens to transfer.
  function transfer(address token, address to, uint256 amount) external;

  /// @notice Returns the amount of assets supplied.
  /// @dev The reserve identifier must match the asset identifier in the hub.
  /// @param reserveId The identifier of the reserve.
  /// @return The amount of assets supplied.
  function getSuppliedAmount(uint256 reserveId) external view returns (uint256);

  /// @notice Returns the amount of shares supplied.
  /// @dev Shares are denominated relative to the supply side.
  /// @dev The reserve identifier must match the asset identifier in the hub.
  /// @param reserveId The identifier of the reserve.
  /// @return The amount of shares supplied.
  function getSuppliedShares(uint256 reserveId) external view returns (uint256);

  /// @notice Returns the interface of the associated hub.
  /// @return The HubBase interface.
  function HUB() external view returns (IHubBase);
}
