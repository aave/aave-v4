// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {LiquidityHub, ILiquidityHub} from 'src/contracts/LiquidityHub.sol';
import {Spoke, ISpoke} from 'src/contracts/Spoke.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {DefaultReserveInterestRateStrategy, IDefaultInterestRateStrategy, IReserveInterestRateStrategy} from 'src/contracts/DefaultReserveInterestRateStrategy.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {Utils} from './Utils.sol';

// mocks
import {TestnetERC20} from './mocks/TestnetERC20.sol';
import {MockERC20} from './mocks/MockERC20.sol';
import {MockPriceOracle, IPriceOracle} from './mocks/MockPriceOracle.sol';

// dependencies
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';

abstract contract Base is Test {
  using WadRayMath for uint256;
  using SharesMath for uint256;

  uint256 internal constant MAX_SUPPLY_AMOUNT = 1e30;
  uint32 internal constant MAX_RISK_PREMIUM_BPS = 1000_00;
  uint256 internal constant MAX_BORROW_RATE = 1000_00; // matches DefaultReserveInterestRateStrategy
  uint256 internal constant MAX_SKIP_TIME = 10_000 days;

  IERC20 internal usdc;
  IERC20 internal dai;
  IERC20 internal usdt;
  IERC20 internal eth;
  IERC20 internal wbtc;

  MockPriceOracle internal oracle;
  LiquidityHub internal hub;
  ISpoke internal spoke1;
  ISpoke internal spoke2;
  ISpoke internal spoke3;
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
    uint256 MAX_RESERVE_ID;
  }

  struct ReserveInfo {
    uint256 reserveId;
    uint256 liquidityPremium;
  }

  struct DebtAccounting {
    uint256 cumulativeDebt;
    uint256 baseDebt;
    uint256 outstandingPremium;
  }

  mapping(ISpoke => SpokeInfo) internal spokeInfo;

  function setUp() public virtual {
    deployFixtures();
  }

  function deployFixtures() internal {
    oracle = new MockPriceOracle();
    creditLineIRStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
    irStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
    hub = new LiquidityHub();
    spoke1 = ISpoke(new Spoke(address(hub), address(oracle)));
    spoke2 = ISpoke(new Spoke(address(hub), address(oracle)));
    spoke3 = ISpoke(new Spoke(address(hub), address(oracle)));
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
    DataTypes.ReserveConfig memory wethConfig = DataTypes.ReserveConfig({
      lt: 0.8e4,
      lb: 0,
      liquidityPremium: 15_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory wbtcConfig = DataTypes.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      liquidityPremium: 50_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory daiConfig = DataTypes.ReserveConfig({
      lt: 0.78e4,
      lb: 0,
      liquidityPremium: 20_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory usdxConfig = DataTypes.ReserveConfig({
      lt: 0.78e4,
      lb: 0,
      liquidityPremium: 50_00,
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
    wbtcConfig = DataTypes.ReserveConfig({
      lt: 0.8e4,
      lb: 0,
      liquidityPremium: 0,
      borrowable: true,
      collateral: true
    });
    wethConfig = DataTypes.ReserveConfig({
      lt: 0.76e4,
      lb: 0,
      liquidityPremium: 10,
      borrowable: true,
      collateral: true
    });
    daiConfig = DataTypes.ReserveConfig({
      lt: 0.72e4,
      lb: 0,
      liquidityPremium: 20,
      borrowable: true,
      collateral: true
    });
    usdxConfig = DataTypes.ReserveConfig({
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
    daiConfig = DataTypes.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      liquidityPremium: 0,
      borrowable: true,
      collateral: true
    });
    usdxConfig = DataTypes.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      liquidityPremium: 10,
      borrowable: true,
      collateral: true
    });
    wethConfig = DataTypes.ReserveConfig({
      lt: 0.79e4,
      lb: 0,
      liquidityPremium: 20,
      borrowable: true,
      collateral: true
    });
    wbtcConfig = DataTypes.ReserveConfig({
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
    daiConfig = DataTypes.ReserveConfig({
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

  function updateAssetActive(ILiquidityHub hub, uint256 assetId, bool newActive) internal {
    DataTypes.AssetConfig memory assetConfig = hub.getAsset(assetId).config;
    assetConfig.active = newActive;
    hub.updateAssetConfig(assetId, assetConfig);
  }

  function setUsingAsCollateral(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    bool usingAsCollateral
  ) internal {
    vm.prank(user);
    spoke.setUsingAsCollateral(reserveId, usingAsCollateral);
  }

  function updateLiquidationThreshold(ISpoke spoke, uint256 reserveId, uint256 newLt) internal {
    DataTypes.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.lt = newLt;
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateCollateral(ISpoke spoke, uint256 reserveId, bool newCollateral) internal {
    DataTypes.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.collateral = newCollateral;
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateBorrowable(ISpoke spoke, uint256 reserveId, bool newBorrowable) internal {
    DataTypes.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.borrowable = newBorrowable;
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateLiquidityPremium(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newLiquidityPremium
  ) internal {
    DataTypes.ReserveConfig memory reserveConfig = spoke.getReserve(reserveId).config;
    reserveConfig.liquidityPremium = newLiquidityPremium;
    spoke.updateReserveConfig(reserveId, reserveConfig);
  }

  /// @dev pseudo random randomizer
  function randomizer(uint256 min, uint256 max, uint256) internal returns (uint256) {
    return vm.randomUint(min, max);
  }

  // assumes spoke has usdx supported
  function usdxReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdx.reserveId;
  }

  // assumes spoke has dai supported
  function daiReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }

  // assumes spoke has weth supported
  function wethReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].weth.reserveId;
  }

  // assumes spoke has wbtc supported
  function wbtcReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].wbtc.reserveId;
  }

  function updateDrawCap(
    ILiquidityHub hub,
    uint256 assetId,
    address spoke,
    uint256 newDrawCap
  ) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.drawCap = newDrawCap;
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  function getUserInfo(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (DataTypes.UserPosition memory) {
    DataTypes.UserPosition memory userPosition;
    userPosition.usingAsCollateral = spoke.getUsingAsCollateral(reserveId, user);
    (userPosition.baseDebt, userPosition.outstandingPremium) = spoke.getUserDebt(reserveId, user);
    userPosition.suppliedShares = spoke.getUserSuppliedShares(reserveId, user);
    userPosition.baseBorrowIndex = spoke.getUserBaseBorrowIndex(reserveId, user);
    userPosition.riskPremium = spoke.getUserRiskPremium(user);
    userPosition.lastUpdateTimestamp = spoke.getUserPosition(reserveId, user).lastUpdateTimestamp;
    return userPosition;
  }

  function getReserveInfo(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (DataTypes.Reserve memory) {
    DataTypes.Reserve memory reserveData = spoke.getReserve(reserveId);
    (reserveData.baseDebt, reserveData.outstandingPremium) = spoke.getReserveDebt(reserveId);
    reserveData.suppliedShares = spoke.getReserveSuppliedShares(reserveId);
    reserveData.riskPremium = spoke.getReserveRiskPremium(reserveId);
    reserveData.lastUpdateTimestamp = reserveData.lastUpdateTimestamp;
    reserveData.baseBorrowIndex = reserveData.baseBorrowIndex;
    return reserveData;
  }

  function getAssetInfo(ISpoke spoke, uint256 reserveId) internal view returns (uint256, IERC20) {
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    return (reserve.assetId, IERC20(reserve.asset));
  }

  function getWithdrawalLimit(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getUserSuppliedAmount(reserveId, user);
  }
}
