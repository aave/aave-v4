// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

import {IRescuable} from 'src/interfaces/IRescuable.sol';

/**
 * @notice This contracts allows to rescue funds sent to the contract by mistake or stuck after transactions.
 */
abstract contract Rescuable is IRescuable {
  using SafeERC20 for *;

  /// @notice modifier that checks that caller is allowed address
  modifier onlyRescueGuardian() {
    if (msg.sender != rescueGuardian()) {
      revert OnlyRescueGuardian();
    }
    _;
  }

  /// @inheritdoc IRescuable
  function rescueToken(address token, address to) external onlyRescueGuardian {
    IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
  }

  /// @inheritdoc IRescuable
  function rescueNative(address to, uint256 amount) external onlyRescueGuardian {
    Address.sendValue(payable(to), amount);
  }

  /**
   * @notice Returns the address that is allowed to rescue funds.
   **/
  function rescueGuardian() public view virtual returns (address);
}
