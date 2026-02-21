// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ERC20} from 'src/dependencies/openzeppelin/ERC20.sol';

contract MockERC20 is ERC20 {
  // TODO: add decimals to constructor to be able to mimic actual tokens, ie USDC has 6 decimals
  constructor() ERC20('MockERC20', 'E20M') {}

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }
}
