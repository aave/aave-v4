// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title IBabylonSpoke
/// @author Aave Labs
/// @notice Full interface for the BabylonSpoke.
interface IBabylonSpoke is ISpoke {
  /// @notice Emitted when the immutable variables specific to the BabylonSpoke are set.
  /// @param liquidationManager The only address allowed to perform liquidations on this Spoke.
  /// @param managedCollateralReserveId The identifier of the only reserve usable as collateral.
  event SetBabylonSpokeImmutables(address liquidationManager, uint256 managedCollateralReserveId);

  /// @dev Emitted when a borrower is liquidated.
  /// @param collateralReserveId The identifier of the managed collateral reserve removed by the liquidation.
  /// @param debtReserveId The identifier of the repaid debt reserve.
  /// @param user The address of the borrower getting liquidated.
  /// @param liquidator The address of the liquidator.
  /// @param debtAmountRestored The amount of debt restored, expressed in asset units.
  /// @param drawnSharesLiquidated The amount of drawn shares liquidated.
  /// @param premiumDelta A struct representing the changes to premium debt after liquidation.
  /// @param collateralAmountRemoved The amount of collateral removed, expressed in asset units.
  /// @param collateralSharesLiquidated The amount of collateral shares liquidated.
  event BabylonLiquidationCall(
    uint256 indexed collateralReserveId,
    uint256 indexed debtReserveId,
    address indexed user,
    address liquidator,
    uint256 debtAmountRestored,
    uint256 drawnSharesLiquidated,
    IHubBase.PremiumDelta premiumDelta,
    uint256 collateralAmountRemoved,
    uint256 collateralSharesLiquidated
  );

  /// @notice Thrown when the disabled canonical liquidation entry point is called.
  error UnsupportedLiquidationCall();

  /// @notice Thrown when registering a reserve other than the managed collateral reserve as collateral.
  error UnsupportedCollateralReserve();

  /// @notice Thrown when a reserve is configured with a non-zero liquidation fee.
  error UnsupportedLiquidationFee();

  /// @notice Thrown when the managed collateral reserve is configured as borrowable.
  error UnsupportedBorrowableCollateral();

  /// @notice Liquidates a user position, bounded by a collateral removal cap.
  /// @dev It reverts if the caller is not the liquidation manager.
  /// @dev It reverts if the debt reserve or the managed collateral reserve is not listed.
  /// @dev The Spoke pulls underlying repaid debt assets from caller (Liquidator), hence it needs prior approval.
  /// @dev The repayment covers premium debt first, up to the desired cover and the user's debt, with no target health factor sizing.
  /// @dev The removed collateral is priced with the canonical bonus formula. If it exceeds the removal cap, the repayment is resized to exactly consume the cap.
  /// @dev No dust validation and no liquidation fee are applied, and the liquidator receives the removed collateral in underlying assets.
  /// @param debtReserveId The reserveId of the underlying asset borrowed by the liquidated user.
  /// @param debtToCover The desired amount of debt to cover.
  /// @param user The address of the user to liquidate.
  /// @param maxCollateralToRemove The maximum amount of collateral to remove from the user, expressed in asset units.
  /// @return liquidationBonus The liquidation bonus applied, expressed in BPS.
  /// @return collateralAmountRemoved The amount of collateral removed, expressed in asset units.
  function liquidationCall(
    uint256 debtReserveId,
    uint256 debtToCover,
    address user,
    uint256 maxCollateralToRemove
  ) external returns (uint256 liquidationBonus, uint256 collateralAmountRemoved);

  /// @notice Returns the only address allowed to perform liquidations on this Spoke.
  function LIQUIDATION_MANAGER() external view returns (address);

  /// @notice Returns the identifier of the only reserve usable as collateral.
  function MANAGED_COLLATERAL_RESERVE_ID() external view returns (uint256);
}
