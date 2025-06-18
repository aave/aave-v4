// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {ITreasurySpoke} from 'src/interfaces/ITreasurySpoke.sol';

/**
 * @title TreasurySpoke
 * @notice Spoke contract used as a treasury where accumulated fees are treated as supplied assets.
 * @dev Dedicated to a single user, controlled exclusively by the owner.
 * @dev Utilizes all assets from the Hub without restrictions, making reserve and asset identifiers aligned.
 * @dev Allows withdraw to claim fees and supply to invest back into the Hub via this dedicated spoke.
 */
contract TreasurySpoke is Ownable, ITreasurySpoke {
  /// @inheritdoc ITreasurySpoke
  ILiquidityHub public immutable HUB;

  /**
   * @dev Constructor
   * @param owner_ The address of the owner
   * @param hub_ The address of the LiquidityHub
   */
  constructor(address owner_, address hub_) Ownable(owner_) {
    require(hub_ != address(0), InvalidHubAddress());

    HUB = ILiquidityHub(hub_);
  }

  /// @inheritdoc ITreasurySpoke
  function supply(uint256 reserveId, uint256 amount) external onlyOwner {
    HUB.add(reserveId, amount, msg.sender);
  }

  /// @inheritdoc ITreasurySpoke
  function withdraw(uint256 reserveId, uint256 amount, address to) external onlyOwner {
    // If uint256.max is passed, withdraw all supplied assets
    if (amount == type(uint256).max) {
      amount = HUB.getSpokeSuppliedAmount(reserveId, address(this));
    }

    HUB.remove(reserveId, amount, to);
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedAmount(uint256 reserveId) external view returns (uint256) {
    return HUB.getSpokeSuppliedAmount(reserveId, address(this));
  }

  /// @inheritdoc ITreasurySpoke
  function getSuppliedShares(uint256 reserveId) external view returns (uint256) {
    return HUB.getSpokeSuppliedShares(reserveId, address(this));
  }

  // todo: add functions to transfer ERC20 out, assuming this can hold assets
  // todo: add functions to rescue
}
