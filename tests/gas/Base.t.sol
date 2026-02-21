// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// dependencies
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Roles} from 'src/libraries/types/Roles.sol';

// hub
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {
  AssetInterestRateStrategy,
  IAssetInterestRateStrategy
} from 'src/hub/AssetInterestRateStrategy.sol';

// spoke
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';
import {TreasurySpoke, ITreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

// tokenization spoke
import {ITokenizationSpoke} from 'src/spoke/TokenizationSpoke.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

// position manager
import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import {SignatureGateway, ISignatureGateway} from 'src/position-manager/SignatureGateway.sol';

// helpers
import 'tests/helpers/hub/HubHelpers.sol';
import 'tests/helpers/spoke/SpokeHelpers.sol';
import 'tests/helpers/deploy/DeployHelpers.sol';

// mocks
import {EIP712Types} from 'tests/helpers/mocks/EIP712Types.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {ISpokeInstance} from 'tests/helpers/mocks/ISpokeInstance.sol';

/// @title Gas test base
/// @notice Minimal, self-contained base for gas benchmarks.
abstract contract Base is HubHelpers, SpokeHelpers {
  using WadRayMath for *;
  using PercentageMath for uint256;
  using SafeCast for *;

  // ──────────────────────────── Structs ────────────────────────────

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
  }

  struct ReserveIds {
    uint256 dai;
    uint256 weth;
    uint256 usdx;
    uint256 wbtc;
  }

  // ──────────────────────────── State ──────────────────────────────

  uint256 internal MAX_SUPPLY_AMOUNT_WETH;
  IHubBase.PremiumDelta internal ZERO_PREMIUM_DELTA;

  IHub internal hub1;
  ITreasurySpoke internal treasurySpoke;
  ISpoke internal spoke1;
  ISpoke internal spoke2;
  AssetInterestRateStrategy internal irStrategy;
  IAccessManager internal accessManager;

  string internal constant ALICE = 'alice';
  string internal constant BOB = 'bob';

  address internal alice = makeAddr(ALICE);
  uint256 internal alicePk = makeKey(ALICE);
  address internal bob = makeAddr(BOB);
  uint256 internal bobPk = makeKey(BOB);

  address internal ADMIN = makeAddr('ADMIN');
  address internal HUB_ADMIN = makeAddr('HUB_ADMIN');
  address internal SPOKE_ADMIN = makeAddr('SPOKE_ADMIN');
  address internal USER_POSITION_UPDATER = makeAddr('USER_POSITION_UPDATER');
  address internal TREASURY_ADMIN = makeAddr('TREASURY_ADMIN');

  TokenList internal tokenList;
  uint256 internal wethAssetId = 0;
  uint256 internal usdxAssetId = 1;
  uint256 internal daiAssetId = 2;
  uint256 internal wbtcAssetId = 3;

  mapping(ISpoke => SpokeInfo) internal spokeInfo;

  // ──────────────────────────── Setup ──────────────────────────────

  function setUp() public virtual {
    deployFixtures();
    initEnvironment();
  }

  function deployFixtures() internal virtual {
    vm.startPrank(ADMIN);
    accessManager = IAccessManager(address(new AccessManagerEnumerable(ADMIN)));
    hub1 = DeployUtils.deployHub(address(accessManager));
    irStrategy = new AssetInterestRateStrategy(address(hub1));
    (spoke1, ) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 1 (USD)');
    (spoke2, ) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 2 (USD)');
    treasurySpoke = ITreasurySpoke(new TreasurySpoke(TREASURY_ADMIN, address(hub1)));
    vm.stopPrank();

    vm.label(address(spoke1), 'spoke1');
    vm.label(address(spoke2), 'spoke2');

    _setUpRoles(hub1, spoke1, accessManager);
    _setUpRoles(hub1, spoke2, accessManager);
  }

  function _setUpRoles(IHub targetHub, ISpoke spoke, IAccessManager manager) internal {
    vm.startPrank(ADMIN);

    manager.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    manager.grantRole(Roles.HUB_ADMIN_ROLE, HUB_ADMIN, 0);
    manager.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);
    manager.grantRole(Roles.SPOKE_ADMIN_ROLE, SPOKE_ADMIN, 0);
    manager.grantRole(Roles.USER_POSITION_UPDATER_ROLE, SPOKE_ADMIN, 0);
    manager.grantRole(Roles.USER_POSITION_UPDATER_ROLE, USER_POSITION_UPDATER, 0);

    {
      bytes4[] memory selectors = new bytes4[](7);
      selectors[0] = ISpoke.updateLiquidationConfig.selector;
      selectors[1] = ISpoke.addReserve.selector;
      selectors[2] = ISpoke.updateReserveConfig.selector;
      selectors[3] = ISpoke.updateDynamicReserveConfig.selector;
      selectors[4] = ISpoke.addDynamicReserveConfig.selector;
      selectors[5] = ISpoke.updatePositionManager.selector;
      selectors[6] = ISpoke.updateReservePriceSource.selector;
      manager.setTargetFunctionRole(address(spoke), selectors, Roles.SPOKE_ADMIN_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](2);
      selectors[0] = ISpoke.updateUserDynamicConfig.selector;
      selectors[1] = ISpoke.updateUserRiskPremium.selector;
      manager.setTargetFunctionRole(address(spoke), selectors, Roles.USER_POSITION_UPDATER_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](6);
      selectors[0] = IHub.addAsset.selector;
      selectors[1] = IHub.updateAssetConfig.selector;
      selectors[2] = IHub.addSpoke.selector;
      selectors[3] = IHub.updateSpokeConfig.selector;
      selectors[4] = IHub.setInterestRateData.selector;
      selectors[5] = IHub.mintFeeShares.selector;
      manager.setTargetFunctionRole(address(targetHub), selectors, Roles.HUB_ADMIN_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](1);
      selectors[0] = IHub.eliminateDeficit.selector;
      manager.setTargetFunctionRole(address(targetHub), selectors, Roles.DEFICIT_ELIMINATOR_ROLE);
    }

    vm.stopPrank();
  }

  function initEnvironment() internal {
    _deployMintAndApproveTokenList();
    _configureTokenList();
  }

  function _deployMintAndApproveTokenList() internal {
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

    MAX_SUPPLY_AMOUNT_WETH = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.weth.decimals();

    address[2] memory users = [alice, bob];
    address[2] memory spokes = [address(spoke1), address(spoke2)];

    for (uint256 x; x < users.length; ++x) {
      tokenList.usdx.mint(users[x], MAX_SUPPLY_AMOUNT);
      tokenList.dai.mint(users[x], MAX_SUPPLY_AMOUNT);
      tokenList.wbtc.mint(users[x], MAX_SUPPLY_AMOUNT);
      deal(address(tokenList.weth), users[x], MAX_SUPPLY_AMOUNT);

      vm.startPrank(users[x]);
      for (uint256 y; y < spokes.length; ++y) {
        tokenList.weth.approve(spokes[y], UINT256_MAX);
        tokenList.usdx.approve(spokes[y], UINT256_MAX);
        tokenList.dai.approve(spokes[y], UINT256_MAX);
        tokenList.wbtc.approve(spokes[y], UINT256_MAX);
      }
      vm.stopPrank();
    }
  }

  function _configureTokenList() internal {
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: HubConstants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: HubConstants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: SpokeConstants.MAX_ALLOWED_COLLATERAL_RISK
    });

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseVariableBorrowRate: 5_00,
        variableRateSlope1: 5_00,
        variableRateSlope2: 5_00
      })
    );

    vm.startPrank(ADMIN);

    // ── Hub assets ──
    hub1.addAsset(
      address(tokenList.weth),
      tokenList.weth.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      wethAssetId,
      IHub.AssetConfig({
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    hub1.addAsset(
      address(tokenList.usdx),
      tokenList.usdx.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      usdxAssetId,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    hub1.addAsset(
      address(tokenList.dai),
      tokenList.dai.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      daiAssetId,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    hub1.addAsset(
      address(tokenList.wbtc),
      tokenList.wbtc.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      wbtcAssetId,
      IHub.AssetConfig({
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );

    // ── Spoke 1 liquidation config ──
    spoke1.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.7e18,
        liquidationBonusFactor: 20_00
      })
    );

    // ── Spoke 1 reserves ──
    spokeInfo[spoke1].weth.reserveConfig = _getDefaultReserveConfig(15_00);
    spokeInfo[spoke1].weth.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 105_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke1].wbtc.reserveConfig = _getDefaultReserveConfig(15_00);
    spokeInfo[spoke1].wbtc.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 75_00,
      maxLiquidationBonus: 103_00,
      liquidationFee: 15_00
    });
    spokeInfo[spoke1].dai.reserveConfig = _getDefaultReserveConfig(20_00);
    spokeInfo[spoke1].dai.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 102_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke1].usdx.reserveConfig = _getDefaultReserveConfig(50_00);
    spokeInfo[spoke1].usdx.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 101_00,
      liquidationFee: 12_00
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

    hub1.addSpoke(wethAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(wbtcAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(daiAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke1), spokeConfig);

    // ── Spoke 2 (hub-level only, no reserves needed) ──
    hub1.addSpoke(wethAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(daiAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(wbtcAssetId, address(spoke2), spokeConfig);

    vm.stopPrank();
  }

  // ──────────────────────────── Deploy helpers ─────────────────────

  function _deploySpokeWithOracle(
    address proxyAdminOwner,
    address _accessManager,
    string memory _oracleDesc
  ) internal pausePrank returns (ISpoke, IAaveOracle) {
    address deployer = makeAddr('deployer');

    vm.startPrank(deployer);
    IAaveOracle oracle = new AaveOracle(8, _oracleDesc);
    ISpoke spoke = DeployUtils.deploySpoke(
      address(oracle),
      SpokeConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
      proxyAdminOwner,
      abi.encodeCall(ISpokeInstance.initialize, (_accessManager))
    );
    oracle.setSpoke(address(spoke));
    vm.stopPrank();

    return (spoke, oracle);
  }

  function _deployTokenizationSpoke(
    IHub hub,
    uint256 assetId,
    string memory shareName,
    string memory shareSymbol,
    address proxyAdminOwner
  ) internal pausePrank returns (ITokenizationSpoke) {
    address tokenizationSpokeImpl = address(new TokenizationSpokeInstance(address(hub), assetId));
    return
      ITokenizationSpoke(
        DeployUtils.proxify(
          tokenizationSpokeImpl,
          proxyAdminOwner,
          abi.encodeCall(TokenizationSpokeInstance.initialize, (shareName, shareSymbol))
        )
      );
  }

  function _registerTokenizationSpoke(
    IHub hub,
    uint256 assetId,
    ITokenizationSpoke tokenizationSpoke
  ) internal pausePrank {
    vm.prank(ADMIN);
    hub.addSpoke(
      assetId,
      address(tokenizationSpoke),
      IHub.SpokeConfig({
        addCap: type(uint40).max,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    );
  }

  function _getDefaultReserveConfig(
    uint24 collateralRisk
  ) internal pure returns (ISpoke.ReserveConfig memory) {
    return
      ISpoke.ReserveConfig({
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true,
        collateralRisk: collateralRisk
      });
  }

  // ──────────────────────────── Reserve ID lookups ─────────────────

  function _wethReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].weth.reserveId;
  }

  function _wbtcReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].wbtc.reserveId;
  }

  function _daiReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }

  function _usdxReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdx.reserveId;
  }

  function _getReserveIds(ISpoke spoke) internal view returns (ReserveIds memory) {
    return
      ReserveIds({
        dai: _daiReserveId(spoke),
        weth: _wethReserveId(spoke),
        usdx: _usdxReserveId(spoke),
        wbtc: _wbtcReserveId(spoke)
      });
  }
}
