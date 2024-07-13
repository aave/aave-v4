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
  address internal USER2 = makeAddr('USER2');
  address internal USER3 = makeAddr('USER3');
  address internal ADMIN = makeAddr('ADMIN');

  IERC20 internal usdc;
  IERC20 internal dai;
  IERC20 internal usdt;

  LiquidityHub hub;

  function setUp() public virtual {
    vm.startPrank(ADMIN);
    hub = new LiquidityHub();
    usdc = new ERC20Mock();
    dai = new ERC20Mock();
    usdt = new ERC20Mock();
    vm.stopPrank();
  }
}
