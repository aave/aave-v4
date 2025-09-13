// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

interface INativeWrapper is IERC20 {
  function deposit() external payable;

  function withdraw(uint256 amount) external;
}
