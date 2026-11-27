// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {Rescuable} from 'src/utils/Rescuable.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {PermissionedActionsMap} from 'src/position-manager/libraries/PermissionedActionsMap.sol';
import {
  IPermissionedPositionManager,
  PermissionedActions
} from 'src/position-manager/interfaces/IPermissionedPositionManager.sol';

/// @title PermissionedPositionManager
/// @author Aave Labs
/// @notice Mandatory position manager routing actions to a single Spoke, where permissioned actions are restricted
/// to owner-approved callers.
/// @dev Contract must be set as the mandatory position manager of the Spoke.
/// @dev Callers can only act on their own position.
contract PermissionedPositionManager is
  IPermissionedPositionManager,
  Ownable2StepUpgradeable,
  Rescuable,
  Multicall
{
  using SafeERC20 for IERC20;
  using PermissionedActionsMap for PermissionedActions;

  /// @notice The revision of the position manager, used for upgrades.
  uint64 public constant POSITION_MANAGER_REVISION = 1;

  /// @inheritdoc IPermissionedPositionManager
  address public immutable SPOKE;

  /// @dev Bitmap of permissioned actions.
  PermissionedActions internal _permissionedActions;

  /// @dev Map of callers to their approval status for permissioned actions.
  mapping(address caller => bool approved) internal _approvedCallers;

  /// @dev Reserved storage space to allow for future layout updates.
  uint256[48] private __gap;

  /// @dev Constructor.
  /// @param spoke_ The address of the Spoke.
  constructor(address spoke_) {
    require(spoke_ != address(0), InvalidAddress());
    SPOKE = spoke_;
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @param initialOwner The address of the initial owner.
  function initialize(address initialOwner) external reinitializer(POSITION_MANAGER_REVISION) {
    __Ownable_init(initialOwner);
    __Ownable2Step_init();
  }

  /// @inheritdoc IPermissionedPositionManager
  function setPermissionedAction(Action action, bool permissioned) external onlyOwner {
    _permissionedActions = _permissionedActions.setPermissioned(action, permissioned);
    emit SetPermissionedAction(action, permissioned);
  }

  /// @inheritdoc IPermissionedPositionManager
  function setApprovedCaller(address caller, bool approved) external onlyOwner {
    _approvedCallers[caller] = approved;
    emit SetApprovedCaller(caller, approved);
  }

  /// @inheritdoc IPermissionedPositionManager
  function supply(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    _validateCaller(onBehalfOf, Action.Supply);
    IERC20 underlying = _getReserveUnderlying(reserveId);

    underlying.safeTransferFrom(msg.sender, address(this), amount);
    underlying.forceApprove(SPOKE, amount);
    return ISpoke(SPOKE).supply(reserveId, amount, onBehalfOf);
  }

  /// @inheritdoc IPermissionedPositionManager
  function withdraw(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    _validateCaller(onBehalfOf, Action.Withdraw);

    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpoke(SPOKE).withdraw(
      reserveId,
      amount,
      onBehalfOf
    );
    _getReserveUnderlying(reserveId).safeTransfer(msg.sender, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc IPermissionedPositionManager
  function borrow(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    _validateCaller(onBehalfOf, Action.Borrow);

    (uint256 borrowedShares, uint256 borrowedAmount) = ISpoke(SPOKE).borrow(
      reserveId,
      amount,
      onBehalfOf
    );
    _getReserveUnderlying(reserveId).safeTransfer(msg.sender, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc IPermissionedPositionManager
  function repay(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    _validateCaller(onBehalfOf, Action.Repay);
    IERC20 underlying = _getReserveUnderlying(reserveId);

    uint256 userTotalDebt = ISpoke(SPOKE).getUserTotalDebt(reserveId, onBehalfOf);
    uint256 repayAmount = amount > userTotalDebt ? userTotalDebt : amount;

    underlying.safeTransferFrom(msg.sender, address(this), repayAmount);
    underlying.forceApprove(SPOKE, repayAmount);
    return ISpoke(SPOKE).repay(reserveId, repayAmount, onBehalfOf);
  }

  /// @inheritdoc IPermissionedPositionManager
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external {
    _validateCaller(onBehalfOf, Action.SetUsingAsCollateral);
    ISpoke(SPOKE).setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  /// @inheritdoc IPermissionedPositionManager
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external {
    // the Spoke sees this contract as the liquidator, hence self-liquidation must be checked here
    require(msg.sender != user, ISpoke.SelfLiquidation());
    _validatePermission(msg.sender, Action.LiquidationCall);
    IERC20 collateralUnderlying = _getReserveUnderlying(collateralReserveId);
    IERC20 debtUnderlying = _getReserveUnderlying(debtReserveId);
    uint256 collateralBalanceBefore = collateralUnderlying.balanceOf(address(this));
    uint256 debtBalanceBefore = debtUnderlying.balanceOf(address(this));

    debtUnderlying.safeTransferFrom(msg.sender, address(this), debtToCover);
    debtUnderlying.forceApprove(SPOKE, debtToCover);
    ISpoke(SPOKE).liquidationCall(collateralReserveId, debtReserveId, user, debtToCover, false);

    // balances are snapshotted before pulling the debt asset, so it also holds when both assets are the same
    _transferBalanceIncrease(collateralUnderlying, collateralBalanceBefore);
    if (debtUnderlying != collateralUnderlying) {
      _transferBalanceIncrease(debtUnderlying, debtBalanceBefore);
    }
  }

  /// @inheritdoc IPermissionedPositionManager
  function updateUserRiskPremium(address onBehalfOf) external {
    _validateCaller(onBehalfOf, Action.UpdateUserRiskPremium);
    ISpoke(SPOKE).updateUserRiskPremium(onBehalfOf);
  }

  /// @inheritdoc IPermissionedPositionManager
  function updateUserDynamicConfig(address onBehalfOf) external {
    _validateCaller(onBehalfOf, Action.UpdateUserDynamicConfig);
    ISpoke(SPOKE).updateUserDynamicConfig(onBehalfOf);
  }

  /// @inheritdoc IPermissionedPositionManager
  function isActionPermissioned(Action action) external view returns (bool) {
    return _permissionedActions.isPermissioned(action);
  }

  /// @inheritdoc IPermissionedPositionManager
  function isApprovedCaller(address caller) external view returns (bool) {
    return _approvedCallers[caller];
  }

  /// @dev Validates that the caller can perform `action` on the position of `onBehalfOf`.
  function _validateCaller(address onBehalfOf, Action action) internal view virtual {
    require(msg.sender == onBehalfOf, Unauthorized());
    _validatePermission(onBehalfOf, action);
  }

  /// @dev Validates that `account` is approved if `action` is permissioned.
  function _validatePermission(address account, Action action) internal view {
    require(
      !_permissionedActions.isPermissioned(action) || _approvedCallers[account],
      CallerNotApproved()
    );
  }

  /// @dev Transfers to the caller the increase of this contract's balance of `token` since `balanceBefore`.
  function _transferBalanceIncrease(IERC20 token, uint256 balanceBefore) internal {
    uint256 amount = token.balanceOf(address(this)) - balanceBefore;
    if (amount > 0) {
      token.safeTransfer(msg.sender, amount);
    }
  }

  /// @return The underlying asset of `reserveId` on the Spoke.
  function _getReserveUnderlying(uint256 reserveId) internal view returns (IERC20) {
    return IERC20(ISpoke(SPOKE).getReserve(reserveId).underlying);
  }

  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }
}
