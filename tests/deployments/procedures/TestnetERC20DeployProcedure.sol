// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

contract TestnetERC20DeployProcedure {
  function _deployTestnetERC20(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) internal returns (address) {
    address token = address(
      new TestnetERC20({name_: name_, symbol_: symbol_, decimals_: decimals_})
    );

    return token;
  }
}
