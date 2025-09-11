// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

import {IRescuable} from 'src/interfaces/IRescuable.sol';

/**
 * @notice This contracts allows to rescue funds sent to the contract by mistake or stuck after transactions.
 */
contract Rescuable is IRescuable, Ownable2Step {
  using SafeERC20 for *;

  constructor(address admin_) Ownable(admin_) {}

  /// @inheritdoc IRescuable
  function rescueToken(address token, address to) external onlyOwner {
    IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
  }

  /// @inheritdoc IRescuable
  function rescueNative(address to, uint256 amount) external onlyOwner {
    Address.sendValue(payable(to), amount);
  }
}
