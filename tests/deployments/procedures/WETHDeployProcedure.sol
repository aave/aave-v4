// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {WETH9} from 'src/dependencies/weth/WETH9.sol';

contract WETHDeployProcedure {
  function _deployWETH() internal returns (address) {
    return address(new WETH9());
  }
}
