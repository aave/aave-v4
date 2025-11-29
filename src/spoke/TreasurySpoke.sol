// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ITreasurySpoke, ISpokeBase} from 'src/spoke/interfaces/ITreasurySpoke.sol';

/// @title TreasurySpoke
/// @author Aave Labs
/// @notice Spoke contract used as a treasury where accumulated fees are treated as supplied assets.
/// @dev Dedicated to a single user, controlled exclusively by the owner.
/// @dev Utilizes all assets from the Hub without restrictions, making reserve and asset identifiers aligned.
/// @dev Allows withdraw to claim fees and supply to invest back into the Hub via this dedicated spoke.
contract TreasurySpoke is ITreasurySpoke, Ownable2Step {
  using SafeERC20 for IERC20;

  /// @inheritdoc ITreasurySpoke
  IHubBase public immutable HUB;

  /// @dev Constructor.
  /// @param owner_ The address of the owner.
  /// @param hub_ The address of the Hub.
  constructor(address owner_, address hub_) Ownable(owner_) {
    require(hub_ != address(0), InvalidAddress());

    HUB = IHubBase(hub_);
  }

  /// @inheritdoc ITreasurySpoke
  function supply(
    uint256 reserveId,
    uint256 amount,
    address
  ) external onlyOwner returns (uint256, uint256) {
    (address underlying, ) = HUB.getAssetUnderlyingAndDecimals(reserveId);
    IERC20(underlying).safeTransferFrom(msg.sender, address(HUB), amount);
    uint256 shares = HUB.add(reserveId, amount);

    return (shares, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function withdraw(
    uint256 reserveId,
    uint256 amount,
    address
  ) external onlyOwner returns (uint256, uint256) {
    // if amount to withdraw is greater than total supplied, withdraw all supplied assets
    uint256 withdrawnAmount = MathUtils.min(
      amount,
      HUB.getSpokeAddedAssets(reserveId, address(this))
    );
    uint256 withdrawnShares = HUB.remove(reserveId, withdrawnAmount, msg.sender);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ITreasurySpoke
  function transfer(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedAmount(uint256 reserveId) external view returns (uint256) {
    return HUB.getSpokeAddedAssets(reserveId, address(this));
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedShares(uint256 reserveId) external view returns (uint256) {
    return HUB.getSpokeAddedShares(reserveId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function borrow(uint256, uint256, address) external pure returns (uint256, uint256) {
    revert UnsupportedAction();
  }

  /// @inheritdoc ISpokeBase
  function repay(uint256, uint256, address) external pure returns (uint256, uint256) {
    revert UnsupportedAction();
  }

  /// @inheritdoc ISpokeBase
  function liquidationCall(uint256, uint256, address, uint256, bool) external pure {
    revert UnsupportedAction();
  }

  /// @inheritdoc ISpokeBase
  function getUserDebt(uint256, address) external pure returns (uint256, uint256) {}

  /// @inheritdoc ISpokeBase
  function getUserTotalDebt(uint256, address) external pure returns (uint256) {}

  /// @inheritdoc ISpokeBase
  function getUserPremiumDebtRay(uint256, address) external pure returns (uint256) {}

  /// @inheritdoc ISpokeBase
  function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256) {
    return HUB.getSpokeAddedAssets(reserveId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256) {
    return HUB.getSpokeAddedShares(reserveId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function getUserSuppliedAssets(uint256, address) external pure returns (uint256) {}

  /// @inheritdoc ISpokeBase
  function getUserSuppliedShares(uint256, address) external pure returns (uint256) {}

  /// @inheritdoc ISpokeBase
  function getReserveDebt(uint256) external pure returns (uint256, uint256) {}

  /// @inheritdoc ISpokeBase
  function getReserveTotalDebt(uint256) external pure returns (uint256) {}
}
