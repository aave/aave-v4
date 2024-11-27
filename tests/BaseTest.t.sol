// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';
// import 'forge-std/StdCheats.sol';

import 'src/contracts/LiquidityHub.sol';
import 'src/contracts/Spoke.sol';
import 'src/contracts/WadRayMath.sol';
import 'src/contracts/SharesMath.sol';
import 'src/contracts/MathUtils.sol';
import 'src/contracts/DefaultReserveInterestRateStrategy.sol';
import 'src/dependencies/openzeppelin/IERC20.sol';
import 'src/interfaces/ISpoke.sol';
import 'src/libraries/types/DataTypes.sol';
import './mocks/MockERC20.sol';
import './mocks/MockPriceOracle.sol';
import './mocks/MockSpokeCreditLine.sol';
import './Utils.t.sol';

// library Constants {}

contract Events {
  // OpenZeppelin
  event Transfer(address indexed from, address indexed to, uint256 value);

  // Aave

  // ILiquidityHub
  event Supply(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event Withdraw(
    uint256 indexed assetId,
    address indexed spoke,
    address indexed to,
    uint256 amount
  );
  event Draw(uint256 indexed assetId, address indexed spoke, address indexed to, uint256 amount);
  event Restore(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event SpokeAdded(uint256 indexed assetId, address indexed spoke);

  // ISpoke
  event Borrowed(uint256 indexed assetId, address indexed user, uint256 amount);
  event Repaid(uint256 indexed assetId, address indexed user, uint256 amount);
  event Supplied(uint256 indexed assetId, address indexed user, uint256 amount);
  event Withdrawn(uint256 indexed assetId, address indexed user, uint256 amount);
  event ReserveConfigUpdated(
    uint256 indexed assetId,
    uint256 lt,
    uint256 lb,
    bool borrowable,
    bool collateral
  );
  event UsingAsCollateral(uint256 indexed assetId, address indexed user, bool usingAsCollateral);
}

library TestErrors {
  // Aave
  // LiquidityHub
  bytes constant NOT_AVAILABLE_LIQUIDITY = 'NOT_AVAILABLE_LIQUIDITY';
  bytes constant ASSET_NOT_ACTIVE = 'ASSET_NOT_ACTIVE';
  bytes constant ASSET_NOT_LISTED = 'ASSET_NOT_LISTED';
  bytes constant INVALID_AMOUNT = 'INVALID_AMOUNT';
  bytes constant SUPPLY_CAP_EXCEEDED = 'SUPPLY_CAP_EXCEEDED';
  bytes constant DRAW_CAP_EXCEEDED = 'DRAW_CAP_EXCEEDED';
  bytes constant SUPPLIED_AMOUNT_EXCEEDED = 'SUPPLIED_AMOUNT_EXCEEDED';
  bytes constant INSUFFICIENT_LIQUIDITY = 'INSUFFICIENT_LIQUIDITY';
  bytes constant RESERVE_NOT_BORROWABLE = 'RESERVE_NOT_BORROWABLE';
  bytes constant INVALID_RESERVE = 'INVALID_RESERVE';
  bytes constant INVALID_SPOKE = 'INVALID_SPOKE';
  bytes constant RESERVE_NOT_COLLATERAL = 'RESERVE_NOT_COLLATERAL';
  bytes constant INVALID_RESTORE_AMOUNT = 'INVALID_RESTORE_AMOUNT';
  // Spoke
  bytes constant NO_SUPPLY = 'NO_SUPPLY';
  bytes constant REPAY_EXCEEDS_DEBT = 'REPAY_EXCEEDS_DEBT';
  bytes constant RESERVE_NOT_LISTED = 'RESERVE_NOT_LISTED';
}

abstract contract BaseTest is Test, Events {
  using WadRayMath for uint256;
  using SharesMath for uint256;

  // TODO: update these mocked tokens with decimals as in the real contracts, ie USDC = 6, wbtc = 8, etc.?
  IERC20 internal usdc;
  IERC20 internal dai;
  IERC20 internal usdt;
  IERC20 internal eth;
  IERC20 internal wbtc;

  IPriceOracle oracle;
  LiquidityHub hub;
  Spoke spoke1;
  Spoke spoke2;
  MockSpokeCreditLine spokeCreditLine;
  DefaultReserveInterestRateStrategy irStrategy;
  DefaultReserveInterestRateStrategy creditLineIRStrategy;

  address internal mockAddressesProvider = makeAddr('mockAddressesProvider');
  address internal USER1 = makeAddr('USER1');
  address internal USER2 = makeAddr('USER2');

  function setUp() public virtual {
    oracle = new MockPriceOracle();
    creditLineIRStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
    irStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
    hub = new LiquidityHub();
    spoke1 = new Spoke(address(hub), address(oracle));
    spoke2 = new Spoke(address(hub), address(oracle));
    dai = new MockERC20();
    eth = new MockERC20();
    usdc = new MockERC20();
    usdt = new MockERC20();
    wbtc = new MockERC20();
  }
}
