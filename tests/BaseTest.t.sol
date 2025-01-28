// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2 as console} from 'forge-std/console2.sol';
// import 'forge-std/StdCheats.sol';

import {LiquidityHub, ILiquidityHub} from 'src/contracts/LiquidityHub.sol';
import {Spoke, ISpoke} from 'src/contracts/Spoke.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {DefaultReserveInterestRateStrategy, IDefaultInterestRateStrategy, IReserveInterestRateStrategy} from 'src/contracts/DefaultReserveInterestRateStrategy.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {TestnetERC20} from './mocks/TestnetERC20.sol';
import {MockERC20} from './mocks/MockERC20.sol';
import {MockPriceOracle, IPriceOracle} from './mocks/MockPriceOracle.sol';
import {MockSpokeCreditLine} from './mocks/MockSpokeCreditLine.sol';
import {Utils} from './Utils.t.sol';

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
  bytes constant INVALID_SHARES_AMOUNT = 'INVALID_SHARES_AMOUNT';
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

  MockPriceOracle internal oracle;
  LiquidityHub internal hub;
  Spoke internal spoke1;
  Spoke internal spoke2;
  Spoke internal spoke3;
  MockSpokeCreditLine internal spokeCreditLine;
  DefaultReserveInterestRateStrategy internal irStrategy;
  DefaultReserveInterestRateStrategy internal creditLineIRStrategy;

  address internal mockAddressesProvider = makeAddr('mockAddressesProvider');
  address internal USER1 = makeAddr('USER1');
  address internal USER2 = makeAddr('USER2');

  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');
  address internal carol = makeAddr('carol');

  TokenList internal tokenList;
  uint256 internal wethAssetId = 0;
  uint256 internal usdxAssetId = 1;

  struct TokenList {
    WETH9 weth;
    TestnetERC20 usdx;
    TestnetERC20 dai;
    TestnetERC20 wbtc;
  }

  function setUp() public virtual {
    oracle = new MockPriceOracle();
    creditLineIRStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
    irStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
    hub = new LiquidityHub();
    spoke1 = new Spoke(address(hub), address(oracle));
    spoke2 = new Spoke(address(hub), address(oracle));
    spoke3 = new Spoke(address(hub), address(oracle));
    dai = new MockERC20();
    eth = new MockERC20();
    usdc = new MockERC20();
    usdt = new MockERC20();
    wbtc = new MockERC20();

    vm.label(address(spoke1), 'spoke1');
    vm.label(address(spoke2), 'spoke2');
    vm.label(address(spoke3), 'spoke3');
  }

  function initEnvironment() internal {
    deployMintAndApproveTokenList();
    configureTokenList();
  }

  function deployMintAndApproveTokenList() internal {
    tokenList = TokenList(
      new WETH9(),
      new TestnetERC20('USDX', 'USDX', 6),
      new TestnetERC20('DAI', 'DAI', 18),
      new TestnetERC20('WBTC', 'WBTC', 8)
    );

    vm.label(address(tokenList.weth), 'WETH');
    vm.label(address(tokenList.usdx), 'USDX');
    vm.label(address(tokenList.dai), 'DAI');
    vm.label(address(tokenList.wbtc), 'WBTC');

    uint256 mintAmount_USDX = 100_000e6;
    uint256 mintAmount_DAI = 1e60;
    uint256 mintAmount_WBTC = 100e8;
    address[6] memory users = [
      alice,
      bob,
      carol,
      address(spoke1),
      address(spoke2),
      address(spoke3)
    ];

    for (uint256 x; x < users.length; ++x) {
      tokenList.usdx.mint(users[x], mintAmount_USDX);
      tokenList.dai.mint(users[x], mintAmount_DAI);
      tokenList.wbtc.mint(users[x], mintAmount_WBTC);
      deal(address(tokenList.weth), users[x], 100e18);

      vm.startPrank(users[x]);
      tokenList.weth.approve(address(hub), type(uint256).max);
      tokenList.usdx.approve(address(hub), type(uint256).max);
      tokenList.dai.approve(address(hub), type(uint256).max);
      tokenList.wbtc.approve(address(hub), type(uint256).max);
      vm.stopPrank();
    }
  }
  function configureTokenList() internal {
    // todo rm override
    uint256 daiAssetId = 2;
    uint256 wbtcAssetId = 3;

    address[] memory spokes = new address[](3);
    spokes[0] = address(spoke1);
    spokes[1] = address(spoke2);
    spokes[2] = address(spoke3);
    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](3);
    // supplyCap, borrowCap
    spokeConfigs[0] = DataTypes.SpokeConfig(type(uint256).max, type(uint256).max);
    spokeConfigs[1] = DataTypes.SpokeConfig(type(uint256).max, type(uint256).max);
    spokeConfigs[2] = DataTypes.SpokeConfig(type(uint256).max, type(uint256).max);

    Spoke.ReserveConfig[] memory reserveConfigs = new Spoke.ReserveConfig[](3);

    // add WETH
    reserveConfigs[0] = Spoke.ReserveConfig(0.8e4, 0, true, true);
    reserveConfigs[1] = Spoke.ReserveConfig(0.76e4, 0, true, true);
    reserveConfigs[2] = Spoke.ReserveConfig(0.79e4, 0, true, true);
    Utils.addAssetAndSpokes(
      hub,
      address(tokenList.weth),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(wethAssetId, 2000e8);

    // add USDX
    reserveConfigs[0] = Spoke.ReserveConfig(0.78e4, 0, true, true);
    reserveConfigs[1] = Spoke.ReserveConfig(0.72e4, 0, true, true);
    reserveConfigs[2] = Spoke.ReserveConfig(0.75e4, 0, true, true);
    Utils.addAssetAndSpokes(
      hub,
      address(tokenList.usdx),
      DataTypes.AssetConfig({decimals: 6, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(usdxAssetId, 1e8);

    // add DAI
    reserveConfigs[0] = Spoke.ReserveConfig(0.78e4, 0, true, true);
    reserveConfigs[1] = Spoke.ReserveConfig(0.72e4, 0, true, true);
    reserveConfigs[2] = Spoke.ReserveConfig(0.75e4, 0, true, true);
    Utils.addAssetAndSpokes(
      hub,
      address(tokenList.dai),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(usdxAssetId, 1e8);

    // add WBTC
    // lt, lb, borrowable, collateral
    reserveConfigs[0] = Spoke.ReserveConfig(0.75e4, 0, true, true);
    reserveConfigs[1] = Spoke.ReserveConfig(0.8e4, 0, true, true);
    reserveConfigs[2] = Spoke.ReserveConfig(0.77e4, 0, true, true);
    Utils.addAssetAndSpokes(
      hub,
      address(tokenList.wbtc),
      DataTypes.AssetConfig({decimals: 8, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(wbtcAssetId, 50_000e8);

    irStrategy.setInterestRateParams(
      wethAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    irStrategy.setInterestRateParams(
      usdxAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    irStrategy.setInterestRateParams(
      wbtcAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    irStrategy.setInterestRateParams(
      daiAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
  }

  /// @dev pseudo random randomizer
  function randomizer(uint256 min, uint256 max, uint256 salt) internal view returns (uint256) {
    return
      (uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, salt))) %
        (max - min)) + min;
  }
}
