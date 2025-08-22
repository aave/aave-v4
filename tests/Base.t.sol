// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {stdError} from 'forge-std/StdError.sol';
import {stdMath} from 'forge-std/StdMath.sol';
import {Vm, VmSafe} from 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';
import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {Hub, IHub} from 'src/contracts/Hub.sol';
import {IHubBase} from 'src/interfaces/IHubBase.sol';
import {Spoke, ISpoke} from 'src/contracts/Spoke.sol';
import {ISpokeBase} from 'src/interfaces/ISpokeBase.sol';
import {AaveOracle, IAaveOracle} from 'src/contracts/AaveOracle.sol';
import {TreasurySpoke, ITreasurySpoke} from 'src/contracts/TreasurySpoke.sol';
import {HubConfigurator, IHubConfigurator} from 'src/contracts/HubConfigurator.sol';
import {SpokeConfigurator, ISpokeConfigurator} from 'src/contracts/SpokeConfigurator.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {Constants} from 'src/libraries/helpers/Constants.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {AssetInterestRateStrategy, IAssetInterestRateStrategy, IBasicInterestRateStrategy} from 'src/contracts/AssetInterestRateStrategy.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {Utils} from 'tests/Utils.sol';
import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';

// mocks
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockERC20} from 'tests/mocks/MockERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {PositionStatusWrapper} from 'tests/mocks/PositionStatusWrapper.sol';

// dependencies
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IERC5267} from 'src/dependencies/openzeppelin/IERC5267.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {AuthorityUtils} from 'src/dependencies/openzeppelin/AuthorityUtils.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {LibBit} from 'src/dependencies/solady/LibBit.sol';

