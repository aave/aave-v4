// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title IBabylonSpoke
/// @author Aave Labs
/// @notice Full interface for the BabylonSpoke.
interface IBabylonSpoke is ISpoke {
  /// @dev liquidationManager The only address allowed to perform liquidations on this Spoke.
  /// @dev managedCollateralReserveId The identifier of the only reserve usable as collateral.
  /// @custom:storage-location erc7201:aave-v4.storage.BabylonSpoke
  struct BabylonSpokeStorage {
    address liquidationManager;
    uint96 managedCollateralReserveId;
  }

  /// @notice Emitted when the Babylon liquidation config is updated.
  /// @param liquidationManager The only address allowed to perform liquidations on this Spoke.
  /// @param managedCollateralReserveId The identifier of the only reserve usable as collateral.
  event UpdateBabylonLiquidationConfig(
    address liquidationManager,
    uint256 managedCollateralReserveId
  );

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

  /// @notice Thrown when setting a borrowable reserve as the managed collateral reserve.
  error UnsupportedBorrowableCollateral();

  /// @notice Updates the Babylon liquidation config.
  /// @dev The managed collateral reserve must be listed and not borrowable: a user holds a single
  /// debt reserve, which can never be the collateral being seized. It is intended to be set once at
  /// initialization: users can only enable the configured reserve as collateral, so changing it
  /// with live positions leaves collateral registered under the previous reserve unliquidatable.
  /// @param liquidationManager The only address allowed to perform liquidations on this Spoke.
  /// @param managedCollateralReserveId The identifier of the only reserve usable as collateral.
  function updateBabylonLiquidationConfig(
    address liquidationManager,
    uint256 managedCollateralReserveId
  ) external;

  /// @notice Liquidates a user position with cap-bounded sizing.
  /// @dev Caller must be the configured liquidation manager, with prior approval for the repaid debt asset.
  /// @dev The repayment is sized up to `debtToCover`, capped at the user's debt, with no target health
  /// factor sizing; the removed collateral is priced with the canonical bonus formula. When the priced
  /// removal exceeds `maxCollateralToRemove`, the repayment is resized to exactly consume it.
  /// @dev No dust validation and no liquidation fee: the liquidator receives the full removed
  /// collateral of the managed collateral reserve, always in underlying assets.
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

  /// @notice Returns the Babylon liquidation config.
  /// @return The address of the liquidation manager.
  /// @return The identifier of the managed collateral reserve.
  function getBabylonLiquidationConfig() external view returns (address, uint256);
}
