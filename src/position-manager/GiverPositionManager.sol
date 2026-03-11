// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IGiverPositionManager} from 'src/position-manager/interfaces/IGiverPositionManager.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title GiverPositionManager
/// @author Aave Labs
/// @notice Position manager to handle supply and repay actions on behalf of users.
contract GiverPositionManager is IGiverPositionManager, PositionManagerBase {
  using SafeERC20 for IERC20;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  /// @inheritdoc IGiverPositionManager
  function supplyOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    underlying.safeTransferFrom(msg.sender, address(this), amount);
    underlying.forceApprove(spoke, amount);
    return ISpoke(spoke).supply(reserveId, amount, onBehalfOf);
  }

  /// @inheritdoc IGiverPositionManager
  function repayOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    require(amount != type(uint256).max, RepayOnBehalfMaxUintNotAllowed());
    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));

    uint256 userTotalDebt = ISpoke(spoke).getUserTotalDebt(reserveId, onBehalfOf);
    uint256 repayAmount = amount > userTotalDebt ? userTotalDebt : amount;

    underlying.safeTransferFrom(msg.sender, address(this), repayAmount);
    underlying.forceApprove(spoke, repayAmount);
    return ISpoke(spoke).repay(reserveId, repayAmount, onBehalfOf);
  }

  function _multicallEnabled() internal pure override returns (bool) {
    return true;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('GiverPositionManager', '1');
  }
}
