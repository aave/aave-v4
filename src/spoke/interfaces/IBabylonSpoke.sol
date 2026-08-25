// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title IBabylonSpoke
/// @author Aave Labs
/// @notice Full interface for the BabylonSpoke.
interface IBabylonSpoke is ISpoke {
  /// @notice Per-reserve liquidation bypass flags.
  /// @dev bypassLiquidationDust True if the liquidation dust protection is bypassed for liquidations involving the reserve.
  /// @dev bypassTargetHealthFactor True if liquidations involving the reserve are not sized by the target health factor.
  struct LiquidationBypass {
    bool bypassLiquidationDust;
    bool bypassTargetHealthFactor;
  }

  /// @notice Emitted when the liquidation bypass flags of a reserve are updated.
  /// @param reserveId The identifier of the reserve.
  /// @param bypass The new liquidation bypass flags.
  event UpdateLiquidationBypass(uint256 indexed reserveId, LiquidationBypass bypass);

  /// @notice Thrown when the disabled canonical liquidation entry point is called.
  error UnsupportedLiquidationCall();

  /// @notice Updates the liquidation bypass flags of a reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param bypass The new liquidation bypass flags.
  function updateLiquidationBypass(uint256 reserveId, LiquidationBypass calldata bypass) external;

  /// @notice Liquidates a user position with a cap on the total collateral removed.
  /// @dev It reverts if the reserves associated with any of the given reserve identifiers are not listed.
  /// @dev The Spoke pulls underlying repaid debt assets from caller (Liquidator), hence it needs prior approval.
  /// @dev The total collateral removed is capped at `maxCollateralToRemove`; when the cap binds, the repaid
  /// debt is resized to exactly consume it, and the remaining collateral and debt must respect the dust threshold.
  /// @dev Dust protection and target health factor sizing are bypassed if the corresponding bypass flag is set
  /// on either the collateral or the debt reserve.
  /// @param collateralReserveId The reserveId of the underlying asset used as collateral by the liquidated user.
  /// @param debtReserveId The reserveId of the underlying asset borrowed by the liquidated user, to be repaid by Liquidator.
  /// @param user The address of the user to liquidate.
  /// @param debtToCover The desired amount of debt to cover.
  /// @param maxCollateralToRemove The maximum total amount of collateral to remove from the user, expressed in asset units. Use `type(uint256).max` for no cap.
  /// @param receiveShares True to receive collateral in supplied shares, false to receive in underlying assets.
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256 maxCollateralToRemove,
    bool receiveShares
  ) external;

  /// @notice Returns the liquidation bypass flags of a reserve.
  /// @param reserveId The identifier of the reserve.
  /// @return The liquidation bypass flags.
  function getLiquidationBypass(uint256 reserveId) external view returns (LiquidationBypass memory);
}
