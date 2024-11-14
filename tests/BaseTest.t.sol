// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';
// import 'forge-std/StdCheats.sol';

import 'src/contracts/LiquidityHub.sol';
import 'src/contracts/BorrowModule.sol';
import 'src/contracts/WadRayMath.sol';
import 'src/contracts/SharesMath.sol';
import 'src/contracts/MathUtils.sol';
import 'src/dependencies/openzeppelin/IERC20.sol';
import 'src/interfaces/IBorrowModule.sol';
import 'src/contracts/DefaultReserveInterestRateStrategy.sol';
import './mocks/MockERC20.sol';
import './mocks/MockPriceOracle.sol';
import './mocks/MockBorrowModuleCreditLine.sol';

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
  event Borrowed(uint256 indexed assetId, address user, uint256 amount);
  event Repaid(uint256 indexed assetId, address user, uint256 amount);
}

library TestErrors {
  // Aave
  bytes constant NOT_AVAILABLE_LIQUIDITY = 'NOT_AVAILABLE_LIQUIDITY';
  bytes constant RESERVE_NOT_ACTIVE = 'RESERVE_NOT_ACTIVE';
  bytes constant ASSET_NOT_LISTED = 'ASSET_NOT_LISTED';
  bytes constant INVALID_AMOUNT = 'INVALID_AMOUNT';
  bytes constant CAP_EXCEEDED = 'CAP_EXCEEDED';
  bytes constant INSUFFICIENT_LIQUIDITY = 'INSUFFICIENT_LIQUIDITY';
  bytes constant RESERVE_NOT_BORROWABLE = 'RESERVE_NOT_BORROWABLE';
  bytes constant INVALID_RESERVE = 'INVALID_RESERVE';
}

abstract contract BaseTest is Test, Events {
  using WadRayMath for uint256;
  using SharesMath for uint256;

  IERC20 internal usdc;
  IERC20 internal dai;
  IERC20 internal usdt;
  IERC20 internal eth;

  IPriceOracle oracle;
  LiquidityHub hub;
  BorrowModule bm;
  MockBorrowModuleCreditLine bmcl;
  DefaultReserveInterestRateStrategy creditLineIRStrategy;

  address internal mockAddressesProvider = makeAddr('mockAddressesProvider');
  address internal USER1 = makeAddr('USER1');
  address internal USER2 = makeAddr('USER2');

  function setUp() public virtual {
    oracle = new MockPriceOracle();
    creditLineIRStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
    hub = new LiquidityHub(address(oracle));
    bm = new BorrowModule(address(hub), address(creditLineIRStrategy));
    dai = new MockERC20();
    eth = new MockERC20();
    usdc = new MockERC20();
    usdt = new MockERC20();
  }
}
