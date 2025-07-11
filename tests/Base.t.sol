// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {stdError} from 'forge-std/StdError.sol';
import {stdMath} from 'forge-std/StdMath.sol';
import {Vm} from 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';

import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';
import {AggregatorV3Interface} from 'src/dependencies/chainlink/AggregatorV3Interface.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {LiquidityHub, ILiquidityHub} from 'src/contracts/LiquidityHub.sol';
import {Spoke, ISpoke} from 'src/contracts/Spoke.sol';
import {AaveOracle, IAaveOracle} from 'src/contracts/AaveOracle.sol';
import {TreasurySpoke, ITreasurySpoke} from 'src/contracts/TreasurySpoke.sol';
import {Configurator, IConfigurator} from 'src/contracts/Configurator.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {PercentageMathExtended} from 'src/libraries/math/PercentageMathExtended.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {AssetInterestRateStrategy, IAssetInterestRateStrategy, IBasicInterestRateStrategy} from 'src/contracts/AssetInterestRateStrategy.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {Utils} from 'tests/Utils.sol';

// mocks
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockERC20} from 'tests/mocks/MockERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {PositionStatusWrapper} from 'tests/mocks/PositionStatusWrapper.sol';

// dependencies
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {AuthorityUtils} from 'src/dependencies/openzeppelin/AuthorityUtils.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {LibBit} from 'src/dependencies/solady/LibBit.sol';

