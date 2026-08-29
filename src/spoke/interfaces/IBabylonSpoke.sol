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

  /// @dev Emitted for each debt reserve repaid during a Babylon liquidation.
  /// @param debtReserveId The identifier of the repaid debt reserve.
  /// @param user The address of the borrower getting liquidated.
  /// @param liquidator The address of the liquidator.
  /// @param debtAmountRestored The amount of debt restored, expressed in asset units.
  /// @param drawnSharesLiquidated The amount of drawn shares liquidated.
  /// @param premiumDelta A struct representing the changes to premium debt after liquidation.
  /// @param collateralAmountRemoved The amount of collateral removed, expressed in asset units.
  /// @param collateralSharesLiquidated The amount of collateral shares liquidated.
  event BabylonLiquidationCall(
    uint256 indexed debtReserveId,
    address indexed user,
    address liquidator,
    uint256 debtAmountRestored,
    uint256 drawnSharesLiquidated,
    IHubBase.PremiumDelta premiumDelta,
    uint256 collateralAmountRemoved,
    uint256 collateralSharesLiquidated
  );

  /// @dev Emitted once per Babylon liquidation, after all repayments.
  /// @param user The address of the borrower getting liquidated.
  /// @param liquidator The address of the liquidator.
  /// @param collateralAmountRemoved The total amount of collateral removed, expressed in asset units.
  /// @param collateralSharesLiquidated The total amount of collateral shares liquidated.
  event BabylonLiquidationCallSummary(
    address indexed user,
    address indexed liquidator,
    uint256 collateralAmountRemoved,
    uint256 collateralSharesLiquidated
  );

  /// @notice Thrown when the debt reserve and amount arrays are empty or of different lengths.
  error InvalidLiquidationCallArguments();

  /// @notice Thrown when the disabled canonical liquidation entry point is called.
  error UnsupportedLiquidationCall();

  /// @notice Thrown when registering a reserve as collateral while another one is registered.
  error CollateralLimitExceeded();

  /// @notice Thrown when registering a reserve other than the managed collateral reserve as collateral.
  error UnsupportedCollateralReserve();

  /// @notice Updates the Babylon liquidation config.
  /// @dev The managed collateral reserve must be listed. It is intended to be set once at
  /// initialization: users can only enable the configured reserve as collateral, so changing it
  /// with live positions leaves collateral registered under the previous reserve unliquidatable.
  /// @param liquidationManager The only address allowed to perform liquidations on this Spoke.
  /// @param managedCollateralReserveId The identifier of the only reserve usable as collateral.
  function updateBabylonLiquidationConfig(
    address liquidationManager,
    uint256 managedCollateralReserveId
  ) external;

  /// @notice Liquidates a user position with cap-bounded sizing.
  /// @dev Caller must be the configured liquidation manager, with prior approval for the repaid debt assets.
  /// @dev The health factor is validated once at entry: an intermediate repayment restoring it must
  /// not block completing the collateral removal, which is bounded by `maxCollateralToRemove`.
  /// @dev Each debt reserve is repaid up to its cover amount, capped at the user's full debt, with
  /// no target health factor sizing; the removed collateral is priced with the canonical bonus
  /// formula from the entry health factor. When the priced removal exceeds the remaining cap, the
  /// final repayment is resized to exactly consume it and later debt reserves are left untouched.
  /// A debt reserve the user no longer borrows is skipped, so front-running repayments cannot
  /// block the call.
  /// @dev No dust validation and no liquidation fee: the liquidator receives the full removed
  /// collateral of the managed collateral reserve, always in underlying assets.
  /// @param debtReserveIds The reserveIds of the underlying assets borrowed by the liquidated user, in repayment order.
  /// @param debtToCoverAmounts The desired amount of debt to cover per debt reserve.
  /// @param user The address of the user to liquidate.
  /// @param maxCollateralToRemove The maximum total amount of collateral to remove from the user, expressed in asset units.
  function liquidationCall(
    uint256[] calldata debtReserveIds,
    uint256[] calldata debtToCoverAmounts,
    address user,
    uint256 maxCollateralToRemove
  ) external;

  /// @notice Returns the Babylon liquidation config.
  /// @return The address of the liquidation manager.
  /// @return The identifier of the managed collateral reserve.
  function getBabylonLiquidationConfig() external view returns (address, uint256);
}
