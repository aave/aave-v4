// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeTransferLib} from 'src/dependencies/solady/SafeTransferLib.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';

/// @title TreasurySpoke
/// @author Aave Labs
/// @notice Spoke contract used as a treasury where accumulated fees are treated as supplied assets.
/// @dev Dedicated to a single user, controlled exclusively by the owner.
/// @dev Utilizes all assets from the Hub without restrictions, making reserve and asset identifiers aligned.
/// @dev Allows withdraw to claim fees and supply to invest back into the Hub via this dedicated spoke.
contract TreasurySpoke is ITreasurySpoke, Ownable2Step {
  using SafeTransferLib for address;

  /// @dev Constructor.
  /// @param owner_ The address of the owner.
  constructor(address owner_) Ownable(owner_) {}

  /// @inheritdoc ITreasurySpoke
  function supply(
    address hub,
    address asset,
    uint256 amount
  ) external onlyOwner returns (uint256, uint256) {
    asset.safeTransferFrom(msg.sender, hub, amount);
    uint256 shares = IHubBase(hub).add(asset, amount);

    return (shares, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function withdraw(
    address hub,
    address asset,
    uint256 amount
  ) external onlyOwner returns (uint256, uint256) {
    // if amount to withdraw is greater than total supplied, withdraw all supplied assets
    uint256 withdrawnAmount = MathUtils.min(
      amount,
      IHubBase(hub).getSpokeAddedAssets(asset, address(this))
    );
    uint256 withdrawnShares = IHubBase(hub).remove(asset, withdrawnAmount, msg.sender);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ITreasurySpoke
  function transfer(address token, address to, uint256 amount) external onlyOwner {
    token.safeTransfer(to, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedAmount(address hub, address asset) external view returns (uint256) {
    return IHubBase(hub).getSpokeAddedAssets(asset, address(this));
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedShares(address hub, address asset) external view returns (uint256) {
    return IHubBase(hub).getSpokeAddedShares(asset, address(this));
  }
}
