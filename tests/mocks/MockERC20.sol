// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from 'src/dependencies/openzeppelin/ERC20.sol';

contract MockERC20 is ERC20 {
  constructor() ERC20('MockERC20', 'E20M') {}

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }
}
