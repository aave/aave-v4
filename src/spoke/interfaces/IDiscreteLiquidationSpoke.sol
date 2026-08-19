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

  /// @dev Emitted when a borrower is liquidated via a discrete liquidation.
  /// @param collateralReserveId The identifier of the reserve used as collateral, to receive as a result of the liquidation.
  /// @param debtReserveId The identifier of the reserve to be repaid with the liquidation.
  /// @param user The address of the borrower getting liquidated.
  /// @param liquidator The address of the liquidator.
  /// @param debtAmountRestored The amount of debt restored, expressed in asset units.
  /// @param drawnSharesLiquidated The amount of drawn shares liquidated.
  /// @param premiumDelta A struct representing the changes to premium debt after liquidation.
  /// @param collateralAmountRemoved The amount of collateral removed, expressed in asset units.
  /// @param collateralSharesLiquidated The total amount of collateral shares liquidated.
  /// @param collateralSharesToLiquidator The amount of collateral shares that the liquidator received.
  event DiscreteLiquidationCall(
    uint256 indexed collateralReserveId,
    uint256 indexed debtReserveId,
    address indexed user,
    address liquidator,
    uint256 debtAmountRestored,
    uint256 drawnSharesLiquidated,
    IHubBase.PremiumDelta premiumDelta,
    uint256 collateralAmountRemoved,
    uint256 collateralSharesLiquidated,
    uint256 collateralSharesToLiquidator
  );

  /// @notice Thrown when a max collateral to receive input is zero.
  error InvalidMaxCollateralToReceive();

  /// @notice Updates the liquidation manager.
  /// @param liquidationManager The address of the new liquidation manager.
  function updateLiquidationManager(address liquidationManager) external;

  /// @notice Liquidates a user position with discrete sizing.
  /// @dev Caller must be the configured liquidation manager.
  /// @dev The Spoke pulls underlying repaid debt assets from the caller, hence it needs prior approval.
  /// @dev Repays up to `debtToCover`, capped at the user's full debt in the reserve, with no target
  /// health factor sizing. The seized collateral is computed with the canonical bonus formula and then
  /// capped at `maxCollateralToReceive` and at the user's collateral balance; any computed seizure
  /// beyond the caps is simply not taken, while the repayment stands.
  /// @dev No dust validation is performed on the remaining collateral and debt balances.
  /// @dev The liquidator always receives collateral in underlying assets, never in supplied shares.
  /// @param collateralReserveId The reserveId of the underlying asset used as collateral by the liquidated user.
  /// @param debtReserveId The reserveId of the underlying asset borrowed by the liquidated user, to be repaid by the caller.
  /// @param user The address of the user to liquidate.
  /// @param debtToCover The desired amount of debt to cover.
  /// @param maxCollateralToReceive The maximum amount of collateral to seize, expressed in asset units.
  function discreteLiquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256 maxCollateralToReceive
  ) external;

  /// @notice Returns the address of the liquidation manager.
  function getLiquidationManager() external view returns (address);
}
