// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';

/// @title ISpokeBase
/// @author Aave Labs
/// @notice Minimal interface for Spoke.
interface ISpokeBase {
  /// @notice Emitted on the supply action.
  /// @param reserveId The reserve identifier of the underlying asset.
  /// @param caller The transaction initiator, and supplier of the underlying asset.
  /// @param user The owner of the modified position.
  /// @param suppliedShares The amount of supply shares minted.
  /// @param suppliedAmount The amount of underlying asset supplied.
  event Supply(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 suppliedShares,
    uint256 suppliedAmount
  );

  /// @notice Emitted on the withdraw action.
  /// @param reserveId The reserve identifier of the underlying asset.
  /// @param caller The transaction initiator, and recipient of the underlying asset being withdrawn.
  /// @param user The owner of the modified position.
  /// @param withdrawnShares The amount of supply shares burned.
  /// @param withdrawnAmount The amount of underlying asset withdrawn.
  event Withdraw(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 withdrawnShares,
    uint256 withdrawnAmount
  );

  /// @notice Emitted on the borrow action.
  /// @param reserveId The reserve identifier of the underlying asset.
  /// @param caller The transaction initiator, and recipient of the underlying asset being borrowed.
  /// @param user The owner of the position on which debt is generated.
  /// @param drawnShares The amount of debt shares minted.
  /// @param drawnAmount The amount of underlying asset borrowed.
  event Borrow(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 drawnShares,
    uint256 drawnAmount
  );

  /// @notice Emitted on the repay action.
  /// @param reserveId The reserve identifier of the underlying asset.
  /// @param caller The transaction initiator who is repaying the underlying asset.
  /// @param user The owner of the position whose debt is being repaid.
  /// @param drawnShares The amount of drawn shares burned.
  /// @param totalAmountRepaid The amount of drawn and premium underlying assets repaid.
  /// @param premiumDelta A struct representing the changes to premium debt after repayment.
  event Repay(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 drawnShares,
    uint256 totalAmountRepaid,
    IHubBase.PremiumDelta premiumDelta
  );

  /// @dev Emitted when a borrower is liquidated.
  /// @param collateralReserveId The identifier of the reserve used as collateral, to receive as a result of the liquidation.
  /// @param debtReserveId The identifier of the reserve to be repaid with the liquidation.
  /// @param user The address of the borrower getting liquidated.
  /// @param debtToLiquidate The debt amount of borrowed reserve to be liquidated.
  /// @param collateralToLiquidate The total amount of collateral asset to be liquidated, inclusive of liquidation fee.
  /// @param liquidator The address of the liquidator.
  /// @param receiveShares True if the liquidator receives collateral in supplied shares rather than underlying assets.
  event LiquidationCall(
    uint256 indexed collateralReserveId,
    uint256 indexed debtReserveId,
    address indexed user,
    uint256 debtToLiquidate,
    uint256 collateralToLiquidate,
    address liquidator,
    bool receiveShares
  );

  /// @notice Supplies an amount of underlying asset of the specified reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev The Spoke pulls the underlying asset from the caller, so prior token approval is required.
  /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
  /// @param reserveId The reserve identifier.
  /// @param amount The amount of asset to supply.
  /// @param onBehalfOf The owner of the position to add supply shares to.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supply(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Withdraws a specified amount of underlying asset from the given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Providing an amount greater than the maximum withdrawable value signals a full withdrawal.
  /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
  /// @dev Caller receives the underlying asset withdrawn.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of asset to withdraw.
  /// @param onBehalfOf The owner of position to remove supply shares from.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdraw(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Borrows a specified amount of underlying asset from the given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
  /// @dev Caller receives the underlying asset borrowed.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of asset to borrow.
  /// @param onBehalfOf The owner of the position against which debt is generated.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Repays a specified amount of underlying asset to a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev The Spoke pulls the underlying asset from the caller, so prior approval is required.
  /// @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of asset to repay.
  /// @param onBehalfOf The owner of the position whose debt is repaid.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repay(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Liquidates a user position.
  /// @dev It reverts if the reserves associated with any of the given reserve identifiers are not listed.
  /// @dev The Spoke pulls underlying repaid debt assets from caller (Liquidator), hence it needs prior approval.
  /// @param collateralReserveId The reserveId of the underlying asset used as collateral by the liquidated user.
  /// @param debtReserveId The reserveId of the underlying asset borrowed by the liquidated user, to be repaid by Liquidator.
  /// @param user The address of the user to liquidate.
  /// @param debtToCover The desired amount of debt to cover.
  /// @param receiveShares True to receive collateral in supplied shares, false to receive in underlying assets.
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) external;

  /// @notice Returns the total amount of supplied assets of a given reserve.
  /// @param reserveId The identifier of the reserve.
  /// @return The amount of supplied assets.
  function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256);

  /// @notice Returns the total amount of supplied shares of a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @return The amount of supplied shares.
  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256);

  /// @notice Returns the debt of a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev The total debt of the reserve is the sum of drawn debt and premium debt.
  /// @param reserveId The identifier of the reserve.
  /// @return The amount of drawn debt.
  /// @return The amount of premium debt.
  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);

  /// @notice Returns the total debt of a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev The total debt of the reserve is the sum of drawn debt and premium debt.
  /// @param reserveId The identifier of the reserve.
  /// @return The total debt amount.
  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256);

  /// @notice Returns the amount of assets supplied by a specific user for a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @return The amount of assets supplied by the user.
  function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);

  /// @notice Returns the amount of shares supplied by a specific user for a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @return The amount of shares supplied by the user.
  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256);

  /// @notice Returns the debt of a specific user for a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev The total debt of the user is the sum of drawn debt and premium debt.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @return The amount of drawn debt.
  /// @return The amount of premium debt.
  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);

  /// @notice Returns the total debt of a specific user for a given reserve.
  /// @dev It reverts if the reserve associated with the given reserve identifier is not listed.
  /// @dev The total debt of the user is the sum of drawn debt and premium debt.
  /// @param reserveId The identifier of the reserve.
  /// @param user The address of the user.
  /// @return The total debt amount.
  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);
}
