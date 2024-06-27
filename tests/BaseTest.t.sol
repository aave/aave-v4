// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';
// import 'forge-std/StdCheats.sol';

import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ERC20Mock} from './mocks/ERC20Mock.sol';

abstract contract BaseTest is Test {
  address internal USER1 = makeAddr('USER1');

  IERC20 internal usdc;
  IERC20 internal dai;
  IERC20 internal usdt;

  LiquidityHub hub;

  function setUp() public virtual {
    hub = new LiquidityHub(address(0));
    usdc = new ERC20Mock();
    dai = new ERC20Mock();
    usdt = new ERC20Mock();
  }
}
