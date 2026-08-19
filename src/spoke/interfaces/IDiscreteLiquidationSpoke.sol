// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title IDiscreteLiquidationSpoke
/// @author Aave Labs
/// @notice Full interface for the DiscreteLiquidationSpoke.
interface IDiscreteLiquidationSpoke is ISpoke {
  /// @notice Emitted when the liquidation manager is updated.
  /// @param liquidationManager The address of the new liquidation manager.
  event UpdateLiquidationManager(address indexed liquidationManager);

  /// @dev Emitted for each debt reserve repaid during a discrete liquidation.
  /// @param debtReserveId The identifier of the repaid debt reserve.
  /// @param user The address of the borrower getting liquidated.
  /// @param debtAmountRestored The amount of debt restored, expressed in asset units.
  /// @param drawnSharesLiquidated The amount of drawn shares liquidated.
  /// @param premiumDelta A struct representing the changes to premium debt after liquidation.
  event DiscreteLiquidationRepay(
    uint256 indexed debtReserveId,
    address indexed user,
    uint256 debtAmountRestored,
    uint256 drawnSharesLiquidated,
    IHubBase.PremiumDelta premiumDelta
  );

  /// @dev Emitted when a borrower is liquidated via a discrete liquidation.
  /// @param collateralReserveId The identifier of the reserve used as collateral, to receive as a result of the liquidation.
  /// @param user The address of the borrower getting liquidated.
  /// @param liquidator The address of the liquidator.
  /// @param collateralAmountRemoved The amount of collateral removed, expressed in asset units.
  /// @param collateralSharesLiquidated The total amount of collateral shares liquidated.
  /// @param collateralSharesToLiquidator The amount of collateral shares that the liquidator received.
  event DiscreteLiquidationCall(
    uint256 indexed collateralReserveId,
    address indexed user,
    address indexed liquidator,
    uint256 collateralAmountRemoved,
    uint256 collateralSharesLiquidated,
    uint256 collateralSharesToLiquidator
  );

  /// @notice Thrown when a max collateral to receive input is zero.
  error InvalidMaxCollateralToReceive();

  /// @notice Thrown when the debt reserve and amount arrays are empty or of different lengths.
  error InvalidLiquidationCallArguments();

  /// @notice Updates the liquidation manager.
  /// @param liquidationManager The address of the new liquidation manager.
  function updateLiquidationManager(address liquidationManager) external;

  /// @notice Liquidates a user position with discrete sizing.
  /// @dev Caller must be the configured liquidation manager.
  /// @dev The Spoke pulls underlying repaid debt assets from the caller, hence it needs prior approval.
  /// @dev The health factor is validated once at entry, not per debt reserve: with multiple debt
  /// reserves, an intermediate repayment can restore the health factor above the threshold while the
  /// seizure cap is not yet reached, and repayment must be able to continue so the seizure can be
  /// completed. Over-liquidation is bounded by `maxCollateralToReceive` and by the liquidation
  /// manager restriction.
  /// @dev For each debt reserve, repays up to the given amount, capped at the user's full debt in
  /// that reserve, with no target health factor sizing. The seized collateral is priced with the
  /// canonical bonus formula (from the entry health factor) and accumulated across reserves, capped
  /// at `maxCollateralToReceive` and at the user's collateral balance; when the cap binds, the final
  /// repayment is resized to exactly consume it and the loop stops early, leaving later debt
  /// reserves untouched.
  /// @dev No dust validation is performed on the remaining collateral and debt balances.
  /// @dev The liquidator always receives collateral in underlying assets, never in supplied shares.
  /// @param collateralReserveId The reserveId of the underlying asset used as collateral by the liquidated user.
  /// @param debtReserveIds The reserveIds of the underlying assets borrowed by the liquidated user, in repayment order.
  /// @param debtAmounts The desired amount of debt to cover per debt reserve.
  /// @param user The address of the user to liquidate.
  /// @param maxCollateralToReceive The maximum total amount of collateral to seize, expressed in asset units.
  function discreteLiquidationCall(
    uint256 collateralReserveId,
    uint256[] calldata debtReserveIds,
    uint256[] calldata debtAmounts,
    address user,
    uint256 maxCollateralToReceive
  ) external;

  /// @notice Returns the address of the liquidation manager.
  function getLiquidationManager() external view returns (address);
}
