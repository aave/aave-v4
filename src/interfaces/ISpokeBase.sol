// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title ISpokeBase
 * @author Aave Labs
 * @notice Minimal interface for Spoke
 */
interface ISpokeBase {
  /**
   * @notice Emitted on the supply action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator, and supplier of the underlying asset.
   * @param user The owner of the modified position.
   * @param suppliedShares The amount of supply shares minted.
   */
  event Supply(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 suppliedShares
  );

  /**
   * @notice Emitted on the withdraw action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator, and recipient of the underlying asset being withdrawn.
   * @param user The owner of the modified position.
   * @param suppliedShares The amount of supply shares burned.
   */
  event Withdraw(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 suppliedShares
  );

  /**
   * @notice Emitted on the borrow action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator, and recipient of the underlying asset being borrowed.
   * @param user The owner of the position on which debt is generated.
   * @param drawnShares The amount of debt shares minted.
   */
  event Borrow(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 drawnShares
  );

  /**
   * @notice Emitted on the repay action.
   * @param reserveId The reserve identifier of the underlying asset as registered on the spoke.
   * @param caller The transaction initiator, and supplier of the underlying asset being repaid.
   * @param user The owner of the position whose debt is being repaid.
   * @param drawnShares The amount of debt shares burned.
   * @param premiumDelta A struct representing the changes to premium debt after repayment.
   */
  event Repay(
    uint256 indexed reserveId,
    address indexed caller,
    address indexed user,
    uint256 drawnShares,
    DataTypes.PremiumDelta premiumDelta
  );

  /**
   * @dev Emitted when a borrower is liquidated.
   * @param collateralAssetId The identifier of the asset used as collateral, to receive as result of the liquidation.
   * @param debtAssetId The identifier of the asset to be repaid with the liquidation.
   * @param user The address of the borrower getting liquidated.
   * @param liquidatedDebt The debt amount of borrowed asset to be liquidated.
   * @param liquidatedCollateral The amount of collateral received by the liquidator.
   * @param liquidator The address of the liquidator.
   */
  event LiquidationCall(
    uint256 indexed collateralAssetId,
    uint256 indexed debtAssetId,
    address indexed user,
    uint256 liquidatedDebt,
    uint256 liquidatedCollateral,
    address liquidator
  );

  /**
   * @notice Supply an amount of underlying asset of the specified reserve.
   * @dev The Liquidity Hub pulls the underlying asset from the caller, so prior token approval is required.
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @param reserveId The reserve identifier.
   * @param amount The amount of asset to supply.
   * @param onBehalfOf The owner of position to add supply shares to.
   */
  function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Withdraws a specified amount of underlying asset from the given reserve.
   * @dev Providing an amount greater than the maximum withdrawable value signals a full withdrawal.
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @dev Caller receives the underlying asset withdrawn.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to withdraw.
   * @param onBehalfOf The owner of position to remove supply shares from.
   */
  function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Borrows a specified amount of underlying asset from the given reserve
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @dev Caller receives the underlying asset borrowed.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to borrow.
   * @param onBehalfOf The owner of the position against which debt is generated.
   */
  function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Repays a specified amount of underlying asset to a given reserve.
   * @dev The Liquidity Hub pulls the underlying asset from the caller, so prior approval is required.
   * @dev Caller must be `onBehalfOf` or an authorized position manager for `onBehalfOf`.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to repay.
   * @param onBehalfOf The owner of the position whose debt is repaid.
   */
  function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external;

  /**
   * @notice Liquidates a user position.
   * @dev Invokes Liquidity Hub restore, and pulls underlying repaid debt asset from caller (Liquidator), hence it needs prior approval.
   * @param collateralReserveId The reserveId of the underlying asset used as collateral by the liquidated user.
   * @param debtReserveId The reserveId of the underlying asset borrowed by the liquidated user, to be repaid by Liquidator during liquidation.
   * @param user The address of the user to liquidate.
   * @param debtToCover The amount of debt to cover.
   */
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external;

  /**
   * @notice Returns the debt of a specific user for a given reserve.
   * @dev The total debt of the user is the sum of drawn debt and premium debt.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The amount of drawn debt.
   * @return The amount of premium debt.
   */
  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);

  /**
   * @notice Returns the total debt of a specific user for a given reserve.
   * @dev The total debt of the user is the sum of drawn debt and premium debt.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The total debt amount.
   */
  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);

  /**
   * @notice Returns the total amount of supplied assets of a given reserve.
   * @param reserveId The identifier of the reserve.
   * @return The amount of supplied assets.
   */
  function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the total amount of supplied shares of a given reserve.
   * @param reserveId The identifier of the reserve.
   * @return The amount of supplied shares.
   */
  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256);

  /**
   * @notice Returns the amount of assets supplied by a specific user for a given reserve.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The amount of assets supplied by the user.
   */
  function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);

  /**
   * @notice Returns the amount of shares supplied by a specific user for a given reserve.
   * @param reserveId The identifier of the reserve.
   * @param user The address of the user.
   * @return The amount of shares supplied by the user.
   */
  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256);

  /**
   * @notice Returns the debt of a given reserve.
   * @dev The total debt of the reserve is the sum of drawn debt and premium debt.
   * @param reserveId The identifier of the reserve.
   * @return The amount of drawn debt.
   * @return The amount of premium debt.
   */
  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);

  /**
   * @notice Returns the total debt of a given reserve.
   * @dev The total debt of the reserve is the sum of drawn debt and premium debt.
   * @param reserveId The identifier of the reserve.
   * @return The total debt amount.
   */
  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256);
}