abstract contract Base is Test {
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  uint256 internal constant MAX_SUPPLY_AMOUNT = 1e30;
  uint256 internal constant MAX_TOKEN_DECIMALS_SUPPORTED = 18;
  uint256 internal constant MAX_SUPPLY_ASSET_UNITS =
    MAX_SUPPLY_AMOUNT / 10 ** MAX_TOKEN_DECIMALS_SUPPORTED;
  uint256 internal MAX_SUPPLY_AMOUNT_USDX;
  uint256 internal MAX_SUPPLY_AMOUNT_DAI;
  uint256 internal MAX_SUPPLY_AMOUNT_WBTC;
  uint256 internal MAX_SUPPLY_AMOUNT_WETH;
  uint256 internal MAX_SUPPLY_AMOUNT_USDY;
  uint256 internal constant MAX_SUPPLY_IN_BASE_CURRENCY = 1e39;
  uint32 internal constant MAX_RISK_PREMIUM_BPS = 1000_00;
  uint256 internal constant MAX_BORROW_RATE = 1000_00; // matches AssetInterestRateStrategy
  uint256 internal constant MIN_OPTIMAL_RATIO = 1_00; // 1.00% in BPS, matches AssetInterestRateStrategy
  uint256 internal constant MAX_OPTIMAL_RATIO = 99_00; // 99.00% in BPS, matches AssetInterestRateStrategy
  uint256 internal constant MAX_SKIP_TIME = 10_000 days;
  uint32 internal constant MIN_LIQUIDATION_BONUS = uint32(PercentageMath.PERCENTAGE_FACTOR); // 100% == 0% bonus
  uint32 internal constant MAX_LIQUIDATION_BONUS = 150_00; // 50% bonus
  uint16 internal constant MAX_LIQUIDATION_BONUS_FACTOR = uint16(PercentageMath.PERCENTAGE_FACTOR); // 100%
  uint128 internal constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
  uint128 internal constant MIN_CLOSE_FACTOR = 1e18;
  uint128 internal constant MAX_CLOSE_FACTOR = 2e18;
  uint256 internal constant MAX_COLLATERAL_FACTOR = 100_00;
  uint256 internal constant MAX_ASSET_PRICE = 1e8 * 1e8; // $100M per token
  uint256 internal constant MAX_LIQUIDATION_PROTOCOL_FEE_PERCENTAGE =
    PercentageMath.PERCENTAGE_FACTOR;

  // TODO: remove after migrating to token list
  IERC20 internal usdc;
  IERC20 internal dai;
  IERC20 internal usdt;
  IERC20 internal eth;
  IERC20 internal wbtc;

  IAaveOracle internal oracle1;
  IAaveOracle internal oracle2;
  IAaveOracle internal oracle3;
  IHub internal hub1;
  ITreasurySpoke internal treasurySpoke;
  ISpoke internal spoke1;
  ISpoke internal spoke2;
  ISpoke internal spoke3;
  AssetInterestRateStrategy internal irStrategy;
  AccessManager internal accessManager;

  // TODO: remove after migrating to other mock users
  address internal USER1 = makeAddr('USER1');
  address internal USER2 = makeAddr('USER2');

  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');
  address internal carol = makeAddr('carol');
  address internal derl = makeAddr('derl');

  address internal ADMIN = makeAddr('ADMIN');
  address internal HUB_ADMIN = makeAddr('HUB_ADMIN');
  address internal SPOKE_ADMIN = makeAddr('SPOKE_ADMIN');
  address internal USER_POSITION_UPDATER = makeAddr('USER_POSITION_UPDATER');
  address internal TREASURY_ADMIN = makeAddr('TREASURY_ADMIN');
  address internal LIQUIDATOR = makeAddr('LIQUIDATOR');
  address internal POSITION_MANAGER = makeAddr('POSITION_MANAGER');

  TokenList internal tokenList;
  uint256 internal wethAssetId = 0;
  uint256 internal usdxAssetId = 1;
  uint256 internal daiAssetId = 2;
  uint256 internal wbtcAssetId = 3;
  uint256 internal usdyAssetId = 4;
  uint256 internal dai2AssetId = 5;

  uint256 internal mintAmount_WETH = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_USDX = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_DAI = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_WBTC = MAX_SUPPLY_AMOUNT;
  uint256 internal mintAmount_USDY = MAX_SUPPLY_AMOUNT;

  Decimals internal decimals = Decimals({usdx: 6, usdy: 18, dai: 18, wbtc: 8, weth: 18});

  struct Decimals {
    uint8 usdx;
    uint8 dai;
    uint8 wbtc;
    uint8 usdy;
    uint8 weth;
  }

  struct TokenList {
    WETH9 weth;
    TestnetERC20 usdx;
    TestnetERC20 dai;
    TestnetERC20 wbtc;
    TestnetERC20 usdy;
  }

  struct SpokeInfo {
    ReserveInfo weth;
    ReserveInfo wbtc;
    ReserveInfo dai;
    ReserveInfo usdx;
    ReserveInfo usdy;
    ReserveInfo dai2; // Special case: dai listed twice on hub and spoke2 (unique assetIds)
    uint256 MAX_RESERVE_ID;
  }

  struct ReserveInfo {
    uint256 reserveId;
    DataTypes.ReserveConfig reserveConfig;
    DataTypes.DynamicReserveConfig dynReserveConfig;
  }

  struct DrawnAccounting {
    uint256 totalOwed;
    uint256 drawn;
    uint256 premium;
  }

  // TODO: Seems this should be replaced with DrawnAccounting struct
  struct Debts {
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
  }

  struct AssetPosition {
    uint256 assetId;
    uint256 addedShares;
    uint256 addedAmount;
    uint256 drawnShares;
    uint256 drawn;
    uint256 premiumShares;
    uint256 premiumOffset;
    uint256 realizedPremium;
    uint256 premium;
    uint40 lastUpdateTimestamp;
    uint256 liquidity;
    uint256 drawnIndex;
    uint256 drawnRate;
  }

  struct SpokePosition {
    uint256 reserveId;
    uint256 assetId;
    uint256 addedShares;
    uint256 addedAmount;
    uint256 drawnShares;
    uint256 drawn;
    uint256 premiumShares;
    uint256 premiumOffset;
    uint256 realizedPremium;
    uint256 premium;
  }

  struct Reserve {
    uint256 reserveId;
    IHub hub;
    uint16 assetId;
    uint8 decimals;
    uint16 dynamicConfigKey; // key of the last reserve config
    bool paused;
    bool frozen;
    bool borrowable;
    uint24 collateralRisk;
  }

  mapping(ISpoke => SpokeInfo) internal spokeInfo;

  function setUp() public virtual {
    deployFixtures();
  }

  function deployFixtures() internal virtual {
    vm.startPrank(ADMIN);
    accessManager = new AccessManager(ADMIN);
    hub1 = new Hub(address(accessManager));
    irStrategy = new AssetInterestRateStrategy(address(hub1));
    spoke1 = ISpoke(new Spoke(address(accessManager)));
    spoke2 = ISpoke(new Spoke(address(accessManager)));
    spoke3 = ISpoke(new Spoke(address(accessManager)));
    oracle1 = IAaveOracle(new AaveOracle(address(spoke1), 8, 'Spoke 1 (USD)'));
    oracle2 = IAaveOracle(new AaveOracle(address(spoke2), 8, 'Spoke 2 (USD)'));
    oracle3 = IAaveOracle(new AaveOracle(address(spoke3), 8, 'Spoke 3 (USD)'));
    treasurySpoke = ITreasurySpoke(new TreasurySpoke(TREASURY_ADMIN, address(hub1)));
    dai = new MockERC20();
    eth = new MockERC20();
    usdc = new MockERC20();
    usdt = new MockERC20();
    wbtc = new MockERC20();
    vm.stopPrank();

    vm.label(address(spoke1), 'spoke1');
    vm.label(address(spoke2), 'spoke2');
    vm.label(address(spoke3), 'spoke3');

    setUpRoles(hub1, spoke1, accessManager);
    setUpRoles(hub1, spoke2, accessManager);
    setUpRoles(hub1, spoke3, accessManager);
  }

  function setUpRoles(IHub targetHub, ISpoke spoke, IAccessManager manager) internal virtual {
    vm.startPrank(ADMIN);
    // Grant roles with 0 delay
    manager.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    manager.grantRole(Roles.HUB_ADMIN_ROLE, HUB_ADMIN, 0);

    manager.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);
    manager.grantRole(Roles.SPOKE_ADMIN_ROLE, SPOKE_ADMIN, 0);

    manager.grantRole(Roles.USER_POSITION_UPDATER_ROLE, SPOKE_ADMIN, 0);
    manager.grantRole(Roles.USER_POSITION_UPDATER_ROLE, USER_POSITION_UPDATER, 0);

    // Grant responsibilities to roles
    {
      bytes4[] memory selectors = new bytes4[](8);
      selectors[0] = ISpoke.updateLiquidationConfig.selector;
      selectors[1] = ISpoke.addReserve.selector;
      selectors[2] = ISpoke.updateReserveConfig.selector;
      selectors[3] = ISpoke.updateDynamicReserveConfig.selector;
      selectors[4] = ISpoke.addDynamicReserveConfig.selector;
      selectors[5] = ISpoke.updatePositionManager.selector;
      selectors[6] = ISpoke.updateOracle.selector;
      selectors[7] = ISpoke.updateReservePriceSource.selector;
      manager.setTargetFunctionRole(address(spoke), selectors, Roles.SPOKE_ADMIN_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](2);
      selectors[0] = ISpoke.updateUserDynamicConfig.selector;
      selectors[1] = ISpoke.updateUserRiskPremium.selector;
      manager.setTargetFunctionRole(address(spoke), selectors, Roles.USER_POSITION_UPDATER_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](5);
      selectors[0] = IHub.addAsset.selector;
      selectors[1] = IHub.updateAssetConfig.selector;
      selectors[2] = IHub.addSpoke.selector;
      selectors[3] = IHub.updateSpokeConfig.selector;
      selectors[4] = IHub.setInterestRateData.selector;
      manager.setTargetFunctionRole(address(targetHub), selectors, Roles.HUB_ADMIN_ROLE);
    }
    vm.stopPrank();
  }

  function initEnvironment() internal {
    deployMintAndApproveTokenList();
    configureTokenList();
  }

  function deployMintAndApproveTokenList() internal {
    tokenList = TokenList(
      new WETH9(),
      new TestnetERC20('USDX', 'USDX', decimals.usdx),
      new TestnetERC20('DAI', 'DAI', decimals.dai),
      new TestnetERC20('WBTC', 'WBTC', decimals.wbtc),
      new TestnetERC20('USDY', 'USDY', decimals.usdy)
    );

    vm.label(address(tokenList.weth), 'WETH');
    vm.label(address(tokenList.usdx), 'USDX');
    vm.label(address(tokenList.dai), 'DAI');
    vm.label(address(tokenList.wbtc), 'WBTC');
    vm.label(address(tokenList.usdy), 'USDY');

    MAX_SUPPLY_AMOUNT_USDX = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.usdx.decimals();
    MAX_SUPPLY_AMOUNT_WETH = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.weth.decimals();
    MAX_SUPPLY_AMOUNT_DAI = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.dai.decimals();
    MAX_SUPPLY_AMOUNT_WBTC = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.wbtc.decimals();
    MAX_SUPPLY_AMOUNT_USDY = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.usdy.decimals();

    address[7] memory users = [
      alice,
      bob,
      carol,
      derl,
      LIQUIDATOR,
      TREASURY_ADMIN,
      POSITION_MANAGER
    ];

    for (uint256 x; x < users.length; ++x) {
      tokenList.usdx.mint(users[x], mintAmount_USDX);
      tokenList.dai.mint(users[x], mintAmount_DAI);
      tokenList.wbtc.mint(users[x], mintAmount_WBTC);
      tokenList.usdy.mint(users[x], mintAmount_USDY);
      deal(address(tokenList.weth), users[x], mintAmount_WETH);

      vm.startPrank(users[x]);
      tokenList.weth.approve(address(hub1), UINT256_MAX);
      tokenList.usdx.approve(address(hub1), UINT256_MAX);
      tokenList.dai.approve(address(hub1), UINT256_MAX);
      tokenList.wbtc.approve(address(hub1), UINT256_MAX);
      tokenList.usdy.approve(address(hub1), UINT256_MAX);
      vm.stopPrank();
    }
  }

  function spokeMintAndApprove() internal {
    uint256 spokeMintAmount_USDX = 100e6 * 10 ** tokenList.usdx.decimals();
    uint256 spokeMintAmount_DAI = 1e60;
    uint256 spokeMintAmount_WBTC = 100e6 * 10 ** tokenList.wbtc.decimals();
    uint256 spokeMintAmount_WETH = 100e6 * 10 ** tokenList.weth.decimals();
    uint256 spokeMintAmount_USDY = 100e6 * 10 ** tokenList.usdy.decimals();
    address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];

    for (uint256 x; x < spokes.length; ++x) {
      tokenList.usdx.mint(spokes[x], spokeMintAmount_USDX);
      tokenList.dai.mint(spokes[x], spokeMintAmount_DAI);
      tokenList.wbtc.mint(spokes[x], spokeMintAmount_WBTC);
      tokenList.usdy.mint(spokes[x], spokeMintAmount_USDY);
      deal(address(tokenList.weth), spokes[x], spokeMintAmount_WETH);

      vm.startPrank(spokes[x]);
      tokenList.weth.approve(address(hub1), UINT256_MAX);
      tokenList.usdx.approve(address(hub1), UINT256_MAX);
      tokenList.dai.approve(address(hub1), UINT256_MAX);
      tokenList.wbtc.approve(address(hub1), UINT256_MAX);
      tokenList.usdy.approve(address(hub1), UINT256_MAX);
      vm.stopPrank();
    }
  }

  function configureTokenList() internal {
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      active: true,
      addCap: Constants.MAX_CAP,
      drawCap: Constants.MAX_CAP
    });

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    // Add all assets to the Hub
    vm.startPrank(ADMIN);
    // add WETH
    hub1.addAsset(
      address(tokenList.weth),
      tokenList.weth.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.addSpoke(wethAssetId, address(treasurySpoke), spokeConfig);
    hub1.updateAssetConfig(
      wethAssetId,
      DataTypes.AssetConfig({
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      })
    );
    // add USDX
    hub1.addAsset(
      address(tokenList.usdx),
      tokenList.usdx.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.addSpoke(usdxAssetId, address(treasurySpoke), spokeConfig);
    hub1.updateAssetConfig(
      usdxAssetId,
      DataTypes.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      })
    );
    // add DAI
    hub1.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.addSpoke(daiAssetId, address(treasurySpoke), spokeConfig);
    hub1.updateAssetConfig(
      daiAssetId,
      DataTypes.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      })
    );
    // add WBTC
    hub1.addAsset(
      address(tokenList.wbtc),
      tokenList.wbtc.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.addSpoke(wbtcAssetId, address(treasurySpoke), spokeConfig);
    hub1.updateAssetConfig(
      wbtcAssetId,
      DataTypes.AssetConfig({
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      })
    );
    // add USDY
    hub1.addAsset(
      address(tokenList.usdy),
      tokenList.usdy.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.addSpoke(usdyAssetId, address(treasurySpoke), spokeConfig);
    hub1.updateAssetConfig(
      usdyAssetId,
      DataTypes.AssetConfig({
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      })
    );
    // add DAI again
    hub1.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.addSpoke(hub1.getAssetCount() - 1, address(treasurySpoke), spokeConfig);
    hub1.updateAssetConfig(
      hub1.getAssetCount() - 1,
      DataTypes.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      })
    );

    // configure oracle in spokes
    spoke1.updateOracle(address(oracle1));
    spoke2.updateOracle(address(oracle2));
    spoke3.updateOracle(address(oracle3));

    // Spoke 1 reserve configs
    spokeInfo[spoke1].weth.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 15_00
    });
    spokeInfo[spoke1].weth.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke1].wbtc.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 15_00
    });
    spokeInfo[spoke1].wbtc.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 75_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke1].dai.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 20_00
    });
    spokeInfo[spoke1].dai.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke1].usdx.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00
    });
    spokeInfo[spoke1].usdx.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke1].usdy.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00
    });
    spokeInfo[spoke1].usdy.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });

    spokeInfo[spoke1].weth.reserveId = spoke1.addReserve(
      address(hub1),
      wethAssetId,
      _deployMockPriceFeed(spoke1, 2000e8),
      spokeInfo[spoke1].weth.reserveConfig,
      spokeInfo[spoke1].weth.dynReserveConfig
    );
    spokeInfo[spoke1].wbtc.reserveId = spoke1.addReserve(
      address(hub1),
      wbtcAssetId,
      _deployMockPriceFeed(spoke1, 50_000e8),
      spokeInfo[spoke1].wbtc.reserveConfig,
      spokeInfo[spoke1].wbtc.dynReserveConfig
    );
    spokeInfo[spoke1].dai.reserveId = spoke1.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].dai.reserveConfig,
      spokeInfo[spoke1].dai.dynReserveConfig
    );
    spokeInfo[spoke1].usdx.reserveId = spoke1.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].usdx.reserveConfig,
      spokeInfo[spoke1].usdx.dynReserveConfig
    );
    spokeInfo[spoke1].usdy.reserveId = spoke1.addReserve(
      address(hub1),
      usdyAssetId,
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].usdy.reserveConfig,
      spokeInfo[spoke1].usdy.dynReserveConfig
    );

    hub1.addSpoke(wethAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(wbtcAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(daiAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(usdyAssetId, address(spoke1), spokeConfig);

    // Spoke 2 reserve configs
    spokeInfo[spoke2].wbtc.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 0
    });
    spokeInfo[spoke2].wbtc.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke2].weth.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 10_00
    });
    spokeInfo[spoke2].weth.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 76_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke2].dai.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 20_00
    });
    spokeInfo[spoke2].dai.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 72_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke2].usdx.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00
    });
    spokeInfo[spoke2].usdx.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 72_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke2].usdy.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00
    });
    spokeInfo[spoke2].usdy.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 72_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke2].dai2.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 100_00
    });
    spokeInfo[spoke2].dai2.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 70_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });

    spokeInfo[spoke2].wbtc.reserveId = spoke2.addReserve(
      address(hub1),
      wbtcAssetId,
      _deployMockPriceFeed(spoke2, 50_000e8),
      spokeInfo[spoke2].wbtc.reserveConfig,
      spokeInfo[spoke2].wbtc.dynReserveConfig
    );
    spokeInfo[spoke2].weth.reserveId = spoke2.addReserve(
      address(hub1),
      wethAssetId,
      _deployMockPriceFeed(spoke2, 2000e8),
      spokeInfo[spoke2].weth.reserveConfig,
      spokeInfo[spoke2].weth.dynReserveConfig
    );
    spokeInfo[spoke2].dai.reserveId = spoke2.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].dai.reserveConfig,
      spokeInfo[spoke2].dai.dynReserveConfig
    );
    spokeInfo[spoke2].usdx.reserveId = spoke2.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].usdx.reserveConfig,
      spokeInfo[spoke2].usdx.dynReserveConfig
    );
    spokeInfo[spoke2].usdy.reserveId = spoke2.addReserve(
      address(hub1),
      usdyAssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].usdy.reserveConfig,
      spokeInfo[spoke2].usdy.dynReserveConfig
    );
    spokeInfo[spoke2].dai2.reserveId = spoke2.addReserve(
      address(hub1),
      dai2AssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].dai2.reserveConfig,
      spokeInfo[spoke2].dai2.dynReserveConfig
    );

    hub1.addSpoke(wbtcAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(wethAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(daiAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(usdyAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(dai2AssetId, address(spoke2), spokeConfig);

    // Spoke 3 reserve configs
    spokeInfo[spoke3].dai.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 0
    });
    spokeInfo[spoke3].dai.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 75_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke3].usdx.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 10_00
    });
    spokeInfo[spoke3].usdx.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 75_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke3].weth.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 20_00
    });
    spokeInfo[spoke3].weth.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 79_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });
    spokeInfo[spoke3].wbtc.reserveConfig = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00
    });
    spokeInfo[spoke3].wbtc.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 77_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });

    spokeInfo[spoke3].dai.reserveId = spoke3.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke3, 1e8),
      spokeInfo[spoke3].dai.reserveConfig,
      spokeInfo[spoke3].dai.dynReserveConfig
    );
    spokeInfo[spoke3].usdx.reserveId = spoke3.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke3, 1e8),
      spokeInfo[spoke3].usdx.reserveConfig,
      spokeInfo[spoke3].usdx.dynReserveConfig
    );
    spokeInfo[spoke3].weth.reserveId = spoke3.addReserve(
      address(hub1),
      wethAssetId,
      _deployMockPriceFeed(spoke3, 2000e8),
      spokeInfo[spoke3].weth.reserveConfig,
      spokeInfo[spoke3].weth.dynReserveConfig
    );
    spokeInfo[spoke3].wbtc.reserveId = spoke3.addReserve(
      address(hub1),
      wbtcAssetId,
      _deployMockPriceFeed(spoke3, 50_000e8),
      spokeInfo[spoke3].wbtc.reserveConfig,
      spokeInfo[spoke3].wbtc.dynReserveConfig
    );

    hub1.addSpoke(daiAssetId, address(spoke3), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke3), spokeConfig);
    hub1.addSpoke(wethAssetId, address(spoke3), spokeConfig);
    hub1.addSpoke(wbtcAssetId, address(spoke3), spokeConfig);

    vm.stopPrank();
  }

  /* @dev Configures Hub 2 with the following assetIds:
   * 0: WETH
   * 1: USDX
   * 2: DAI
   * 3: WBTC
   */
  function hub2Fixture() internal returns (IHub, AssetInterestRateStrategy) {
    IAccessManager accessManager2 = new AccessManager(ADMIN);
    IHub hub2 = new Hub(address(accessManager2));
    AssetInterestRateStrategy hub2IrStrategy = new AssetInterestRateStrategy(address(hub2));

    // Configure IR Strategy for hub 2
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    vm.startPrank(ADMIN);

    // Add assets to the second hub
    // Add WETH
    hub2.addAsset(
      address(tokenList.weth),
      tokenList.weth.decimals(),
      address(treasurySpoke),
      address(hub2IrStrategy),
      encodedIrData
    );

    // Add USDX
    hub2.addAsset(
      address(tokenList.usdx),
      tokenList.usdx.decimals(),
      address(treasurySpoke),
      address(hub2IrStrategy),
      encodedIrData
    );

    // Add DAI
    hub2.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(hub2IrStrategy),
      encodedIrData
    );

    // Add WBTC
    hub2.addAsset(
      address(tokenList.wbtc),
      tokenList.wbtc.decimals(),
      address(treasurySpoke),
      address(hub2IrStrategy),
      encodedIrData
    );
    vm.stopPrank();

    setUpRoles(hub2, spoke1, accessManager2);

    return (hub2, hub2IrStrategy);
  }

  /* @dev Configures Hub 3 with the following assetIds:
   * 0: DAI
   * 1: USDX
   * 2: WBTC
   * 3: WETH
   */
  function hub3Fixture() internal returns (IHub, AssetInterestRateStrategy) {
    IAccessManager accessManager3 = new AccessManager(ADMIN);
    IHub hub3 = new Hub(address(accessManager3));
    AssetInterestRateStrategy hub3IrStrategy = new AssetInterestRateStrategy(address(hub3));

    // Configure IR Strategy for hub 3
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    vm.startPrank(ADMIN);
    // Add DAI
    hub3.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(hub3IrStrategy),
      encodedIrData
    );

    // Add USDX
    hub3.addAsset(
      address(tokenList.usdx),
      tokenList.usdx.decimals(),
      address(treasurySpoke),
      address(hub3IrStrategy),
      encodedIrData
    );

    // Add WBTC
    hub3.addAsset(
      address(tokenList.wbtc),
      tokenList.wbtc.decimals(),
      address(treasurySpoke),
      address(hub3IrStrategy),
      encodedIrData
    );

    // Add WETH
    hub3.addAsset(
      address(tokenList.weth),
      tokenList.weth.decimals(),
      address(treasurySpoke),
      address(hub3IrStrategy),
      encodedIrData
    );

    vm.stopPrank();

    setUpRoles(hub3, spoke1, accessManager3);

    return (hub3, hub3IrStrategy);
  }

  function updateAssetFeeReceiver(
    IHub hub,
    uint256 assetId,
    address newFeeReceiver
  ) internal pausePrank {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.feeReceiver = newFeeReceiver;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, config);

    assertEq(hub.getAssetConfig(assetId), config);
  }

  function updateAssetReinvestmentController(
    IHub hub,
    uint256 assetId,
    address newReinvestmentController
  ) internal pausePrank {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.reinvestmentController = newReinvestmentController;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, config);

    assertEq(hub.getAssetConfig(assetId), config);
  }

  function updateReserveFrozenFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newFrozenFlag
  ) internal pausePrank {
    DataTypes.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.frozen = newFrozenFlag;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function updateReservePausedFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newPausedFlag
  ) internal pausePrank {
    DataTypes.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.paused = newPausedFlag;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function updateLiquidationConfig(
    ISpoke spoke,
    DataTypes.LiquidationConfig memory config
  ) internal pausePrank {
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(config);

    assertEq(spoke.getLiquidationConfig(), config);
  }

  function updateLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint32 newLiquidationBonus
  ) internal pausePrank returns (uint16) {
    DataTypes.DynamicReserveConfig memory config = spoke.getDynamicReserveConfig(reserveId);
    config.liquidationBonus = newLiquidationBonus;

    vm.prank(SPOKE_ADMIN);
    uint16 configKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(spoke.getDynamicReserveConfig(reserveId), config);
    return configKey;
  }

  function updateLiquidationFee(
    ISpoke spoke,
    uint256 reserveId,
    uint16 newLiquidationFee
  ) internal pausePrank returns (uint16) {
    DataTypes.DynamicReserveConfig memory config = spoke.getDynamicReserveConfig(reserveId);
    config.liquidationFee = newLiquidationFee;

    vm.prank(SPOKE_ADMIN);
    uint16 configKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(spoke.getDynamicReserveConfig(reserveId), config);
    return configKey;
  }

  function updateCollateralFactor(
    ISpoke spoke,
    function(ISpoke) pure returns (uint256) reserveIdFn,
    uint256 newCollateralFactor
  ) internal pausePrank returns (uint16) {
    uint256 reserveId = reserveIdFn(spoke);
    DataTypes.DynamicReserveConfig memory config = spoke.getDynamicReserveConfig(reserveId);
    config.collateralFactor = newCollateralFactor.toUint16();

    vm.prank(SPOKE_ADMIN);
    uint16 configKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(spoke.getDynamicReserveConfig(reserveId), config);
    return configKey;
  }

  function updateCollateralFactor(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newCollateralFactor
  ) internal pausePrank returns (uint16) {
    DataTypes.DynamicReserveConfig memory config = spoke.getDynamicReserveConfig(reserveId);
    config.collateralFactor = newCollateralFactor.toUint16();
    vm.prank(SPOKE_ADMIN);
    uint16 configKey = spoke.addDynamicReserveConfig(reserveId, config);

    assertEq(spoke.getDynamicReserveConfig(reserveId), config);
    return configKey;
  }

  function updateReserveBorrowableFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newBorrowable
  ) internal pausePrank {
    DataTypes.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.borrowable = newBorrowable;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function updateCollateralRisk(
    ISpoke spoke,
    uint256 reserveId,
    uint24 newCollateralRisk
  ) internal pausePrank {
    DataTypes.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
    config.collateralRisk = newCollateralRisk;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserveConfig(reserveId), config);
  }

  function updateLiquidityFee(IHub hub, uint256 assetId, uint256 liquidityFee) internal pausePrank {
    DataTypes.AssetConfig memory config = hub1.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee.toUint16();
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(assetId, config);

    assertEq(hub1.getAssetConfig(assetId), config);
  }

  function updateCloseFactor(ISpoke spoke, uint128 newCloseFactor) internal pausePrank {
    DataTypes.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
    liqConfig.closeFactor = newCloseFactor;
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(liqConfig);

    assertEq(spoke.getLiquidationConfig(), liqConfig);
  }

  function getCloseFactor(ISpoke spoke) internal view returns (uint256) {
    DataTypes.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
    return liqConfig.closeFactor;
  }

  /// @dev pseudo random randomizer
  function randomizer(uint256 min, uint256 max) internal returns (uint256) {
    return vm.randomUint(min, max);
  }

  // assumes spoke has usdx supported
  function _usdxReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdx.reserveId;
  }

  // assumes spoke has usdx supported
  function _usdyReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdy.reserveId;
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

  function updateSpokeActive(
    IHub hub,
    uint256 assetId,
    address spoke,
    bool newActive
  ) internal pausePrank {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.active = newActive;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function updateDrawCap(
    IHub hub,
    uint256 assetId,
    address spoke,
    uint56 newDrawCap
  ) internal pausePrank {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.drawCap = newDrawCap;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, spoke), spokeConfig);
  }

  function getUserInfo(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (DataTypes.UserPosition memory) {
    return spoke.getUserPosition(reserveId, user);
  }

  function getUserDebt(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (Debts memory data) {
    (data.drawnDebt, data.premiumDebt) = spoke.getUserDebt(reserveId, user);
    data.totalDebt = data.drawnDebt + data.premiumDebt;
  }

  function getReserveInfo(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (DataTypes.Reserve memory) {
    return spoke.getReserve(reserveId);
  }

  function getSpokeInfo(
    uint256 assetId,
    address spoke
  ) internal view returns (DataTypes.SpokeData memory) {
    return hub1.getSpoke(assetId, spoke);
  }

  function getAssetInfo(uint256 assetId) internal view returns (DataTypes.Asset memory) {
    return hub1.getAsset(assetId);
  }

  function getAssetByReserveId(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint256, IERC20) {
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    return (reserve.assetId, IERC20(reserve.hub.getAsset(reserve.assetId).underlying));
  }

  function getAssetUnderlyingByReserveId(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (IERC20) {
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    return IERC20(reserve.hub.getAsset(reserve.assetId).underlying);
  }

  function getWithdrawalLimit(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getUserSuppliedAmount(reserveId, user);
  }

  /// @dev Helper function to calculate asset amount corresponding to single added share
  function minimumAssetsPerAddedShare(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewAddByShares(assetId, 1);
  }

  /// @dev Helper function to calculate asset amount corresponding to single drawn share
  function minimumAssetsPerDrawnShare(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.previewRestoreByShares(assetId, 1);
  }

  /// @dev Helper function to calculate expected supplied assets based on amount to supply and current exchange rate
  /// taking potential donation into account
  function calculateEffectiveAddedAssets(
    uint256 assetsAmount,
    uint256 totalAddedAssets,
    uint256 totalAddedShares
  ) internal pure returns (uint256) {
    uint256 sharesAmount = assetsAmount.toSharesDown(totalAddedAssets, totalAddedShares);
    return
      sharesAmount.toAssetsDown(totalAddedAssets + assetsAmount, totalAddedShares + sharesAmount);
  }

  function getAddExRate(uint256 assetId) internal view returns (uint256) {
    return hub1.convertToAddedAssets(assetId, MAX_SUPPLY_AMOUNT);
  }

  function getDebtExRate(uint256 assetId) internal view returns (uint256) {
    return hub1.convertToDrawnAssets(assetId, MAX_SUPPLY_AMOUNT);
  }

  function getDeficit(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.getAsset(assetId).deficit;
  }

  function getAssetDrawnRate(IHub hub, uint256 assetId) internal view returns (uint256) {
    return hub.getAsset(assetId).drawnRate;
  }

  /// @dev Helper function to ensure supply exchange rate is monotonically increasing
  function _checkSupplyRateIncreasing(
    uint256 oldRate,
    uint256 newRate,
    string memory label
  ) internal pure {
    assertGe(newRate, oldRate, string.concat('supply rate monotonically increasing ', label));
  }

  function _checkDebtRateConstant(
    uint256 oldRate,
    uint256 newRate,
    string memory label
  ) internal pure {
    assertEq(newRate, oldRate, string.concat('debt rate should be constant ', label));
  }

  /// returns the USD value of the reserve normalized by it's decimals, in terms of WAD
  function _getValueInBaseCurrency(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal view returns (uint256) {
    IPriceOracle oracle = spoke.oracle();
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    return
      (amount * oracle.getReservePrice(reserveId).toWad()) /
      (10 ** spoke.getReserve(reserveId).hub.getAsset(assetId).decimals);
  }

  /// @notice Convert 1 asset amount to equivalent amount in another asset.
  /// @notice Will contain precision loss due to conversion split into two steps.
  /// @return Converted amount of toAsset.
  function _convertAssetAmount(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    uint256 toReserveId
  ) internal view returns (uint256) {
    return
      _convertBaseCurrencyToAmount(
        spoke,
        toReserveId,
        _convertAmountToBaseCurrency(spoke, reserveId, amount)
      );
  }

  /// @dev Helper function to calculate the amount of base and premium debt to restore
  // @return drawnRestored amount of drawn debt to restore
  // @return premiumRestored amount of premium debt to restore
  function _calculateExactRestoreAmount(
    uint256 drawn,
    uint256 premium,
    uint256 restoreAmount,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    if (restoreAmount <= premium) {
      return (0, restoreAmount);
    }
    uint256 drawnRestored = _min(drawn, restoreAmount - premium);
    // round drawn debt to nearest whole share
    drawnRestored = hub1.convertToDrawnAssets(
      assetId,
      hub1.convertToDrawnShares(assetId, drawnRestored)
    );
    return (drawnRestored, premium);
  }

  /// @dev Helper function to check consistent supplied amounts within accounting
  function _checkSuppliedAmounts(
    uint256 assetId,
    uint256 reserveId,
    ISpoke spoke,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 expectedSuppliedShares = hub1.convertToAddedShares(assetId, expectedSuppliedAmount);
    assertEq(
      hub1.getAssetAddedShares(assetId),
      expectedSuppliedShares,
      string(abi.encodePacked('asset supplied shares ', label))
    );
    assertEq(
      hub1.getAssetAddedAmount(assetId),
      expectedSuppliedAmount,
      string(abi.encodePacked('asset supplied amount ', label))
    );
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke)),
      expectedSuppliedShares,
      string(abi.encodePacked('spoke supplied shares ', label))
    );
    assertEq(
      hub1.getSpokeAddedAmount(assetId, address(spoke)),
      expectedSuppliedAmount,
      string(abi.encodePacked('spoke supplied amount ', label))
    );
    assertEq(
      spoke.getReserveSuppliedShares(reserveId),
      expectedSuppliedShares,
      string(abi.encodePacked('reserve supplied shares ', label))
    );
    assertEq(
      spoke.getReserveSuppliedAmount(reserveId),
      expectedSuppliedAmount,
      string(abi.encodePacked('reserve supplied amount ', label))
    );
    assertEq(
      spoke.getUserSuppliedShares(reserveId, user),
      expectedSuppliedShares,
      string(abi.encodePacked('user supplied shares ', label))
    );
    assertEq(
      spoke.getUserSuppliedAmount(reserveId, user),
      expectedSuppliedAmount,
      string(abi.encodePacked('user supplied amount ', label))
    );
  }

  function _assertUserDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = spoke.getUserDebt(reserveId, user);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('user drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('user premium debt ', label)
    );
    assertApproxEqAbs(
      spoke.getUserTotalDebt(reserveId, user),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('user total debt ', label)
    );
  }

  function _assertReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = spoke.getReserveDebt(reserveId);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('reserve drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('reserve premium debt ', label)
    );
    assertApproxEqAbs(
      spoke.getReserveTotalDebt(reserveId),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('reserve total debt ', label)
    );
  }

  function _assertSpokeDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = hub1.getSpokeOwed(
      assetId,
      address(spoke)
    );
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('spoke drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('spoke premium debt ', label)
    );
    assertApproxEqAbs(
      hub1.getSpokeTotalOwed(assetId, address(spoke)),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('spoke total debt ', label)
    );
  }

  function _assertAssetDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    (uint256 actualDrawnDebt, uint256 actualPremiumDebt) = hub1.getAssetOwed(assetId);
    assertApproxEqAbs(
      actualDrawnDebt,
      expectedDrawnDebt,
      1,
      string.concat('asset drawn debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      3,
      string.concat('asset premium debt ', label)
    );
    assertApproxEqAbs(
      hub1.getAssetTotalOwed(assetId),
      expectedDrawnDebt + expectedPremiumDebt,
      3,
      string.concat('asset total debt ', label)
    );
  }

  function _assertSingleUserProtocolDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedDrawnDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    _assertUserDebt(spoke, reserveId, user, expectedDrawnDebt, expectedPremiumDebt, label);

    _assertReserveDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);

    _assertSpokeDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);

    _assertAssetDebt(spoke, reserveId, expectedDrawnDebt, expectedPremiumDebt, label);
  }

  function _assertUserSupply(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    assertApproxEqAbs(
      spoke.getUserSuppliedAmount(reserveId, user),
      expectedSuppliedAmount,
      3,
      string.concat('user supplied amount ', label)
    );
  }

  function _assertReserveSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    assertApproxEqAbs(
      spoke.getReserveSuppliedAmount(reserveId),
      expectedSuppliedAmount,
      3,
      string.concat('reserve supplied amount ', label)
    );
  }

  function _assertSpokeSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    assertApproxEqAbs(
      hub1.getSpokeAddedAmount(assetId, address(spoke)),
      expectedSuppliedAmount,
      3,
      string.concat('spoke supplied amount ', label)
    );
  }

  function _assertAssetSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    assertApproxEqAbs(
      hub1.getAssetAddedAmount(assetId),
      expectedSuppliedAmount,
      3,
      string.concat('asset supplied amount ', label)
    );
  }

  function _assertSingleUserProtocolSupply(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedSuppliedAmount,
    string memory label
  ) internal view {
    _assertUserSupply(spoke, reserveId, user, expectedSuppliedAmount, label);

    _assertReserveSupply(spoke, reserveId, expectedSuppliedAmount, label);

    _assertSpokeSupply(spoke, reserveId, expectedSuppliedAmount, label);

    _assertAssetSupply(spoke, reserveId, expectedSuppliedAmount, label);
  }

  function _convertAmountToBaseCurrency(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal view returns (uint256) {
    IPriceOracle oracle = spoke.oracle();
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    return
      _convertAmountToBaseCurrency(
        amount,
        oracle.getReservePrice(reserveId),
        10 ** hub1.getAsset(assetId).decimals
      );
  }

  function _convertAmountToBaseCurrency(
    uint256 amount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return (amount * assetPrice).toWad() / assetUnit;
  }

  function _convertBaseCurrencyToAmount(
    ISpoke spoke,
    uint256 reserveId,
    uint256 baseCurrencyAmount
  ) internal view returns (uint256) {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IPriceOracle oracle = spoke.oracle();
    return
      _convertBaseCurrencyToAmount(
        baseCurrencyAmount,
        oracle.getReservePrice(reserveId),
        10 ** hub1.getAsset(assetId).decimals
      );
  }

  /// @dev Convert base currency to asset amount
  function _convertBaseCurrencyToAmount(
    uint256 baseCurrencyAmount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return ((baseCurrencyAmount * assetUnit) / assetPrice).fromWadDown();
  }

  /**
   * @notice Returns the required debt amount to ensure user position is below a certain health factor.
   * @param desiredHf The desired health factor to be below.
   */
  function _getRequiredDebtAmountForLtHf(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 desiredHf
  ) internal view returns (uint256 requiredDebtAmount) {
    uint256 requiredDebtAmountInBase = _getRequiredDebtInBaseCurrencyForLtHf(
      spoke,
      user,
      desiredHf
    );
    return _convertBaseCurrencyToAmount(spoke, reserveId, requiredDebtAmountInBase) + 1;
  }

  /**
   * @notice Returns the required debt in base currency to ensure user position is below a certain health factor.
   */
  function _getRequiredDebtInBaseCurrencyForLtHf(
    ISpoke spoke,
    address user,
    uint256 desiredHf
  ) internal view returns (uint256 requiredDebtInBaseCurrency) {
    (
      ,
      uint256 currentAvgCollateralFactor,
      ,
      uint256 totalCollateralBase,
      uint256 totalDebtBase
    ) = spoke.getUserAccountData(user);

    requiredDebtInBaseCurrency =
      totalCollateralBase.percentMulDown(currentAvgCollateralFactor.fromWadDown() + 1).wadDivUp(
        desiredHf
      ) -
      totalDebtBase;
    // add 1 to num to round debt up (ie making sure resultant debt creates HF that is less than desired)
  }

  /// @dev Borrow to be below a certain health factor, without needing to check HF
  function _borrowToBeBelowHf(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 desiredHf
  ) internal returns (uint256, uint256) {
    uint256 requiredDebtAmount = _getRequiredDebtAmountForLtHf(spoke, user, reserveId, desiredHf);
    require(requiredDebtAmount <= MAX_SUPPLY_AMOUNT, 'required debt amount too high');

    _borrowWithoutHfCheck(spoke, user, reserveId, requiredDebtAmount);

    uint256 finalHf = spoke.getHealthFactor(user);
    assertLt(finalHf, desiredHf, 'should borrow enough for HF to be below desiredHf');

    return (finalHf, requiredDebtAmount);
  }

  function _approxRelFromBps(uint256 bps) internal pure returns (uint256) {
    return (bps * 1e18) / 100_00;
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function _max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a : b;
  }

  function _getCloseFactor(ISpoke spoke) internal view returns (uint128) {
    return spoke.getLiquidationConfig().closeFactor;
  }

  function _calcMinimumCollAmount(
    ISpoke spoke,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 debtAmount
  ) internal view returns (uint256) {
    if (debtAmount == 0) return 1;

    IPriceOracle oracle = spoke.oracle();
    DataTypes.Reserve memory collData = spoke.getReserve(collReserveId);
    DataTypes.DynamicReserveConfig memory colDynConf = spoke.getDynamicReserveConfig(collReserveId);
    uint256 collPrice = oracle.getReservePrice(collReserveId);
    uint256 collAssetUnits = 10 ** hub1.getAsset(collData.assetId).decimals;

    DataTypes.Reserve memory debtData = spoke.getReserve(debtReserveId);
    uint256 debtAssetUnits = 10 ** hub1.getAsset(debtData.assetId).decimals;
    uint256 debtPrice = oracle.getReservePrice(debtReserveId);

    uint256 normalizedDebtAmount = (debtAmount * debtPrice).wadDivDown(debtAssetUnits);
    uint256 normalizedCollPrice = collPrice.wadDivDown(collAssetUnits);

    return
      normalizedDebtAmount.wadDivUp(
        normalizedCollPrice.toWad().percentMulDown(colDynConf.collateralFactor)
      );
  }

  /// @dev Helper function to borrow without health factor check
  function _borrowWithoutHfCheck(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 debtAmount
  ) internal {
    uint256 initialPrice = spoke.oracle().getReservePrice(reserveId);
    // set price to 0 to circumvent borrow validation
    vm.mockCall(
      address(spoke.oracle()),
      abi.encodeWithSelector(IPriceOracle.getReservePrice.selector, reserveId),
      abi.encode(0)
    );
    vm.prank(user);
    spoke.borrow(reserveId, debtAmount, user);
    vm.mockCall(
      address(spoke.oracle()),
      abi.encodeWithSelector(IPriceOracle.getReservePrice.selector, reserveId),
      abi.encode(initialPrice)
    );
  }

  /// @dev Calculate expected debt index based on input params
  function _calculateExpectedDrawnIndex(
    uint256 initialDrawnIndex,
    uint256 borrowRate,
    uint40 startTime
  ) internal view returns (uint256) {
    return initialDrawnIndex.rayMulUp(MathUtils.calculateLinearInterest(borrowRate, startTime));
  }

  /// @dev Calculate expected debt index and drawn debt based on input params
  function calculateExpectedDebt(
    uint256 initialDrawnShares,
    uint256 initialDrawnIndex,
    uint256 borrowRate,
    uint40 startTime
  ) internal view returns (uint256 newDrawnIndex, uint256 newDrawnDebt) {
    newDrawnIndex = _calculateExpectedDrawnIndex(initialDrawnIndex, borrowRate, startTime);
    newDrawnDebt = initialDrawnShares.rayMulUp(newDrawnIndex);
  }

  /// @dev Calculate expected drawn debt based on specified borrow rate
  function _calculateExpectedDrawnDebt(
    uint256 initialDebt,
    uint256 borrowRate,
    uint40 startTime
  ) internal view returns (uint256) {
    return MathUtils.calculateLinearInterest(borrowRate, startTime).rayMulUp(initialDebt);
  }

  /// @dev Calculate expected premium debt based on change in drawn debt and user rp
  function _calculateExpectedPremiumDebt(
    uint256 initialDrawnDebt,
    uint256 currentDrawnDebt,
    uint256 userRiskPremium
  ) internal pure returns (uint256) {
    return (currentDrawnDebt - initialDrawnDebt).percentMulUp(userRiskPremium);
  }

  /// @dev Helper function to get asset drawn debt
  function getAssetDrawnDebt(uint256 assetId) internal view returns (uint256) {
    (uint256 drawn, ) = hub1.getAssetOwed(assetId);
    return drawn;
  }

  /// @dev Helper function to calculate burnt interest in assets terms (originated from virtual shares and assets)
  function _calculateBurntInterest(IHub hub, uint256 assetId) internal view returns (uint256) {
    return
      hub.getTotalAddedAssets(assetId) -
      hub.previewRemoveByShares(assetId, hub.getTotalAddedShares(assetId));
  }

  /// @dev Helper function to withdraw fees from the treasury spoke
  function withdrawLiquidityFees(uint256 assetId, uint256 amount) internal {
    uint256 fees = hub1.getSpokeAddedAmount(assetId, address(treasurySpoke));
    if (amount > fees) {
      amount = fees;
    }
    if (amount == 0) {
      return; // nothing to withdraw
    }
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(assetId, amount, address(treasurySpoke));
  }

  function _assumeValidSupplier(address user) internal view {
    vm.assume(
      user != address(0) &&
        user != address(hub1) &&
        user != address(spoke1) &&
        user != address(spoke2) &&
        user != address(spoke3)
    );
  }

  function _getLiquidityFee(uint256 assetId) internal view returns (uint256) {
    return hub1.getAssetConfig(assetId).liquidityFee;
  }

  function _getFeeReceiver(uint256 assetId) internal view returns (address) {
    return hub1.getAssetConfig(assetId).feeReceiver;
  }

  function _getCollateralRisk(ISpoke spoke, uint256 reserveId) internal view returns (uint24) {
    return spoke.getReserveConfig(reserveId).collateralRisk;
  }

  function _getCollateralFactor(ISpoke spoke, uint256 reserveId) internal view returns (uint16) {
    return spoke.getDynamicReserveConfig(reserveId).collateralFactor;
  }

  function _hasRole(
    IAccessManager authority,
    uint64 role,
    address account
  ) internal view returns (bool) {
    (bool hasRole, ) = authority.hasRole(role, account);
    return hasRole;
  }

  function _randomBps() internal returns (uint16) {
    return vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR).toUint16();
  }

  function assertEq(DataTypes.AssetConfig memory a, DataTypes.AssetConfig memory b) internal pure {
    assertEq(a.feeReceiver, b.feeReceiver, 'feeReceiver');
    assertEq(a.liquidityFee, b.liquidityFee, 'liquidityFee');
    assertEq(a.irStrategy, b.irStrategy, 'irStrategy');
    assertEq(a.reinvestmentController, b.reinvestmentController, 'reinvestmentController');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(DataTypes.SpokeConfig memory a, DataTypes.SpokeConfig memory b) internal pure {
    assertEq(a.addCap, b.addCap, 'addCap');
    assertEq(a.drawCap, b.drawCap, 'drawCap');
    assertEq(a.active, b.active, 'active');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    DataTypes.LiquidationConfig memory a,
    DataTypes.LiquidationConfig memory b
  ) internal pure {
    assertEq(a.closeFactor, b.closeFactor, 'closeFactor');
    assertEq(a.liquidationBonusFactor, b.liquidationBonusFactor, 'liquidationBonusFactor');
    assertEq(a.healthFactorForMaxBonus, b.healthFactorForMaxBonus, 'healthFactorForMaxBonus');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    DataTypes.ReserveConfig memory a,
    DataTypes.ReserveConfig memory b
  ) internal pure {
    assertEq(a.paused, b.paused, 'paused');
    assertEq(a.frozen, b.frozen, 'frozen');
    assertEq(a.borrowable, b.borrowable, 'borrowable');
    assertEq(a.collateralRisk, b.collateralRisk, 'collateralRisk');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    DataTypes.DynamicReserveConfig memory a,
    DataTypes.DynamicReserveConfig memory b
  ) internal pure {
    assertEq(a.collateralFactor, b.collateralFactor, 'collateralFactor');
    assertEq(a.liquidationBonus, b.liquidationBonus, 'liquidationBonus');
    assertEq(a.liquidationFee, b.liquidationFee, 'liquidationFee');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    IAssetInterestRateStrategy.InterestRateData memory a,
    IAssetInterestRateStrategy.InterestRateData memory b
  ) internal pure {
    assertEq(a.optimalUsageRatio, b.optimalUsageRatio, 'optimalUsageRatio');
    assertEq(a.baseVariableBorrowRate, b.baseVariableBorrowRate, 'baseVariableBorrowRate');
    assertEq(a.variableRateSlope1, b.variableRateSlope1, 'variableRateSlope1');
    assertEq(a.variableRateSlope2, b.variableRateSlope2, 'variableRateSlope2');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function _calculateExpectedFees(
    uint256 drawnIncrease,
    uint256 premiumIncrease,
    uint256 liquidityFee
  ) internal pure returns (uint256) {
    return (drawnIncrease + premiumIncrease).percentMulDown(liquidityFee);
  }

  function _calculateExpectedFeesAmount(
    uint256 initialDrawnShares,
    uint256 initialPremiumShares,
    uint256 liquidityFee,
    uint256 indexDelta
  ) internal pure returns (uint256 feesAmount) {
    return
      indexDelta.rayMulDown(initialDrawnShares + initialPremiumShares).percentMulDown(liquidityFee);
  }

  /// @dev Get the liquidation bonus for a given reserve at a user HF
  function _getVariableLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) internal view returns (uint256) {
    return spoke.getVariableLiquidationBonus(reserveId, user, healthFactor);
  }

  /**
   * @notice Returns the required debt amount in base currency to ensure user position is above a certain health factor.
   * @return requiredDebt The required additional debt amount in base currency.
   */
  function _getRequiredDebtForGtHf(
    ISpoke spoke,
    address user,
    uint256 desiredHf
  ) internal view returns (uint256) {
    (
      ,
      uint256 currentAvgCollateralFactor,
      ,
      uint256 totalCollateralBase,
      uint256 totalDebtBase
    ) = spoke.getUserAccountData(user);

    return
      totalCollateralBase
        .percentMulDown(currentAvgCollateralFactor.fromWadDown())
        .percentMulDown(99_00)
        .wadDivDown(desiredHf) - totalDebtBase;
    // buffer to force debt lower (ie making sure resultant debt creates HF that is gt desired)
  }

  /// @dev Borrow to be below a certain healthy health factor
  /// @dev This function validates HF and does not mock price, thus it will cache user RP properly
  function _borrowToBeAboveHealthyHf(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 desiredHf
  ) internal returns (uint256, uint256) {
    uint256 requiredDebtInBase = _getRequiredDebtForGtHf(spoke, user, desiredHf);
    uint256 requiredDebtAmount = _convertBaseCurrencyToAmount(
      spoke,
      reserveId,
      requiredDebtInBase
    ) - 1;

    vm.assume(requiredDebtAmount < MAX_SUPPLY_AMOUNT);

    vm.prank(user);
    spoke.borrow(reserveId, requiredDebtAmount, user);

    uint256 finalHf = spoke.getHealthFactor(user);
    assertGt(finalHf, desiredHf, 'should borrow so that HF is above desiredHf');
    return (finalHf, requiredDebtAmount);
  }

  function _mockDecimals(address underlying, uint8 decimals) internal {
    vm.mockCall(
      underlying,
      abi.encodeWithSelector(IERC20Metadata.decimals.selector),
      abi.encode(decimals)
    );
  }

  function _mockInterestRateBps(uint256 interestRateBps) internal {
    _mockInterestRateBps(address(irStrategy), interestRateBps);
  }

  function _mockInterestRateBps(address interestRateStrategy, uint256 interestRateBps) internal {
    vm.mockCall(
      interestRateStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      abi.encode(interestRateBps.bpsToRay())
    );
  }

  function _mockInterestRateBps(
    uint256 interestRateBps,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 premium,
    uint256 deficit,
    uint256 swept
  ) internal {
    _mockInterestRateBps(
      address(irStrategy),
      interestRateBps,
      assetId,
      liquidity,
      drawn,
      premium,
      deficit,
      swept
    );
  }

  function _mockInterestRateBps(
    address interestRateStrategy,
    uint256 interestRateBps,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 premium,
    uint256 deficit,
    uint256 swept
  ) internal {
    vm.mockCall(
      interestRateStrategy,
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, liquidity, drawn, premium, deficit, swept)
      ),
      abi.encode(interestRateBps.bpsToRay())
    );
  }

  function _mockInterestRateRay(uint256 interestRateRay) internal {
    _mockInterestRateRay(address(irStrategy), interestRateRay);
  }

  function _mockInterestRateRay(address interestRateStrategy, uint256 interestRateRay) internal {
    vm.mockCall(
      interestRateStrategy,
      IBasicInterestRateStrategy.calculateInterestRate.selector,
      abi.encode(interestRateRay)
    );
  }

  function _mockInterestRateRay(
    uint256 interestRateRay,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 premium
  ) internal {
    _mockInterestRateRay(
      address(irStrategy),
      interestRateRay,
      assetId,
      liquidity,
      drawn,
      premium,
      0,
      0
    );
  }

  function _mockInterestRateRay(
    address interestRateStrategy,
    uint256 interestRateRay,
    uint256 assetId,
    uint256 liquidity,
    uint256 drawn,
    uint256 premium,
    uint256 deficit,
    uint256 swept
  ) internal {
    vm.mockCall(
      interestRateStrategy,
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, liquidity, drawn, premium, deficit, swept)
      ),
      abi.encode(interestRateRay)
    );
  }

  function _mockReservePrice(ISpoke spoke, uint256 reserveId, uint256 price) internal {
    require(price > 0, 'mockReservePrice: price must be positive');
    AaveOracle oracle = AaveOracle(address(spoke.oracle()));
    address mockPriceFeed = address(
      new MockPriceFeed(oracle.DECIMALS(), oracle.DESCRIPTION(), price)
    );
    vm.prank(address(ADMIN));
    spoke.updateReservePriceSource(reserveId, mockPriceFeed);
  }

  function _mockReservePriceByPercent(
    ISpoke spoke,
    uint256 reserveId,
    uint256 percentage
  ) internal {
    uint256 initialPrice = spoke.oracle().getReservePrice(reserveId);
    uint256 newPrice = initialPrice.percentMulDown(percentage);
    _mockReservePrice(spoke, reserveId, newPrice);
  }

  function _deployMockPriceFeed(ISpoke spoke, uint256 price) internal returns (address) {
    AaveOracle oracle = AaveOracle(address(spoke.oracle()));
    return address(new MockPriceFeed(oracle.DECIMALS(), oracle.DESCRIPTION(), price));
  }

  function assertBorrowRateSynced(
    IHub targetHub,
    uint256 assetId,
    string memory operation
  ) internal view {
    DataTypes.Asset memory asset = targetHub.getAsset(assetId);
    (uint256 drawn, uint256 premium) = hub1.getAssetOwed(assetId);

    vm.assertEq(
      asset.drawnRate,
      IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate(
        assetId,
        asset.liquidity,
        drawn,
        premium,
        asset.deficit,
        asset.swept
      ),
      string.concat('base borrow rate after ', operation)
    );
  }

  function _assertEventNotEmitted(bytes32 eventSignature) internal {
    Vm.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], eventSignature);
    }
    vm.recordLogs();
  }

  function _assertEventsNotEmitted(bytes32 event1Sig, bytes32 event2Sig) internal {
    Vm.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], event1Sig);
      assertNotEq(entries[i].topics[0], event2Sig);
    }
    vm.recordLogs();
  }

  function _assertEventsNotEmitted(
    bytes32 event1Sig,
    bytes32 event2Sig,
    bytes32 event3Sig
  ) internal {
    Vm.Log[] memory entries = vm.getRecordedLogs();
    for (uint256 i; i < entries.length; i++) {
      assertNotEq(entries[i].topics[0], event1Sig);
      assertNotEq(entries[i].topics[0], event2Sig);
      assertNotEq(entries[i].topics[0], event3Sig);
    }
    vm.recordLogs();
  }

  function _assertDynamicConfigRefreshEventsNotEmitted() internal {
    _assertEventsNotEmitted(
      ISpoke.RefreshAllUserDynamicConfig.selector,
      ISpoke.RefreshSingleUserDynamicConfig.selector
    );
  }

  // @dev Helper function to get asset position, valid if no time has passed since last action
  function getAssetPosition(
    IHub targetHub,
    uint256 assetId
  ) internal view returns (AssetPosition memory) {
    DataTypes.Asset memory assetData = targetHub.getAsset(assetId);
    (uint256 drawn, uint256 premium) = targetHub.getAssetOwed(assetId);
    return
      AssetPosition({
        assetId: assetId,
        liquidity: assetData.liquidity,
        addedShares: assetData.addedShares,
        addedAmount: targetHub.getAssetAddedAmount(assetId),
        drawnShares: assetData.drawnShares,
        drawn: drawn,
        premiumShares: assetData.premiumShares,
        premiumOffset: assetData.premiumOffset,
        realizedPremium: assetData.realizedPremium,
        premium: premium,
        lastUpdateTimestamp: assetData.lastUpdateTimestamp.toUint40(),
        drawnIndex: assetData.drawnIndex,
        drawnRate: assetData.drawnRate
      });
  }

  function getSpokePosition(
    ISpoke spoke,
    function(ISpoke) internal view returns (uint256) reserveIdFn
  ) internal view returns (SpokePosition memory) {
    return getSpokePosition(spoke, reserveIdFn(spoke));
  }

  function getSpokePosition(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (SpokePosition memory) {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    DataTypes.SpokeData memory spokeData = hub1.getSpoke(assetId, address(spoke));
    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(assetId, address(spoke));
    return
      SpokePosition({
        reserveId: reserveId,
        assetId: assetId,
        addedShares: spokeData.addedShares,
        addedAmount: hub1.getSpokeAddedAmount(assetId, address(spoke)),
        drawnShares: spokeData.drawnShares,
        drawn: drawn,
        premiumShares: spokeData.premiumShares,
        premiumOffset: spokeData.premiumOffset,
        realizedPremium: spokeData.realizedPremium,
        premium: premium
      });
  }

  function _getReserve(ISpoke spoke, uint256 reserveId) internal view returns (Reserve memory) {
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    return
      Reserve({
        reserveId: reserveId,
        hub: reserve.hub,
        assetId: reserve.assetId,
        decimals: reserve.decimals,
        dynamicConfigKey: reserve.dynamicConfigKey,
        paused: reserve.paused,
        frozen: reserve.frozen,
        borrowable: reserve.borrowable,
        collateralRisk: reserve.collateralRisk
      });
  }

  function assertEq(SpokePosition memory a, AssetPosition memory b) internal pure {
    assertEq(a.assetId, b.assetId, 'assetId');
    assertEq(a.addedShares, b.addedShares, 'addedShares');
    assertEq(a.addedAmount, b.addedAmount, 'addedAmount');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.drawn, b.drawn, 'drawnDebt');
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffset, b.premiumOffset, 'premiumOffset');
    assertEq(a.realizedPremium, b.realizedPremium, 'realizedPremium');
    assertEq(a.premium, b.premium, 'premium');
  }

  function assertEq(SpokePosition memory a, SpokePosition memory b) internal pure {
    assertEq(a.reserveId, b.reserveId, 'reserveId');
    assertEq(a.assetId, b.assetId, 'assetId');
    assertEq(a.addedShares, b.addedShares, 'addedShares');
    assertEq(a.addedAmount, b.addedAmount, 'addedAmount');
    assertEq(a.drawnShares, b.drawnShares, 'drawnShares');
    assertEq(a.drawn, b.drawn, 'drawn');
    assertEq(a.premiumShares, b.premiumShares, 'premiumShares');
    assertEq(a.premiumOffset, b.premiumOffset, 'premiumOffset');
    assertEq(a.realizedPremium, b.realizedPremium, 'realizedPremium');
    assertEq(a.premium, b.premium, 'premium');
    assertEq(abi.encode(a), abi.encode(b)); // sanity check
  }

  modifier pausePrank() {
    (VmSafe.CallerMode callerMode, address msgSender, address txOrigin) = vm.readCallers();
    if (callerMode == VmSafe.CallerMode.RecurrentPrank) vm.stopPrank();
    _;
    if (callerMode == VmSafe.CallerMode.RecurrentPrank) vm.startPrank(msgSender, txOrigin);
  }

  function makeEntity(string memory id, bytes32 key) internal returns (address) {
    return makeAddr(string.concat(id, '-', vm.toString(uint256(key))));
  }

  function makeUser(uint256 i) internal returns (address) {
    return makeEntity('user', bytes32(i));
  }

  function makeUser() internal returns (address) {
    return makeEntity('user', vm.randomBytes8());
  }

  function makeSpoke() internal returns (address) {
    return makeEntity('spoke', vm.randomBytes8());
  }

  function _getTypedDataHash(
    TestnetERC20 token,
    EIP712Types.Permit memory permit
  ) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          token.DOMAIN_SEPARATOR(),
          vm.eip712HashStruct('Permit', abi.encode(permit))
        )
      );
  }

  function _getTypedDataHash(
    ISpoke spoke,
    EIP712Types.SetUserPositionManager memory setUserPositionManager
  ) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          spoke.DOMAIN_SEPARATOR(),
          vm.eip712HashStruct('SetUserPositionManager', abi.encode(setUserPositionManager))
        )
      );
  }
}
