// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';
// import 'forge-std/StdCheats.sol';

import 'src/contracts/LiquidityHub.sol';
import 'src/dependencies/openzeppelin/IERC20.sol';
import './mocks/ERC20Mock.sol';

import './Utils.t.sol';

// library Constants {}

contract Events {
  // OpenZeppelin
  event Transfer(address indexed from, address indexed to, uint256 value);

  // Aave
  event Supply(
    uint256 indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );
  event Withdraw(uint256 indexed reserve, address indexed user, address indexed to, uint256 amount);
}

library Errors {
  // Aave
  bytes constant NOT_AVAILABLE_LIQUIDITY = 'NOT_AVAILABLE_LIQUIDITY';
  bytes constant RESERVE_NOT_ACTIVE = 'RESERVE_NOT_ACTIVE';
  bytes constant ASSET_NOT_LISTED = 'ASSET_NOT_LISTED';
}

abstract contract BaseTest is Test, Events {
  IERC20 internal usdc;
  IERC20 internal dai;
  IERC20 internal usdt;

  LiquidityHub hub;

  address internal USER1 = makeAddr('USER1');

  function setUp() public virtual {
    hub = new LiquidityHub();
    usdc = new ERC20Mock();
    dai = new ERC20Mock();
    usdt = new ERC20Mock();
  }
}
