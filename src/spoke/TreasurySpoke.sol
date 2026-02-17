// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';

/// @title TreasurySpoke
/// @author Aave Labs
/// @notice Spoke contract used as a treasury where accumulated fees are treated as supplied assets.
/// @dev Dedicated to a single user, controlled exclusively by the owner.
/// @dev Allows withdraw to claim fees and supply to invest back into the corresponding hub via this dedicated spoke.
contract TreasurySpoke is ITreasurySpoke, Ownable2Step {
  using SafeERC20 for IERC20;

  /// @dev Constructor.
  /// @param owner_ The address of the owner.
  constructor(address owner_) Ownable(owner_) {}

  /// @inheritdoc ITreasurySpoke
  function supply(
    address hub,
    uint256 assetId,
    uint256 amount,
    address
  ) external onlyOwner returns (uint256, uint256) {
    IHub hubContract = IHub(hub);
    address underlying = hubContract.getAsset(assetId).underlying;
    IERC20(underlying).safeTransferFrom(msg.sender, hub, amount);
    uint256 shares = hubContract.add(assetId, amount);

    return (shares, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function withdraw(
    address hub,
    uint256 assetId,
    uint256 amount,
    address
  ) external onlyOwner returns (uint256, uint256) {
    // if amount to withdraw is greater than total supplied, withdraw all supplied assets
    uint256 withdrawnAmount = MathUtils.min(
      amount,
      IHubBase(hub).getSpokeAddedAssets(assetId, address(this))
    );
    uint256 withdrawnShares = IHubBase(hub).remove(assetId, withdrawnAmount, msg.sender);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ITreasurySpoke
  function transfer(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedAmount(address hub, uint256 assetId) external view returns (uint256) {
    return IHubBase(hub).getSpokeAddedAssets(assetId, address(this));
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedShares(address hub, uint256 assetId) external view returns (uint256) {
    return IHubBase(hub).getSpokeAddedShares(assetId, address(this));
  }
}