abstract contract Base is Test {
  using WadRayMathExtended for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;
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
  uint256 internal constant MAX_SKIP_TIME = 10_000 days;
  uint256 internal constant MIN_LIQUIDATION_BONUS = PercentageMath.PERCENTAGE_FACTOR; // 100% == 0% bonus
  uint256 internal constant MAX_LIQUIDATION_BONUS = 150_00; // 50% bonus
  uint256 internal constant MAX_LIQUIDATION_BONUS_FACTOR = PercentageMath.PERCENTAGE_FACTOR; // 100%
  uint256 internal constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
  uint256 internal constant MIN_CLOSE_FACTOR = 1e18;
  uint256 internal constant MAX_CLOSE_FACTOR = 2e18;
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
  ILiquidityHub internal hub;
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
  address internal TREASURY_ADMIN = makeAddr('TREASURY_ADMIN');
  address internal LIQUIDATOR = makeAddr('LIQUIDATOR');

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

  struct DebtAccounting {
    uint256 cumulativeDebt;
    uint256 baseDebt;
    uint256 outstandingPremium;
  }

  mapping(ISpoke => SpokeInfo) internal spokeInfo;

  function setUp() public virtual {
    deployFixtures();
  }

  function deployFixtures() internal virtual {
    vm.startPrank(ADMIN);
    accessManager = new AccessManager(ADMIN);
    hub = new LiquidityHub(address(accessManager));
    irStrategy = new AssetInterestRateStrategy(address(hub));
    spoke1 = ISpoke(new Spoke(address(accessManager)));
    spoke2 = ISpoke(new Spoke(address(accessManager)));
    spoke3 = ISpoke(new Spoke(address(accessManager)));
    oracle1 = IAaveOracle(new AaveOracle(address(spoke1), 8, 'Spoke 1 (USD)'));
    oracle2 = IAaveOracle(new AaveOracle(address(spoke2), 8, 'Spoke 2 (USD)'));
    oracle3 = IAaveOracle(new AaveOracle(address(spoke3), 8, 'Spoke 3 (USD)'));
    treasurySpoke = ITreasurySpoke(new TreasurySpoke(TREASURY_ADMIN, address(hub)));
    dai = new MockERC20();
    eth = new MockERC20();
    usdc = new MockERC20();
    usdt = new MockERC20();
    wbtc = new MockERC20();
    vm.stopPrank();

    vm.label(address(spoke1), 'spoke1');
    vm.label(address(spoke2), 'spoke2');
    vm.label(address(spoke3), 'spoke3');

    setUpRoles(hub, spoke1, accessManager);
    setUpRoles(hub, spoke2, accessManager);
    setUpRoles(hub, spoke3, accessManager);
  }

  function setUpRoles(
    ILiquidityHub hub,
    ISpoke spoke,
    IAccessManager accessManager
  ) internal virtual {
    vm.startPrank(ADMIN);
    // Grant roles with 0 delay
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, HUB_ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, SPOKE_ADMIN, 0);

    // Grant responsibilities to roles
    // Spoke Admin functionalities
    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = ISpoke.updateOracle.selector;
    selectors[1] = ISpoke.updateReservePriceSource.selector;
    selectors[2] = ISpoke.updateLiquidationConfig.selector;
    selectors[3] = ISpoke.addReserve.selector;
    selectors[4] = ISpoke.updateReserveConfig.selector;
    selectors[5] = ISpoke.updateDynamicReserveConfig.selector;
    selectors[6] = ISpoke.updateUserRiskPremium.selector;
    accessManager.setTargetFunctionRole(address(spoke), selectors, Roles.SPOKE_ADMIN_ROLE);

    // Liquidity Hub Admin functionalities
    bytes4[] memory hubSelectors = new bytes4[](5);
    hubSelectors[0] = ILiquidityHub.addAsset.selector;
    hubSelectors[1] = ILiquidityHub.updateAssetConfig.selector;
    hubSelectors[2] = ILiquidityHub.addSpoke.selector;
    hubSelectors[3] = ILiquidityHub.updateSpokeConfig.selector;
    hubSelectors[4] = ILiquidityHub.setInterestRateData.selector;
    accessManager.setTargetFunctionRole(address(hub), hubSelectors, Roles.HUB_ADMIN_ROLE);

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

    address[6] memory users = [alice, bob, carol, derl, LIQUIDATOR, TREASURY_ADMIN];

    for (uint256 x; x < users.length; ++x) {
      tokenList.usdx.mint(users[x], mintAmount_USDX);
      tokenList.dai.mint(users[x], mintAmount_DAI);
      tokenList.wbtc.mint(users[x], mintAmount_WBTC);
      tokenList.usdy.mint(users[x], mintAmount_USDY);
      deal(address(tokenList.weth), users[x], mintAmount_WETH);

      vm.startPrank(users[x]);
      tokenList.weth.approve(address(hub), type(uint256).max);
      tokenList.usdx.approve(address(hub), type(uint256).max);
      tokenList.dai.approve(address(hub), type(uint256).max);
      tokenList.wbtc.approve(address(hub), type(uint256).max);
      tokenList.usdy.approve(address(hub), type(uint256).max);
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
      tokenList.weth.approve(address(hub), type(uint256).max);
      tokenList.usdx.approve(address(hub), type(uint256).max);
      tokenList.dai.approve(address(hub), type(uint256).max);
      tokenList.wbtc.approve(address(hub), type(uint256).max);
      tokenList.usdy.approve(address(hub), type(uint256).max);
      vm.stopPrank();
    }
  }

  function configureTokenList() internal {
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      active: true,
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });

    // Add all assets to the Liquidity Hub
    vm.startPrank(ADMIN);
    // add WETH
    hub.addAsset(
      address(tokenList.weth),
      tokenList.weth.decimals(),
      address(treasurySpoke),
      address(irStrategy)
    );
    hub.addSpoke(wethAssetId, address(treasurySpoke), spokeConfig);
    vm.stopPrank();
    vm.prank(address(hub));
    irStrategy.setInterestRateData(
      wethAssetId,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00, // 90.00%
          baseVariableBorrowRate: 5_00, // 5.00%
          variableRateSlope1: 5_00, // 5.00%
          variableRateSlope2: 5_00 // 5.00%
        })
      )
    );
    vm.startPrank(ADMIN);
    hub.updateAssetConfig(
      wethAssetId,
      DataTypes.AssetConfig({
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy)
      })
    );

    // add USDX
    hub.addAsset(
      address(tokenList.usdx),
      tokenList.usdx.decimals(),
      address(treasurySpoke),
      address(irStrategy)
    );
    hub.addSpoke(usdxAssetId, address(treasurySpoke), spokeConfig);
    vm.stopPrank();
    vm.prank(address(hub));
    irStrategy.setInterestRateData(
      usdxAssetId,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00, // 90.00%
          baseVariableBorrowRate: 5_00, // 5.00%
          variableRateSlope1: 5_00, // 5.00%
          variableRateSlope2: 5_00 // 5.00%
        })
      )
    );
    vm.startPrank(ADMIN);
    hub.updateAssetConfig(
      usdxAssetId,
      DataTypes.AssetConfig({
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy)
      })
    );

    // add DAI
    hub.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(irStrategy)
    );
    hub.addSpoke(daiAssetId, address(treasurySpoke), spokeConfig);
    vm.stopPrank();
    vm.prank(address(hub));
    irStrategy.setInterestRateData(
      daiAssetId,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00, // 90.00%
          baseVariableBorrowRate: 5_00, // 5.00%
          variableRateSlope1: 5_00, // 5.00%
          variableRateSlope2: 5_00 // 5.00%
        })
      )
    );
    vm.startPrank(ADMIN);
    hub.updateAssetConfig(
      daiAssetId,
      DataTypes.AssetConfig({
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy)
      })
    );

    // add WBTC
    hub.addAsset(
      address(tokenList.wbtc),
      tokenList.wbtc.decimals(),
      address(treasurySpoke),
      address(irStrategy)
    );
    hub.addSpoke(wbtcAssetId, address(treasurySpoke), spokeConfig);
    vm.stopPrank();
    vm.prank(address(hub));
    irStrategy.setInterestRateData(
      wbtcAssetId,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00, // 90.00%
          baseVariableBorrowRate: 5_00, // 5.00%
          variableRateSlope1: 5_00, // 5.00%
          variableRateSlope2: 5_00 // 5.00%
        })
      )
    );
    vm.startPrank(ADMIN);
    hub.updateAssetConfig(
      wbtcAssetId,
      DataTypes.AssetConfig({
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy)
      })
    );

    // add USDY
    hub.addAsset(
      address(tokenList.usdy),
      tokenList.usdy.decimals(),
      address(treasurySpoke),
      address(irStrategy)
    );
    hub.addSpoke(usdyAssetId, address(treasurySpoke), spokeConfig);
    vm.stopPrank();
    vm.prank(address(hub));
    irStrategy.setInterestRateData(
      usdyAssetId,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00, // 90.00%
          baseVariableBorrowRate: 5_00, // 5.00%
          variableRateSlope1: 5_00, // 5.00%
          variableRateSlope2: 5_00 // 5.00%
        })
      )
    );
    vm.startPrank(ADMIN);
    hub.updateAssetConfig(
      usdyAssetId,
      DataTypes.AssetConfig({
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy)
      })
    );

    // add DAI again
    hub.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(irStrategy)
    );
    hub.addSpoke(hub.getAssetCount() - 1, address(treasurySpoke), spokeConfig);
    vm.stopPrank();
    vm.prank(address(hub));
    irStrategy.setInterestRateData(
      dai2AssetId,
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00, // 90.00%
          baseVariableBorrowRate: 5_00, // 5.00%
          variableRateSlope1: 5_00, // 5.00%
          variableRateSlope2: 5_00 // 5.00%
        })
      )
    );
    vm.startPrank(ADMIN);
    hub.updateAssetConfig(
      hub.getAssetCount() - 1,
      DataTypes.AssetConfig({
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy)
      })
    );

    // configure oracle in spokes
    spoke1.updateOracle(address(oracle1));
    spoke2.updateOracle(address(oracle2));
    spoke3.updateOracle(address(oracle3));

    // Spoke 1 reserve configs
    spokeInfo[spoke1].weth.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 15_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke1].weth.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00
    });
    spokeInfo[spoke1].wbtc.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 5_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke1].wbtc.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 75_00
    });
    spokeInfo[spoke1].dai.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 20_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke1].dai.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00
    });
    spokeInfo[spoke1].usdx.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 50_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke1].usdx.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00
    });
    spokeInfo[spoke1].usdy.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 50_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke1].usdy.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00
    });

    spokeInfo[spoke1].weth.reserveId = spoke1.addReserve(
      wethAssetId,
      address(hub),
      _deployMockPriceFeed(spoke1, 2000e8),
      spokeInfo[spoke1].weth.reserveConfig,
      spokeInfo[spoke1].weth.dynReserveConfig
    );
    spokeInfo[spoke1].wbtc.reserveId = spoke1.addReserve(
      wbtcAssetId,
      address(hub),
      _deployMockPriceFeed(spoke1, 50_000e8),
      spokeInfo[spoke1].wbtc.reserveConfig,
      spokeInfo[spoke1].wbtc.dynReserveConfig
    );
    spokeInfo[spoke1].dai.reserveId = spoke1.addReserve(
      daiAssetId,
      address(hub),
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].dai.reserveConfig,
      spokeInfo[spoke1].dai.dynReserveConfig
    );
    spokeInfo[spoke1].usdx.reserveId = spoke1.addReserve(
      usdxAssetId,
      address(hub),
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].usdx.reserveConfig,
      spokeInfo[spoke1].usdx.dynReserveConfig
    );
    spokeInfo[spoke1].usdy.reserveId = spoke1.addReserve(
      usdyAssetId,
      address(hub),
      _deployMockPriceFeed(spoke1, 1e8),
      spokeInfo[spoke1].usdy.reserveConfig,
      spokeInfo[spoke1].usdy.dynReserveConfig
    );

    hub.addSpoke(wethAssetId, address(spoke1), spokeConfig);
    hub.addSpoke(wbtcAssetId, address(spoke1), spokeConfig);
    hub.addSpoke(daiAssetId, address(spoke1), spokeConfig);
    hub.addSpoke(usdxAssetId, address(spoke1), spokeConfig);
    hub.addSpoke(usdyAssetId, address(spoke1), spokeConfig);

    // Spoke 2 reserve configs
    spokeInfo[spoke2].wbtc.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 0,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke2].wbtc.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00
    });
    spokeInfo[spoke2].weth.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 10_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke2].weth.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 76_00
    });
    spokeInfo[spoke2].dai.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 20_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke2].dai.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 72_00
    });
    spokeInfo[spoke2].usdx.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 50_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke2].usdx.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 72_00
    });
    spokeInfo[spoke2].usdy.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 50_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke2].usdy.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 72_00
    });
    spokeInfo[spoke2].dai2.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 100_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke2].dai2.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 70_00
    });

    spokeInfo[spoke2].wbtc.reserveId = spoke2.addReserve(
      wbtcAssetId,
      address(hub),
      _deployMockPriceFeed(spoke2, 50_000e8),
      spokeInfo[spoke2].wbtc.reserveConfig,
      spokeInfo[spoke2].wbtc.dynReserveConfig
    );
    spokeInfo[spoke2].weth.reserveId = spoke2.addReserve(
      wethAssetId,
      address(hub),
      _deployMockPriceFeed(spoke2, 2000e8),
      spokeInfo[spoke2].weth.reserveConfig,
      spokeInfo[spoke2].weth.dynReserveConfig
    );
    spokeInfo[spoke2].dai.reserveId = spoke2.addReserve(
      daiAssetId,
      address(hub),
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].dai.reserveConfig,
      spokeInfo[spoke2].dai.dynReserveConfig
    );
    spokeInfo[spoke2].usdx.reserveId = spoke2.addReserve(
      usdxAssetId,
      address(hub),
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].usdx.reserveConfig,
      spokeInfo[spoke2].usdx.dynReserveConfig
    );
    spokeInfo[spoke2].usdy.reserveId = spoke2.addReserve(
      usdyAssetId,
      address(hub),
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].usdy.reserveConfig,
      spokeInfo[spoke2].usdy.dynReserveConfig
    );
    spokeInfo[spoke2].dai2.reserveId = spoke2.addReserve(
      dai2AssetId,
      address(hub),
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].dai2.reserveConfig,
      spokeInfo[spoke2].dai2.dynReserveConfig
    );

    hub.addSpoke(wbtcAssetId, address(spoke2), spokeConfig);
    hub.addSpoke(wethAssetId, address(spoke2), spokeConfig);
    hub.addSpoke(daiAssetId, address(spoke2), spokeConfig);
    hub.addSpoke(usdxAssetId, address(spoke2), spokeConfig);
    hub.addSpoke(usdyAssetId, address(spoke2), spokeConfig);
    hub.addSpoke(dai2AssetId, address(spoke2), spokeConfig);

    // Spoke 3 reserve configs
    spokeInfo[spoke3].dai.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 0,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke3].dai.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 75_00
    });
    spokeInfo[spoke3].usdx.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 10_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke3].usdx.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 75_00
    });
    spokeInfo[spoke3].weth.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 20_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke3].weth.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 79_00
    });
    spokeInfo[spoke3].wbtc.reserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 50_00,
      liquidationFee: 0,
      borrowable: true,
      collateral: true
    });
    spokeInfo[spoke3].wbtc.dynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 77_00
    });

    spokeInfo[spoke3].dai.reserveId = spoke3.addReserve(
      daiAssetId,
      address(hub),
      _deployMockPriceFeed(spoke3, 1e8),
      spokeInfo[spoke3].dai.reserveConfig,
      spokeInfo[spoke3].dai.dynReserveConfig
    );
    spokeInfo[spoke3].usdx.reserveId = spoke3.addReserve(
      usdxAssetId,
      address(hub),
      _deployMockPriceFeed(spoke3, 1e8),
      spokeInfo[spoke3].usdx.reserveConfig,
      spokeInfo[spoke3].usdx.dynReserveConfig
    );
    spokeInfo[spoke3].weth.reserveId = spoke3.addReserve(
      wethAssetId,
      address(hub),
      _deployMockPriceFeed(spoke3, 2000e8),
      spokeInfo[spoke3].weth.reserveConfig,
      spokeInfo[spoke3].weth.dynReserveConfig
    );
    spokeInfo[spoke3].wbtc.reserveId = spoke3.addReserve(
      wbtcAssetId,
      address(hub),
      _deployMockPriceFeed(spoke3, 50_000e8),
      spokeInfo[spoke3].wbtc.reserveConfig,
      spokeInfo[spoke3].wbtc.dynReserveConfig
    );

    hub.addSpoke(daiAssetId, address(spoke3), spokeConfig);
    hub.addSpoke(usdxAssetId, address(spoke3), spokeConfig);
    hub.addSpoke(wethAssetId, address(spoke3), spokeConfig);
    hub.addSpoke(wbtcAssetId, address(spoke3), spokeConfig);

    vm.stopPrank();
  }

  /* @dev Configures Hub 2 with the following assetIds:
   * 0: WETH
   * 1: USDX
   * 2: DAI
   * 3: WBTC
   */
  function hub2Fixture() internal returns (ILiquidityHub, AssetInterestRateStrategy) {
    vm.startPrank(ADMIN);

    IAccessManager accessManager2 = new AccessManager(ADMIN);
    ILiquidityHub hub2 = new LiquidityHub(address(accessManager2));
    AssetInterestRateStrategy hub2IrStrategy = new AssetInterestRateStrategy(address(hub2));

    // Add assets to the second hub
    // Add WETH
    hub2.addAsset(
      address(tokenList.weth),
      tokenList.weth.decimals(),
      address(treasurySpoke),
      address(hub2IrStrategy)
    );

    // Add USDX
    hub2.addAsset(
      address(tokenList.usdx),
      tokenList.usdx.decimals(),
      address(treasurySpoke),
      address(hub2IrStrategy)
    );

    // Add DAI
    hub2.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(hub2IrStrategy)
    );

    // Add WBTC
    hub2.addAsset(
      address(tokenList.wbtc),
      tokenList.wbtc.decimals(),
      address(treasurySpoke),
      address(hub2IrStrategy)
    );

    // Configure IR Strategy for hub 2
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    vm.startPrank(address(hub2));
    hub2IrStrategy.setInterestRateData(wethAssetId, encodedIrData);
    hub2IrStrategy.setInterestRateData(usdxAssetId, encodedIrData);
    hub2IrStrategy.setInterestRateData(daiAssetId, encodedIrData);
    hub2IrStrategy.setInterestRateData(wbtcAssetId, encodedIrData);
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
  function hub3Fixture() internal returns (ILiquidityHub, AssetInterestRateStrategy) {
    vm.startPrank(ADMIN);

    IAccessManager accessManager3 = new AccessManager(ADMIN);
    ILiquidityHub hub3 = new LiquidityHub(address(accessManager3));
    AssetInterestRateStrategy hub3IrStrategy = new AssetInterestRateStrategy(address(hub3));

    // Add DAI
    hub3.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(hub3IrStrategy)
    );
    uint256 hub3DaiAssetId = 0;

    // Add USDX
    hub3.addAsset(
      address(tokenList.usdx),
      tokenList.usdx.decimals(),
      address(treasurySpoke),
      address(hub3IrStrategy)
    );
    uint256 hub3UsdxAssetId = 1;

    // Add WBTC
    hub3.addAsset(
      address(tokenList.wbtc),
      tokenList.wbtc.decimals(),
      address(treasurySpoke),
      address(hub3IrStrategy)
    );
    uint256 hub3WbtcAssetId = 2;

    // Add WETH
    hub3.addAsset(
      address(tokenList.weth),
      tokenList.weth.decimals(),
      address(treasurySpoke),
      address(hub3IrStrategy)
    );
    uint256 hub3WethAssetId = 3;
    vm.stopPrank();

    // Configure IR Strategy for hub 3
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    vm.startPrank(address(hub3));
    hub3IrStrategy.setInterestRateData(hub3WethAssetId, encodedIrData);
    hub3IrStrategy.setInterestRateData(hub3UsdxAssetId, encodedIrData);
    hub3IrStrategy.setInterestRateData(hub3DaiAssetId, encodedIrData);
    hub3IrStrategy.setInterestRateData(hub3WbtcAssetId, encodedIrData);
    vm.stopPrank();

    setUpRoles(hub3, spoke1, accessManager3);

    return (hub3, hub3IrStrategy);
  }

  function updateAssetActive(
    ILiquidityHub liquidityHub,
    uint256 assetId,
    bool newActiveFlag
  ) internal {
    DataTypes.AssetConfig memory assetConfig = liquidityHub.getAsset(assetId).config;
    assetConfig.active = newActiveFlag;

    vm.prank(HUB_ADMIN);
    liquidityHub.updateAssetConfig(assetId, assetConfig);
  }

  function updateAssetPaused(
    ILiquidityHub liquidityHub,
    uint256 assetId,
    bool newPausedFlag
  ) internal {
    DataTypes.AssetConfig memory assetConfig = liquidityHub.getAsset(assetId).config;
    assetConfig.paused = newPausedFlag;

    vm.prank(HUB_ADMIN);
    liquidityHub.updateAssetConfig(assetId, assetConfig);
  }

  function updateAssetFrozen(
    ILiquidityHub liquidityHub,
    uint256 assetId,
    bool newFrozenFlag
  ) internal {
    DataTypes.AssetConfig memory assetConfig = liquidityHub.getAsset(assetId).config;
    assetConfig.frozen = newFrozenFlag;

    vm.prank(HUB_ADMIN);
    liquidityHub.updateAssetConfig(assetId, assetConfig);
  }

  function updateAssetFeeReceiver(
    ILiquidityHub liquidityHub,
    uint256 assetId,
    address newFeeReceiver
  ) internal {
    DataTypes.AssetConfig memory assetConfig = liquidityHub.getAsset(assetId).config;
    assetConfig.feeReceiver = newFeeReceiver;

    vm.prank(HUB_ADMIN);
    liquidityHub.updateAssetConfig(assetId, assetConfig);
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

  function updateLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newLiquidationBonus
  ) internal {
    DataTypes.ReserveConfig memory config = spoke.getReserve(reserveId).config;
    config.liquidationBonus = newLiquidationBonus;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserve(reserveId).config.liquidationBonus, newLiquidationBonus);
  }

  function updateLiquidationFee(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newLiquidationFee
  ) internal {
    DataTypes.ReserveConfig memory config = spoke.getReserve(reserveId).config;
    config.liquidationFee = newLiquidationFee;

    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, config);

    assertEq(spoke.getReserve(reserveId).config.liquidationFee, newLiquidationFee);
  }

  function updateCollateralFactor(
    ISpoke spoke,
    function(ISpoke) pure returns (uint256) reserveIdFn,
    uint256 newCollateralFactor
  ) internal {
    uint256 reserveId = reserveIdFn(spoke);
    DataTypes.DynamicReserveConfig memory config = spoke.getDynamicReserveConfig(reserveId);
    config.collateralFactor = newCollateralFactor.toUint16();

    vm.prank(SPOKE_ADMIN);
    spoke.updateDynamicReserveConfig(reserveId, config);

    assertEq(spoke.getDynamicReserveConfig(reserveId).collateralFactor, newCollateralFactor);
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
    DataTypes.DynamicReserveConfig memory config = spoke.getDynamicReserveConfig(reserveId);
    config.collateralFactor = newCollateralFactor.toUint16();
    vm.prank(SPOKE_ADMIN);
    spoke.updateDynamicReserveConfig(reserveId, config);
  }

  function updateCollateralFlag(ISpoke spoke, uint256 reserveId, bool newCollateralFlag) internal {
    DataTypes.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.collateral = newCollateralFlag;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateReserveBorrowableFlag(
    ISpoke spoke,
    uint256 reserveId,
    bool newBorrowable
  ) internal {
    DataTypes.Reserve memory reserveData = spoke.getReserve(reserveId);
    reserveData.config.borrowable = newBorrowable;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, reserveData.config);
  }

  function updateLiquidityPremium(
    ISpoke spoke,
    uint256 reserveId,
    uint256 newLiquidityPremium
  ) internal {
    DataTypes.ReserveConfig memory reserveConfig = spoke.getReserve(reserveId).config;
    reserveConfig.liquidityPremium = newLiquidityPremium;
    vm.prank(SPOKE_ADMIN);
    spoke.updateReserveConfig(reserveId, reserveConfig);
  }

  function updateLiquidityFee(
    ILiquidityHub liquidityHub,
    uint256 assetId,
    uint256 liquidityFee
  ) internal {
    DataTypes.AssetConfig memory config = liquidityHub.getAssetConfig(assetId);
    config.liquidityFee = liquidityFee;
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, config);
  }

  function updateCloseFactor(ISpoke spoke, uint256 newCloseFactor) internal {
    DataTypes.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
    liqConfig.closeFactor = newCloseFactor;
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(liqConfig);

    assertEq(spoke.getLiquidationConfig().closeFactor, newCloseFactor);
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

  function updateDrawCap(
    ILiquidityHub liquidityHub,
    uint256 assetId,
    address spoke,
    uint256 newDrawCap
  ) internal {
    DataTypes.SpokeConfig memory spokeConfig = liquidityHub.getSpokeConfig(assetId, spoke);
    spokeConfig.drawCap = newDrawCap;
    vm.prank(HUB_ADMIN);
    liquidityHub.updateSpokeConfig(assetId, spoke, spokeConfig);
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

  function getSpokeInfo(
    uint256 assetId,
    address spoke
  ) internal view returns (DataTypes.SpokeData memory) {
    return hub.getSpoke(assetId, spoke);
  }

  function getAssetInfo(uint256 assetId) internal view returns (DataTypes.Asset memory) {
    return hub.getAsset(assetId);
  }

  function getAssetByReserveId(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint256, IERC20) {
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    return (reserve.assetId, IERC20(reserve.underlying));
  }

  function getWithdrawalLimit(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getUserSuppliedAmount(reserveId, user);
  }

  /// @dev Helper function to calculate asset amount corresponding to single drawn share
  function minimumAssetsPerDrawnShare(uint256 assetId) internal view returns (uint256) {
    return hub.convertToDrawnAssets(assetId, 1);
  }

  /// @dev Helper function to calculate asset amount corresponding to single supplied share
  function minimumAssetsPerSuppliedShare(uint256 assetId) internal view returns (uint256) {
    return hub.convertToSuppliedAssetsUp(assetId, 1);
  }

  /// @dev Helper function to calculate expected supplied assets based on amount to supply and current exchange rate
  /// taking potential donation into account
  function calculateEffectiveSuppliedAssets(
    uint256 assetsAmount,
    uint256 totalSuppliedAssets,
    uint256 totalSuppliedShares
  ) internal view returns (uint256) {
    uint256 sharesAmount = assetsAmount.toSharesDown(totalSuppliedAssets, totalSuppliedShares);
    return
      sharesAmount.toAssetsDown(
        totalSuppliedAssets + assetsAmount,
        totalSuppliedShares + sharesAmount
      );
  }

  function getSupplyExRate(uint256 assetId) internal view returns (uint256) {
    return hub.convertToSuppliedAssets(assetId, MAX_SUPPLY_AMOUNT);
  }

  function getDebtExRate(uint256 assetId) internal view returns (uint256) {
    return hub.convertToDrawnAssets(assetId, MAX_SUPPLY_AMOUNT);
  }

  /// TODO: Once inflation protection implemented, can remove boolean param since rate should always monotonically increase
  /// @dev Helper function to ensure supply exchange rate is monotonically increasing
  function _checkSupplyRateIncreasing(
    uint256 oldRate,
    uint256 newRate,
    bool allWithdrawn,
    string memory label
  ) internal pure {
    if (!allWithdrawn) {
      assertGe(newRate, oldRate, string.concat('supply rate monotonically increasing ', label));
    }
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
      (amount * oracle.getReservePrice(reserveId).wadify()) /
      (10 ** hub.getAsset(assetId).decimals);
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
  // @return baseDebtRestored amount of base debt to restore
  // @return premiumDebtRestored amount of premium debt to restore
  function _calculateExactRestoreAmount(
    uint256 baseDebt,
    uint256 premiumDebt,
    uint256 restoreAmount,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    if (restoreAmount <= premiumDebt) {
      return (0, restoreAmount);
    }
    uint256 baseDebtRestored = _min(baseDebt, restoreAmount - premiumDebt);
    // round base debt to nearest whole share
    baseDebtRestored = hub.convertToDrawnAssets(
      assetId,
      hub.convertToDrawnShares(assetId, baseDebtRestored)
    );
    return (baseDebtRestored, premiumDebt);
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
    uint256 expectedSuppliedShares = hub.convertToSuppliedShares(assetId, expectedSuppliedAmount);
    assertEq(
      hub.getAssetSuppliedShares(assetId),
      expectedSuppliedShares,
      string(abi.encodePacked('asset supplied shares ', label))
    );
    assertEq(
      hub.getAssetSuppliedAmount(assetId),
      expectedSuppliedAmount,
      string(abi.encodePacked('asset supplied amount ', label))
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke)),
      expectedSuppliedShares,
      string(abi.encodePacked('spoke supplied shares ', label))
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke)),
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
    uint256 expectedBaseDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    (uint256 actualBaseDebt, uint256 actualPremiumDebt) = spoke.getUserDebt(reserveId, user);
    assertApproxEqAbs(actualBaseDebt, expectedBaseDebt, 1, string.concat('user base debt ', label));
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      2,
      string.concat('user premium debt ', label)
    );
    assertApproxEqAbs(
      spoke.getUserTotalDebt(reserveId, user),
      expectedBaseDebt + expectedPremiumDebt,
      2,
      string.concat('user total debt ', label)
    );
  }

  function _assertReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedBaseDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    (uint256 actualBaseDebt, uint256 actualPremiumDebt) = spoke.getReserveDebt(reserveId);
    assertApproxEqAbs(
      actualBaseDebt,
      expectedBaseDebt,
      1,
      string.concat('reserve base debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      2,
      string.concat('reserve premium debt ', label)
    );
    assertApproxEqAbs(
      spoke.getReserveTotalDebt(reserveId),
      expectedBaseDebt + expectedPremiumDebt,
      2,
      string.concat('reserve total debt ', label)
    );
  }

  function _assertSpokeDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedBaseDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    (uint256 actualBaseDebt, uint256 actualPremiumDebt) = hub.getSpokeDebt(assetId, address(spoke));
    assertApproxEqAbs(
      actualBaseDebt,
      expectedBaseDebt,
      1,
      string.concat('spoke base debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      2,
      string.concat('spoke premium debt ', label)
    );
    assertApproxEqAbs(
      hub.getSpokeTotalDebt(assetId, address(spoke)),
      expectedBaseDebt + expectedPremiumDebt,
      2,
      string.concat('spoke total debt ', label)
    );
  }

  function _assertAssetDebt(
    ISpoke spoke,
    uint256 reserveId,
    uint256 expectedBaseDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    (uint256 actualBaseDebt, uint256 actualPremiumDebt) = hub.getAssetDebt(assetId);
    assertApproxEqAbs(
      actualBaseDebt,
      expectedBaseDebt,
      1,
      string.concat('asset base debt ', label)
    );
    assertApproxEqAbs(
      actualPremiumDebt,
      expectedPremiumDebt,
      2,
      string.concat('asset premium debt ', label)
    );
    assertApproxEqAbs(
      hub.getAssetTotalDebt(assetId),
      expectedBaseDebt + expectedPremiumDebt,
      2,
      string.concat('asset total debt ', label)
    );
  }

  function _assertSingleUserProtocolDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 expectedBaseDebt,
    uint256 expectedPremiumDebt,
    string memory label
  ) internal view {
    _assertUserDebt(spoke, reserveId, user, expectedBaseDebt, expectedPremiumDebt, label);

    _assertReserveDebt(spoke, reserveId, expectedBaseDebt, expectedPremiumDebt, label);

    _assertSpokeDebt(spoke, reserveId, expectedBaseDebt, expectedPremiumDebt, label);

    _assertAssetDebt(spoke, reserveId, expectedBaseDebt, expectedPremiumDebt, label);
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
      2,
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
      2,
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
      hub.getSpokeSuppliedAmount(assetId, address(spoke)),
      expectedSuppliedAmount,
      2,
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
      hub.getAssetSuppliedAmount(assetId),
      expectedSuppliedAmount,
      2,
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
        10 ** hub.getAsset(assetId).decimals
      );
  }

  function _convertAmountToBaseCurrency(
    uint256 amount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return (amount * assetPrice).wadify() / assetUnit;
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
        10 ** hub.getAsset(assetId).decimals
      );
  }

  /// @dev Convert base currency to asset amount
  function _convertBaseCurrencyToAmount(
    uint256 baseCurrencyAmount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal pure returns (uint256) {
    return ((baseCurrencyAmount * assetUnit) / assetPrice).dewadifyDown();
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
      totalCollateralBase.percentMul(currentAvgCollateralFactor.dewadifyDown() + 1).wadDivUp(
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

  function _getCloseFactor(ISpoke spoke) internal view returns (uint256) {
    return spoke.getLiquidationConfig().closeFactor;
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
  function _calculateExpectedDebtIndex(
    uint256 initialDebtIndex,
    uint256 borrowRate,
    uint40 startTime
  ) internal view returns (uint256) {
    return initialDebtIndex.rayMulUp(MathUtils.calculateLinearInterest(borrowRate, startTime));
  }

  /// @dev Calculate expected debt index and base debt based on input params
  function calculateExpectedDebt(
    uint256 initialDrawnShares,
    uint256 initialDebtIndex,
    uint256 borrowRate,
    uint40 startTime
  ) internal view returns (uint256 newDebtIndex, uint256 newBaseDebt) {
    newDebtIndex = _calculateExpectedDebtIndex(initialDebtIndex, borrowRate, startTime);
    newBaseDebt = initialDrawnShares.rayMulUp(newDebtIndex);
  }

  /// @dev Calculate expected base debt based on specified borrow rate
  function _calculateExpectedBaseDebt(
    uint256 initialDebt,
    uint256 borrowRate,
    uint40 startTime
  ) internal view returns (uint256) {
    return MathUtils.calculateLinearInterest(borrowRate, startTime).rayMulUp(initialDebt);
  }

  /// @dev Calculate expected premium debt based on change in base debt and user rp
  function _calculateExpectedPremiumDebt(
    uint256 initialBaseDebt,
    uint256 currentBaseDebt,
    uint256 userRiskPremium
  ) internal pure returns (uint256) {
    return (currentBaseDebt - initialBaseDebt).percentMulUp(userRiskPremium);
  }

  /// @dev Helper function to get asset base debt
  function getAssetBaseDebt(uint256 assetId) internal view returns (uint256) {
    (uint256 baseDebt, ) = hub.getAssetDebt(assetId);
    return baseDebt;
  }

  /// @dev Helper function to withdraw fees from the treasury spoke
  function withdrawLiquidityFees(uint256 assetId, uint256 amount) internal {
    uint256 fees = hub.getSpokeSuppliedAmount(assetId, address(treasurySpoke));
    if (amount > fees) {
      amount = fees;
    }
    if (amount == 0) {
      return; // nothing to withdraw
    }
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(assetId, amount, address(treasurySpoke));
  }

  function _assumeValidSupplier(address user) internal {
    vm.assume(
      user != address(0) &&
        user != address(hub) &&
        user != address(spoke1) &&
        user != address(spoke2) &&
        user != address(spoke3)
    );
  }

  function _getLiquidityFee(uint256 assetId) internal view returns (uint256) {
    return hub.getAssetConfig(assetId).liquidityFee;
  }

  function _getFeeReceiver(uint256 assetId) internal view returns (address) {
    return hub.getAssetConfig(assetId).feeReceiver;
  }

  function _getLiquidityPremium(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
    return spoke.getReserveConfig(reserveId).liquidityPremium;
  }

  function _getCollateralFactor(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
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
    assertEq(a.active, b.active, 'assertEq(AssetConfig): active');
    assertEq(a.paused, b.paused, 'assertEq(AssetConfig): paused');
    assertEq(a.frozen, b.frozen, 'assertEq(AssetConfig): frozen');
    assertEq(a.feeReceiver, b.feeReceiver, 'assertEq(AssetConfig): feeReceiver');
    assertEq(a.liquidityFee, b.liquidityFee, 'assertEq(AssetConfig): liquidityFee');
    assertEq(a.irStrategy, b.irStrategy, 'assertEq(AssetConfig): irStrategy');
    assertEq(abi.encode(a), abi.encode(b), 'assertEq(AssetConfig): all fields');
  }

  function assertEq(DataTypes.SpokeConfig memory a, DataTypes.SpokeConfig memory b) internal pure {
    assertEq(a.supplyCap, b.supplyCap, 'assertEq(SpokeConfig): supplyCap');
    assertEq(a.drawCap, b.drawCap, 'assertEq(SpokeConfig): drawCap');
    assertEq(a.active, b.active, 'assertEq(SpokeConfig): active');
    assertEq(abi.encode(a), abi.encode(b), 'assertEq(SpokeConfig): all fields');
  }

  function _calculateExpectedFees(
    uint256 baseDebtIncrease,
    uint256 premiumDebtIncrease,
    uint256 liquidityFee
  ) internal pure returns (uint256) {
    return (baseDebtIncrease + premiumDebtIncrease).percentMulDown(liquidityFee);
  }

  function _calculateExpectedFeesAmount(
    uint256 initialDrawnShares,
    uint256 initialPremiumShares,
    uint256 liquidityFee,
    uint256 indexDelta
  ) internal view returns (uint256 feesAmount) {
    return
      indexDelta.rayMulDown(initialDrawnShares + initialPremiumShares).percentMulDown(liquidityFee);
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
    uint256 availableLiquidity,
    uint256 baseDebt,
    uint256 premiumDebt
  ) internal {
    _mockInterestRateBps(
      address(irStrategy),
      interestRateBps,
      assetId,
      availableLiquidity,
      baseDebt,
      premiumDebt
    );
  }

  function _mockInterestRateBps(
    address interestRateStrategy,
    uint256 interestRateBps,
    uint256 assetId,
    uint256 availableLiquidity,
    uint256 baseDebt,
    uint256 premiumDebt
  ) internal {
    vm.mockCall(
      interestRateStrategy,
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, availableLiquidity, baseDebt, premiumDebt)
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
    uint256 availableLiquidity,
    uint256 baseDebt,
    uint256 premiumDebt
  ) internal {
    _mockInterestRateRay(
      address(irStrategy),
      interestRateRay,
      assetId,
      availableLiquidity,
      baseDebt,
      premiumDebt
    );
  }

  function _mockInterestRateRay(
    address interestRateStrategy,
    uint256 interestRateRay,
    uint256 assetId,
    uint256 availableLiquidity,
    uint256 baseDebt,
    uint256 premiumDebt
  ) internal {
    vm.mockCall(
      interestRateStrategy,
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (assetId, availableLiquidity, baseDebt, premiumDebt)
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
    ILiquidityHub hub,
    uint256 assetId,
    string memory operation
  ) internal {
    DataTypes.Asset memory asset = hub.getAsset(assetId);
    (uint256 baseDebt, uint256 premiumDebt) = hub.getAssetDebt(assetId);

    vm.assertEq(
      asset.baseBorrowRate,
      IBasicInterestRateStrategy(asset.config.irStrategy).calculateInterestRate(
        assetId,
        asset.availableLiquidity,
        baseDebt,
        premiumDebt
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
}
