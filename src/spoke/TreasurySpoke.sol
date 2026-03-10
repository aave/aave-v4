// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';

/// @title TreasurySpoke
/// @author Aave Labs
/// @notice Spoke contract used as a treasury where accumulated fees are treated as supplied assets.
/// @dev Dedicated to a single user, controlled exclusively by the owner.
/// @dev Allows withdraw to claim fees and supply to invest back into any Hub asset.
abstract contract TreasurySpoke is ITreasurySpoke, Ownable2StepUpgradeable {
  using SafeERC20 for IERC20;

  /// @dev To be overridden by the inheriting TreasurySpoke instance contract.
  function initialize(address owner) external virtual;

  /// @inheritdoc ITreasurySpoke
  function supply(
    address hub,
    address underlying,
    uint256 amount
  ) external onlyOwner returns (uint256) {
    IHubBase hubContract = IHubBase(hub);
    uint256 assetId = hubContract.getAssetId(underlying);
    IERC20(underlying).safeTransferFrom(msg.sender, hub, amount);

    return hubContract.add(assetId, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function withdraw(
    address hub,
    address underlying,
    uint256 amount
  ) external onlyOwner returns (uint256) {
    IHubBase hubContract = IHubBase(hub);
    uint256 assetId = hubContract.getAssetId(underlying);
    // if amount to withdraw is greater than total supplied, withdraw all supplied assets
    uint256 withdrawnAmount = MathUtils.min(
      amount,
      hubContract.getSpokeAddedAssets(assetId, address(this))
    );

    return hubContract.remove(assetId, withdrawnAmount, msg.sender);
  }

  /// @inheritdoc ITreasurySpoke
  function transfer(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedAssets(address hub, address underlying) external view returns (uint256) {
    uint256 assetId = IHubBase(hub).getAssetId(underlying);
    return IHubBase(hub).getSpokeAddedAssets(assetId, address(this));
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedShares(address hub, address underlying) external view returns (uint256) {
    uint256 assetId = IHubBase(hub).getAssetId(underlying);
    return IHubBase(hub).getSpokeAddedShares(assetId, address(this));
  }
}
