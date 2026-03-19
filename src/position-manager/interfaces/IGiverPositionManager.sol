// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

/// @title IGiverPositionManager
/// @author Aave Labs
/// @notice Interface for position manager handling supply and repay actions on behalf of users.
interface IGiverPositionManager is IPositionManagerBase {
  /// @notice Emitted when supplying on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param caller The transaction initiator, and supplier of the underlying asset.
  /// @param onBehalfOf The owner of the modified position.
  /// @param reserveId The identifier of the reserve.
  /// @param suppliedShares The amount of supply shares minted.
  /// @param suppliedAmount The amount of underlying asset supplied.
  event SupplyOnBehalfOf(
    address indexed spoke,
    address indexed caller,
    address indexed onBehalfOf,
    uint256 reserveId,
    uint256 suppliedShares,
    uint256 suppliedAmount
  );

  /// @notice Emitted when repaying on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param caller The transaction initiator who is repaying the underlying asset.
  /// @param onBehalfOf The owner of the position whose debt is being repaid.
  /// @param reserveId The identifier of the reserve.
  /// @param repaidShares The amount of debt shares burned.
  /// @param repaidAmount The amount of underlying asset repaid.
  event RepayOnBehalfOf(
    address indexed spoke,
    address indexed caller,
    address indexed onBehalfOf,
    uint256 reserveId,
    uint256 repaidShares,
    uint256 repaidAmount
  );

  /// @notice Error thrown when the repay amount is set to `type(uint256).max`, as it is not allowed.
  error RepayOnBehalfMaxUintNotAllowed();

  /// @notice Executes a supply on behalf of a user.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to supply.
  /// @param onBehalfOf The address of the user to supply on behalf of.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Executes a repay on behalf of a user.
  /// @dev If the amount exceeds the user's current debt, the entire debt is repaid.
  /// @dev Using `type(uint256).max` to repay the full debt is not allowed with this method.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to repay.
  /// @param onBehalfOf The address of the user to repay on behalf of.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repayOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);
}
