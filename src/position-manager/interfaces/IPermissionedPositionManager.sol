// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {IRescuable} from 'src/interfaces/IRescuable.sol';

type PermissionedActions is uint8;

/// @title IPermissionedPositionManager
/// @author Aave Labs
/// @notice Interface for the mandatory position manager restricting permissioned Spoke actions to approved callers.
interface IPermissionedPositionManager is IRescuable, IMulticall {
  /// @notice Spoke actions which can be permissioned.
  enum Action {
    Supply,
    Withdraw,
    Borrow,
    Repay,
    SetUsingAsCollateral,
    LiquidationCall,
    UpdateUserRiskPremium,
    UpdateUserDynamicConfig
  }

  /// @notice Emitted when the permissioned status of an action is updated.
  /// @param action The action.
  /// @param permissioned True if the action is permissioned.
  event SetPermissionedAction(Action indexed action, bool permissioned);

  /// @notice Emitted when the approval status of a caller is updated.
  /// @param caller The address of the caller.
  /// @param approved True if the caller is approved to perform permissioned actions.
  event SetApprovedCaller(address indexed caller, bool approved);

  /// @notice Thrown when the specified address is invalid.
  error InvalidAddress();

  /// @notice Thrown when the caller is not allowed to act on behalf of the position owner.
  error Unauthorized();

  /// @notice Thrown when the account is not approved to perform a permissioned action.
  error CallerNotApproved();

  /// @notice Sets the permissioned status of an action.
  /// @param action The action.
  /// @param permissioned True to restrict the action to approved callers, false to open it to any caller.
  function setPermissionedAction(Action action, bool permissioned) external;

  /// @notice Sets the approval status of a caller for permissioned actions.
  /// @param caller The address of the caller.
  /// @param approved True to approve the caller, false to revoke approval.
  function setApprovedCaller(address caller, bool approved) external;

  /// @notice Supplies on the Spoke through this position manager.
  /// @dev Caller provides the underlying asset.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to supply.
  /// @param onBehalfOf The owner of the position.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supply(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Withdraws from the Spoke through this position manager.
  /// @dev Caller receives the underlying asset withdrawn.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to withdraw.
  /// @param onBehalfOf The owner of the position.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdraw(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Borrows from the Spoke through this position manager.
  /// @dev Caller receives the underlying asset borrowed.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to borrow.
  /// @param onBehalfOf The owner of the position.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Repays on the Spoke through this position manager.
  /// @dev Caller provides the underlying asset. Amount is capped to the total debt of `onBehalfOf`.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to repay.
  /// @param onBehalfOf The owner of the position.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repay(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Sets the usage of a reserve as collateral on the Spoke through this position manager.
  /// @param reserveId The identifier of the reserve.
  /// @param usingAsCollateral True to enable the reserve as collateral, false to disable.
  /// @param onBehalfOf The owner of the position.
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external;

  /// @notice Liquidates a user position on the Spoke through this position manager.
  /// @dev Caller provides up to `debtToCover` of the debt asset, and receives the unused part along with the
  /// collateral seized in underlying assets. Receiving shares is not supported.
  /// @param collateralReserveId The identifier of the collateral reserve.
  /// @param debtReserveId The identifier of the debt reserve.
  /// @param user The address of the user to liquidate.
  /// @param debtToCover The desired amount of debt to cover.
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external;

  /// @notice Updates the risk premium of a user position on the Spoke through this position manager.
  /// @param onBehalfOf The owner of the position.
  function updateUserRiskPremium(address onBehalfOf) external;

  /// @notice Updates the dynamic config of a user position on the Spoke through this position manager.
  /// @param onBehalfOf The owner of the position.
  function updateUserDynamicConfig(address onBehalfOf) external;

  /// @notice Returns whether the action is permissioned.
  /// @param action The action.
  /// @return True if the action is restricted to approved callers.
  function isActionPermissioned(Action action) external view returns (bool);

  /// @notice Returns whether the caller is approved for permissioned actions.
  /// @param caller The address of the caller.
  /// @return True if the caller is approved.
  function isApprovedCaller(address caller) external view returns (bool);

  /// @notice Returns the address of the Spoke this position manager routes calls to.
  function SPOKE() external view returns (address);
}
