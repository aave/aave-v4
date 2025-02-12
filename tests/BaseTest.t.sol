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
  event Borrowed(uint256 indexed assetId, uint256 amount, address indexed user);
  event Repaid(uint256 indexed assetId, uint256 amount, address indexed user);
  event Supplied(uint256 indexed assetId, uint256 amount, address indexed user);
  event Withdrawn(uint256 indexed assetId, uint256 amount, address indexed user);
  event ReserveConfigUpdated(
    uint256 indexed assetId,
    uint256 lt,
    uint256 lb,
    uint256 liquidityPremium,
    bool borrowable,
    bool collateral
  );
  event UsingAsCollateral(uint256 indexed assetId, bool usingAsCollateral, address indexed user);
}

library TestErrors {
  // Aave
  // LiquidityHub
  bytes constant NOT_AVAILABLE_LIQUIDITY = 'NOT_AVAILABLE_LIQUIDITY';
  bytes constant ASSET_NOT_ACTIVE = 'ASSET_NOT_ACTIVE';
  bytes constant ASSET_NOT_LISTED = 'ASSET_NOT_LISTED';
  bytes constant INVALID_AMOUNT = 'INVALID_AMOUNT';
  bytes constant INVALID_SUPPLY_AMOUNT = 'INVALID_SUPPLY_AMOUNT';
  bytes constant INVALID_DRAW_AMOUNT = 'INVALID_DRAW_AMOUNT';
  bytes constant INVALID_WITHDRAW_AMOUNT = 'INVALID_WITHDRAW_AMOUNT';
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

  uint256 internal constant MAX_SUPPLY_AMOUNT = 1e30;

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
  // TODO: remove after migrating to other mock users
  address internal USER1 = makeAddr('USER1');
  address internal USER2 = makeAddr('USER2');

  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');
  address internal carol = makeAddr('carol');

  TokenList internal tokenList;
  uint256 internal wethAssetId = 0;
  uint256 internal usdxAssetId = 1;
  uint256 internal daiAssetId = 2;
  uint256 internal wbtcAssetId = 3;
  uint256 internal dai2AssetId = 4;

  uint256 internal mintAmount_WETH = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_USDX = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_DAI = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_WBTC = MAX_SUPPLY_AMOUNT;

  struct TokenList {
    WETH9 weth;
    TestnetERC20 usdx;
    TestnetERC20 dai;
    TestnetERC20 wbtc;
  }

  struct SpokeInfo {
    ReserveInfo weth;
    ReserveInfo wbtc;
    ReserveInfo dai;
    ReserveInfo usdx;
    ReserveInfo dai2; // Special case: dai listed twice on hub and spoke2 (unique assetIds)
  }

  struct ReserveInfo {
    uint256 reserveId;
    uint256 liquidityPremium;
  }

  mapping(Spoke => SpokeInfo) internal spokeInfo;

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

    address[3] memory users = [alice, bob, carol];

    for (uint256 x; x < users.length; ++x) {
      tokenList.usdx.mint(users[x], mintAmount_USDX);
      tokenList.dai.mint(users[x], mintAmount_DAI);
      tokenList.wbtc.mint(users[x], mintAmount_WBTC);
      deal(address(tokenList.weth), users[x], mintAmount_WETH);

      vm.startPrank(users[x]);
      tokenList.weth.approve(address(hub), type(uint256).max);
      tokenList.usdx.approve(address(hub), type(uint256).max);
      tokenList.dai.approve(address(hub), type(uint256).max);
      tokenList.wbtc.approve(address(hub), type(uint256).max);
      vm.stopPrank();
    }
  }

  function spokeMintAndApprove() internal {
    uint256 spokeMintAmount_USDX = 100_000e6;
    uint256 spokeMintAmount_DAI = 1e60;
    uint256 spokeMintAmount_WBTC = 100e8;
    uint256 spokeMintAmount_WETH = 100e18;
    address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];

    for (uint256 x; x < spokes.length; ++x) {
      tokenList.usdx.mint(spokes[x], spokeMintAmount_USDX);
      tokenList.dai.mint(spokes[x], spokeMintAmount_DAI);
      tokenList.wbtc.mint(spokes[x], spokeMintAmount_WBTC);
      deal(address(tokenList.weth), spokes[x], spokeMintAmount_WETH);

      vm.startPrank(spokes[x]);
      tokenList.weth.approve(address(hub), type(uint256).max);
      tokenList.usdx.approve(address(hub), type(uint256).max);
      tokenList.dai.approve(address(hub), type(uint256).max);
      tokenList.wbtc.approve(address(hub), type(uint256).max);
      vm.stopPrank();
    }
  }
  function configureTokenList() internal {
    address[] memory spokes = new address[](3);
    spokes[0] = address(spoke1);
    spokes[1] = address(spoke2);
    spokes[2] = address(spoke3);
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });

    // Add all assets to the Liquidity Hub

    // add WETH
    hub.addAsset(
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      address(tokenList.weth)
    );
    oracle.setAssetPrice(wethAssetId, 2000e8);

    // add USDX
    hub.addAsset(
      DataTypes.AssetConfig({decimals: 6, active: true, irStrategy: address(irStrategy)}),
      address(tokenList.usdx)
    );
    oracle.setAssetPrice(usdxAssetId, 1e8);

    // add DAI
    hub.addAsset(
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      address(tokenList.dai)
    );
    oracle.setAssetPrice(daiAssetId, 1e8);

    // add WBTC
    hub.addAsset(
      DataTypes.AssetConfig({decimals: 8, active: true, irStrategy: address(irStrategy)}),
      address(tokenList.wbtc)
    );
    oracle.setAssetPrice(wbtcAssetId, 50_000e8);

    // Spoke 1 reserve configs
    Spoke.ReserveConfig memory wethConfig = Spoke.ReserveConfig({
      lt: 0.8e4,
      lb: 0,
      liquidityPremium: 0,
      borrowable: true,
      collateral: true
    });
    Spoke.ReserveConfig memory wbtcConfig = Spoke.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      liquidityPremium: 10,
      borrowable: true,
      collateral: true
    });
    Spoke.ReserveConfig memory daiConfig = Spoke.ReserveConfig({
      lt: 0.78e4,
      lb: 0,
      liquidityPremium: 20,
      borrowable: true,
      collateral: true
    });
    Spoke.ReserveConfig memory usdxConfig = Spoke.ReserveConfig({
      lt: 0.78e4,
      lb: 0,
      liquidityPremium: 50,
      borrowable: true,
      collateral: true
    });

    spokeInfo[spoke1].weth.reserveId = spoke1.addReserve(
      wethAssetId,
      wethConfig,
      address(tokenList.weth)
    );
    spokeInfo[spoke1].weth.liquidityPremium = wethConfig.liquidityPremium;
    spokeInfo[spoke1].wbtc.reserveId = spoke1.addReserve(
      wbtcAssetId,
      wbtcConfig,
      address(tokenList.wbtc)
    );
    spokeInfo[spoke1].wbtc.liquidityPremium = wbtcConfig.liquidityPremium;
    spokeInfo[spoke1].dai.reserveId = spoke1.addReserve(
      daiAssetId,
      daiConfig,
      address(tokenList.dai)
    );
    spokeInfo[spoke1].dai.liquidityPremium = daiConfig.liquidityPremium;
    spokeInfo[spoke1].usdx.reserveId = spoke1.addReserve(
      usdxAssetId,
      usdxConfig,
      address(tokenList.usdx)
    );
    spokeInfo[spoke1].usdx.liquidityPremium = usdxConfig.liquidityPremium;

    hub.addSpoke(wethAssetId, spokeConfig, address(spoke1));
    hub.addSpoke(wbtcAssetId, spokeConfig, address(spoke1));
    hub.addSpoke(daiAssetId, spokeConfig, address(spoke1));
    hub.addSpoke(usdxAssetId, spokeConfig, address(spoke1));

    // Spoke 2 reserve configs
    wbtcConfig = Spoke.ReserveConfig({
      lt: 0.8e4,
      lb: 0,
      liquidityPremium: 0,
      borrowable: true,
      collateral: true
    });
    wethConfig = Spoke.ReserveConfig({
      lt: 0.76e4,
      lb: 0,
      liquidityPremium: 10,
      borrowable: true,
      collateral: true
    });
    daiConfig = Spoke.ReserveConfig({
      lt: 0.72e4,
      lb: 0,
      liquidityPremium: 20,
      borrowable: true,
      collateral: true
    });
    usdxConfig = Spoke.ReserveConfig({
      lt: 0.72e4,
      lb: 0,
      liquidityPremium: 50,
      borrowable: true,
      collateral: true
    });

    spokeInfo[spoke2].wbtc.reserveId = spoke2.addReserve(
      wbtcAssetId,
      wbtcConfig,
      address(tokenList.wbtc)
    );
    spokeInfo[spoke2].wbtc.liquidityPremium = wbtcConfig.liquidityPremium;
    spokeInfo[spoke2].weth.reserveId = spoke2.addReserve(
      wethAssetId,
      wethConfig,
      address(tokenList.weth)
    );
    spokeInfo[spoke2].weth.liquidityPremium = wethConfig.liquidityPremium;
    spokeInfo[spoke2].dai.reserveId = spoke2.addReserve(
      daiAssetId,
      daiConfig,
      address(tokenList.dai)
    );
    spokeInfo[spoke2].dai.liquidityPremium = daiConfig.liquidityPremium;
    spokeInfo[spoke2].usdx.reserveId = spoke2.addReserve(
      usdxAssetId,
      usdxConfig,
      address(tokenList.usdx)
    );
    spokeInfo[spoke2].usdx.liquidityPremium = usdxConfig.liquidityPremium;

    hub.addSpoke(wbtcAssetId, spokeConfig, address(spoke2));
    hub.addSpoke(wethAssetId, spokeConfig, address(spoke2));
    hub.addSpoke(daiAssetId, spokeConfig, address(spoke2));
    hub.addSpoke(usdxAssetId, spokeConfig, address(spoke2));

    // Spoke 3 reserve configs
    daiConfig = Spoke.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      liquidityPremium: 0,
      borrowable: true,
      collateral: true
    });
    usdxConfig = Spoke.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      liquidityPremium: 10,
      borrowable: true,
      collateral: true
    });
    wethConfig = Spoke.ReserveConfig({
      lt: 0.79e4,
      lb: 0,
      liquidityPremium: 20,
      borrowable: true,
      collateral: true
    });
    wbtcConfig = Spoke.ReserveConfig({
      lt: 0.77e4,
      lb: 0,
      liquidityPremium: 50,
      borrowable: true,
      collateral: true
    });

    spokeInfo[spoke3].dai.reserveId = spoke3.addReserve(
      daiAssetId,
      daiConfig,
      address(tokenList.dai)
    );
    spokeInfo[spoke3].dai.liquidityPremium = daiConfig.liquidityPremium;
    spokeInfo[spoke3].usdx.reserveId = spoke3.addReserve(
      usdxAssetId,
      usdxConfig,
      address(tokenList.usdx)
    );
    spokeInfo[spoke3].usdx.liquidityPremium = usdxConfig.liquidityPremium;
    spokeInfo[spoke3].weth.reserveId = spoke3.addReserve(
      wethAssetId,
      wethConfig,
      address(tokenList.weth)
    );
    spokeInfo[spoke3].weth.liquidityPremium = wethConfig.liquidityPremium;
    spokeInfo[spoke3].wbtc.reserveId = spoke3.addReserve(
      wbtcAssetId,
      wbtcConfig,
      address(tokenList.wbtc)
    );
    spokeInfo[spoke3].wbtc.liquidityPremium = wbtcConfig.liquidityPremium;

    hub.addSpoke(daiAssetId, spokeConfig, address(spoke3));
    hub.addSpoke(usdxAssetId, spokeConfig, address(spoke3));
    hub.addSpoke(wethAssetId, spokeConfig, address(spoke3));
    hub.addSpoke(wbtcAssetId, spokeConfig, address(spoke3));

    // Spoke 2 to have an extra dai reserve
    hub.addAsset(
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      address(tokenList.dai)
    );
    oracle.setAssetPrice(dai2AssetId, 1e8);
    daiConfig = Spoke.ReserveConfig({
      lt: 0.70e4,
      lb: 0,
      liquidityPremium: 100,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke2].dai2.reserveId = spoke2.addReserve(
      dai2AssetId,
      daiConfig,
      address(tokenList.dai)
    );
    spokeInfo[spoke2].dai2.liquidityPremium = daiConfig.liquidityPremium;
    hub.addSpoke(dai2AssetId, spokeConfig, address(spoke2));

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
    irStrategy.setInterestRateParams(
      dai2AssetId,
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
    return (uint256(keccak256(abi.encodePacked(vm.getBlockTimestamp(), salt))) % (max - min)) + min;
  }
}
