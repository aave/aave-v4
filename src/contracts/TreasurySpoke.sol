// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IHub} from 'src/interfaces/IHub.sol';
import {ITreasurySpoke, ISpokeBase} from 'src/interfaces/ITreasurySpoke.sol';

/**
 * @title TreasurySpoke
 * @notice Spoke contract used as a treasury where accumulated fees are treated as supplied assets.
 * @dev Dedicated to a single user, controlled exclusively by the owner.
 * @dev Utilizes all assets from the Hub without restrictions, making reserve and asset identifiers aligned.
 * @dev Allows withdraw to claim fees and supply to invest back into the Hub via this dedicated spoke.
 */
contract TreasurySpoke is ITreasurySpoke, Ownable {
  using SafeERC20 for IERC20;

  /// @inheritdoc ITreasurySpoke
  IHub public immutable HUB;

  /**
   * @dev Constructor
   * @param owner_ The address of the owner
   * @param hub_ The address of the Hub
   */
  constructor(address owner_, address hub_) Ownable(owner_) {
    require(hub_ != address(0), InvalidHubAddress());

    HUB = IHub(hub_);
  }

  /// @inheritdoc ITreasurySpoke
  function supply(uint256 reserveId, uint256 amount, address) external onlyOwner {
    HUB.add(reserveId, amount, msg.sender);
  }

  /// @inheritdoc ITreasurySpoke
  function withdraw(uint256 reserveId, uint256 amount, address) external onlyOwner {
    // If uint256.max is passed, withdraw all supplied assets
    if (amount == type(uint256).max) {
      amount = HUB.getSpokeAddedAmount(reserveId, address(this));
    }

    HUB.remove(reserveId, amount, msg.sender);
  }

  /// @inheritdoc ITreasurySpoke
  function transfer(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedAmount(uint256 reserveId) external view returns (uint256) {
    return HUB.getSpokeAddedAmount(reserveId, address(this));
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedShares(uint256 reserveId) external view returns (uint256) {
    return HUB.getSpokeAddedShares(reserveId, address(this));
  }

  /// @inheritdoc ISpokeBase
  function borrow(uint256 reserveId, uint256 amount, address) external {
    /// intentionally left blank
  }

  /// @inheritdoc ISpokeBase
  function repay(uint256 reserveId, uint256 amount, address) external {
    /// intentionally left blank
  }

  /// @inheritdoc ISpokeBase
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external {
    /// intentionally left blank
  }
}
