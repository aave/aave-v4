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
  using PercentageMath for uint256;

  uint256 internal constant MAX_SUPPLY_AMOUNT = 1e30;
  uint256 internal constant MAX_TOKEN_DECIMALS_SUPPORTED = 18;
  uint256 internal constant MAX_SUPPLY_ASSET_UNITS =
    MAX_SUPPLY_AMOUNT / 10 ** MAX_TOKEN_DECIMALS_SUPPORTED;
  uint256 internal MAX_SUPPLY_AMOUNT_USDX;
  uint256 internal MAX_SUPPLY_AMOUNT_DAI;
  uint256 internal MAX_SUPPLY_AMOUNT_WBTC;
  uint256 internal MAX_SUPPLY_AMOUNT_WETH;
  uint32 internal constant MAX_RISK_PREMIUM_BPS = 1000_00;
  uint256 internal constant MAX_BORROW_RATE = 1000_00; // matches DefaultReserveInterestRateStrategy
  uint256 internal constant MAX_SKIP_TIME = 10_000 days;

  IERC20 internal usdc;
  IERC20 internal dai;
  IERC20 internal usdt;
  IERC20 internal eth;
  IERC20 internal wbtc;

  MockPriceOracle internal oracle;
  ILiquidityHub internal hub;
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

  address internal HUB_ADMIN = makeAddr('HUB_ADMIN');
  address internal SPOKE_ADMIN = makeAddr('SPOKE_ADMIN');

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

    // todo: set up admin role when access controls impl
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

    MAX_SUPPLY_AMOUNT_USDX = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.usdx.decimals();
    MAX_SUPPLY_AMOUNT_WETH = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.weth.decimals();
    MAX_SUPPLY_AMOUNT_DAI = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.dai.decimals();
    MAX_SUPPLY_AMOUNT_WBTC = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.wbtc.decimals();

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
    vm.startPrank(HUB_ADMIN);
    // add WETH
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: 18,
        active: true,
        paused: false,
        frozen: false,
        irStrategy: irStrategy
      }),
      address(tokenList.weth)
    );
    oracle.setAssetPrice(wethAssetId, 2000e8);

    // add USDX
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: 6,
        active: true,
        paused: false,
        frozen: false,
        irStrategy: irStrategy
      }),
      address(tokenList.usdx)
    );
    oracle.setAssetPrice(usdxAssetId, 1e8);

    // add DAI
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: 18,
        active: true,
        paused: false,
        frozen: false,
        irStrategy: irStrategy
      }),
      address(tokenList.dai)
    );
    oracle.setAssetPrice(daiAssetId, 1e8);

    // add WBTC
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: 8,
        active: true,
        paused: false,
        frozen: false,
        irStrategy: irStrategy
      }),
      address(tokenList.wbtc)
    );
    oracle.setAssetPrice(wbtcAssetId, 50_000e8);

    // Spoke 1 reserve configs
    DataTypes.ReserveConfig memory wethConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 80_00,
      liquidationBonus: 0,
      liquidityPremium: 15_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory wbtcConfig = DataTypes.ReserveConfig({
      decimals: 8,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 75_00,
      liquidationBonus: 0,
      liquidityPremium: 5_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory daiConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 78_00,
      liquidationBonus: 0,
      liquidityPremium: 20_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory usdxConfig = DataTypes.ReserveConfig({
      decimals: 6,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 78_00,
      liquidationBonus: 0,
      liquidityPremium: 50_00,
      borrowable: true,
      collateral: true
    });

    spokeInfo[spoke1].weth.reserveId = spoke1.addReserve(wethAssetId, wethConfig);
    spokeInfo[spoke1].weth.liquidityPremium = wethConfig.liquidityPremium;
    spokeInfo[spoke1].wbtc.reserveId = spoke1.addReserve(wbtcAssetId, wbtcConfig);
    spokeInfo[spoke1].wbtc.liquidityPremium = wbtcConfig.liquidityPremium;
    spokeInfo[spoke1].dai.reserveId = spoke1.addReserve(daiAssetId, daiConfig);
    spokeInfo[spoke1].dai.liquidityPremium = daiConfig.liquidityPremium;
    spokeInfo[spoke1].usdx.reserveId = spoke1.addReserve(usdxAssetId, usdxConfig);
    spokeInfo[spoke1].usdx.liquidityPremium = usdxConfig.liquidityPremium;

    hub.addSpoke(wethAssetId, spokeConfig, address(spoke1));
    hub.addSpoke(wbtcAssetId, spokeConfig, address(spoke1));
    hub.addSpoke(daiAssetId, spokeConfig, address(spoke1));
    hub.addSpoke(usdxAssetId, spokeConfig, address(spoke1));

    // Spoke 2 reserve configs
    wbtcConfig = DataTypes.ReserveConfig({
      decimals: 8,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 80_00,
      liquidationBonus: 0,
      liquidityPremium: 0,
      borrowable: true,
      collateral: true
    });
    wethConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 76_00,
      liquidationBonus: 0,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });
    daiConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 72_00,
      liquidationBonus: 0,
      liquidityPremium: 20_00,
      borrowable: true,
      collateral: true
    });
    usdxConfig = DataTypes.ReserveConfig({
      decimals: 6,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 72_00,
      liquidationBonus: 0,
      liquidityPremium: 50_00,
      borrowable: true,
      collateral: true
    });

    spokeInfo[spoke2].wbtc.reserveId = spoke2.addReserve(wbtcAssetId, wbtcConfig);
    spokeInfo[spoke2].wbtc.liquidityPremium = wbtcConfig.liquidityPremium;
    spokeInfo[spoke2].weth.reserveId = spoke2.addReserve(wethAssetId, wethConfig);
    spokeInfo[spoke2].weth.liquidityPremium = wethConfig.liquidityPremium;
    spokeInfo[spoke2].dai.reserveId = spoke2.addReserve(daiAssetId, daiConfig);
    spokeInfo[spoke2].dai.liquidityPremium = daiConfig.liquidityPremium;
    spokeInfo[spoke2].usdx.reserveId = spoke2.addReserve(usdxAssetId, usdxConfig);
    spokeInfo[spoke2].usdx.liquidityPremium = usdxConfig.liquidityPremium;

    hub.addSpoke(wbtcAssetId, spokeConfig, address(spoke2));
    hub.addSpoke(wethAssetId, spokeConfig, address(spoke2));
    hub.addSpoke(daiAssetId, spokeConfig, address(spoke2));
    hub.addSpoke(usdxAssetId, spokeConfig, address(spoke2));

    // Spoke 3 reserve configs
    daiConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 75_00,
      liquidationBonus: 0,
      liquidityPremium: 0,
      borrowable: true,
      collateral: true
    });
    usdxConfig = DataTypes.ReserveConfig({
      decimals: 6,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 75_00,
      liquidationBonus: 0,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });
    wethConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 79_00,
      liquidationBonus: 0,
      liquidityPremium: 20_00,
      borrowable: true,
      collateral: true
    });
    wbtcConfig = DataTypes.ReserveConfig({
      decimals: 8,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 77_00,
      liquidationBonus: 0,
      liquidityPremium: 50_00,
      borrowable: true,
      collateral: true
    });

    spokeInfo[spoke3].dai.reserveId = spoke3.addReserve(daiAssetId, daiConfig);
    spokeInfo[spoke3].dai.liquidityPremium = daiConfig.liquidityPremium;
    spokeInfo[spoke3].usdx.reserveId = spoke3.addReserve(usdxAssetId, usdxConfig);
    spokeInfo[spoke3].usdx.liquidityPremium = usdxConfig.liquidityPremium;
    spokeInfo[spoke3].weth.reserveId = spoke3.addReserve(wethAssetId, wethConfig);
    spokeInfo[spoke3].weth.liquidityPremium = wethConfig.liquidityPremium;
    spokeInfo[spoke3].wbtc.reserveId = spoke3.addReserve(wbtcAssetId, wbtcConfig);
    spokeInfo[spoke3].wbtc.liquidityPremium = wbtcConfig.liquidityPremium;

    hub.addSpoke(daiAssetId, spokeConfig, address(spoke3));
    hub.addSpoke(usdxAssetId, spokeConfig, address(spoke3));
    hub.addSpoke(wethAssetId, spokeConfig, address(spoke3));
    hub.addSpoke(wbtcAssetId, spokeConfig, address(spoke3));

    // Spoke 2 to have an extra dai reserve
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: 18,
        active: true,
        frozen: false,
        paused: false,
        irStrategy: irStrategy
      }),
      address(tokenList.dai)
    );
    oracle.setAssetPrice(dai2AssetId, 1e8);
    daiConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 70_00,
      liquidationBonus: 0,
      liquidityPremium: 100_00,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke2].dai2.reserveId = spoke2.addReserve(dai2AssetId, daiConfig);
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
    vm.stopPrank();
  }

  function updateAssetActive(ILiquidityHub hub, uint256 assetId, bool newActiveFlag) internal {
    DataTypes.AssetConfig memory assetConfig = hub.getAsset(assetId).config;
    assetConfig.active = newActiveFlag;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, assetConfig);
  }

  function updateAssetPaused(ILiquidityHub hub, uint256 assetId, bool newPausedFlag) internal {
    DataTypes.AssetConfig memory assetConfig = hub.getAsset(assetId).config;
    assetConfig.paused = newPausedFlag;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, assetConfig);
  }

  function updateAssetFrozen(ILiquidityHub hub, uint256 assetId, bool newFrozenFlag) internal {
    DataTypes.AssetConfig memory assetConfig = hub.getAsset(assetId).config;
    assetConfig.frozen = newFrozenFlag;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, assetConfig);
  }

  function updateReserveFrozenFlag(ISpoke spoke, uint256 reserveId, bool newFrozenFlag) internal {
    DataTypes.ReserveConfig memory config = spoke.getReserve(reserveId).config;
    config.frozen = newFrozenFlag;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);
  }

  function updateReservePausedFlag(ISpoke spoke, uint256 reserveId, bool newPausedFlag) internal {
    DataTypes.ReserveConfig memory config = spoke.getReserve(reserveId).config;
    config.paused = newPausedFlag;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);
  }

  function updateReserveActiveFlag(ISpoke spoke, uint256 reserveId, bool newActiveFlag) internal {
    DataTypes.ReserveConfig memory config = spoke.getReserve(reserveId).config;
    config.active = newActiveFlag;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);
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

  function updateCollateralFactor(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor
  ) internal {
    DataTypes.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.collateralFactor = newCollateralFactor;
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateCollateralFlag(ISpoke spoke, uint256 reserveId, bool newCollateralFlag) internal {
    DataTypes.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.collateral = newCollateralFlag;
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateReserveBorrowableFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newBorrowable
  ) internal {
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
  function _usdxReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdx.reserveId;
  }

  // assumes spoke has dai supported
  function _daiReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }

  // assumes spoke has weth supported
  function _wethReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].weth.reserveId;
  }

  // assumes spoke has wbtc supported
  function _wbtcReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].wbtc.reserveId;
  }

  // assumes spoke has dai2 supported
  function _dai2ReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai2.reserveId;
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
    return spoke.getUserPosition(reserveId, user);
  }

  function getReserveInfo(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (DataTypes.Reserve memory) {
    return spoke.getReserve(reserveId);
  }

  function getAssetInfo(uint256 assetId) internal view returns (DataTypes.Asset memory) {
    revert('implement me');

    // DataTypes.Asset memory asset;
    // asset.id = assetId;
    // asset.suppliedShares = hub.getAssetSuppliedShares(assetId);
    // asset.availableLiquidity = hub.getAvailableLiquidity(assetId);
    // (asset.baseDebt, asset.outstandingPremium) = hub.getAssetDebt(assetId);
    // asset.baseBorrowIndex = hub.getAsset(assetId).baseBorrowIndex;
    // asset.baseBorrowRate = hub.getBaseInterestRate(assetId);
    // asset.riskPremium = hub.getAssetRiskPremium(assetId);
    // asset.lastUpdateTimestamp = hub.getAsset(assetId).lastUpdateTimestamp;
    // asset.config = hub.getAssetConfig(assetId);
    // return asset;
  }

  function getAssetByReserveId(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint256, IERC20) {
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

  /// @dev Helper function to calculate a new price based on a percentage change
  function calcNewPrice(uint256 price, uint256 percent) public pure returns (uint256) {
    if (percent == 0) return price;
    return price.percentMul(percent);
  }

  /// @dev Helper function to check consistent supplied amounts within accounting
  function _checkSuppliedAmounts(
    uint256 assetId,
    uint256 reserveId,
    ISpoke spoke,
    address user,
    uint256 expectedSuppliedAmount,
    string memory when
  ) internal {
    uint256 expectedSuppliedShares = hub.convertToSuppliedShares(assetId, expectedSuppliedAmount);
    assertEq(
      hub.getAssetSuppliedShares(assetId),
      expectedSuppliedShares,
      string(abi.encodePacked('asset supplied shares ', when))
    );
    assertEq(
      hub.getAssetSuppliedAmount(assetId),
      expectedSuppliedAmount,
      string(abi.encodePacked('asset supplied amount ', when))
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke)),
      expectedSuppliedShares,
      string(abi.encodePacked('spoke supplied shares ', when))
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke)),
      expectedSuppliedAmount,
      string(abi.encodePacked('spoke supplied amount ', when))
    );
    assertEq(
      spoke.getReserveSuppliedShares(reserveId),
      expectedSuppliedShares,
      string(abi.encodePacked('reserve supplied shares ', when))
    );
    assertEq(
      spoke.getReserveSuppliedAmount(reserveId),
      expectedSuppliedAmount,
      string(abi.encodePacked('reserve supplied amount ', when))
    );
    assertEq(
      spoke.getUserSuppliedShares(reserveId, user),
      expectedSuppliedShares,
      string(abi.encodePacked('user supplied shares ', when))
    );
    assertEq(
      spoke.getUserSuppliedAmount(reserveId, user),
      expectedSuppliedAmount,
      string(abi.encodePacked('user supplied amount ', when))
    );
  }
}
