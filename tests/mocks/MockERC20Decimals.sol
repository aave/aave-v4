// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ERC20} from 'src/dependencies/openzeppelin/ERC20.sol';

contract MockERC20Decimals is ERC20 {
  uint8 private _decimals;

  constructor(uint8 decimals_) ERC20('MockERC20', 'E20M') {
    _decimals = decimals_;
  }

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }
}
