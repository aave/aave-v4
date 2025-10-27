// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

contract MockDummySpoke {
  using SafeERC20 for IERC20;

  bool public tamperedTransfers;

  function transferAssetsFrom(
    uint256 /*assetId*/,
    address underlying,
    address from,
    uint256 amount
  ) external {
    if (tamperedTransfers) {
      // transfer less than expected to simulate a bad transfer
      IERC20(underlying).safeTransferFrom(from, msg.sender, amount / 2);
    } else {
      IERC20(underlying).safeTransferFrom(from, msg.sender, amount);
    }
  }

  function setTamperedTransfers(bool tampered) external {
    tamperedTransfers = tampered;
  }
}
