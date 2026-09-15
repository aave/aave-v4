// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';

import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';
import {TestTypes} from 'tests/utils/TestTypes.sol';
import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';
import {AccessManagerEngine} from 'src/config-engine/libraries/AccessManagerEngine.sol';
import {HubEngine} from 'src/config-engine/libraries/HubEngine.sol';
import {SpokeEngine} from 'src/config-engine/libraries/SpokeEngine.sol';
import {PositionManagerEngine} from 'src/config-engine/libraries/PositionManagerEngine.sol';
import {TokenizationSpokeDeployer} from 'src/config-engine/libraries/TokenizationSpokeDeployer.sol';

import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {AaveV4PayloadWrapper} from 'tests/helpers/mocks/config-engine/AaveV4PayloadWrapper.sol';
import {MockGovernanceExecutor} from 'tests/helpers/mocks/config-engine/MockGovernanceExecutor.sol';
import {MockPriceFeed} from 'tests/helpers/mocks/MockPriceFeed.sol';
import {PositionManagerBaseWrapper} from 'tests/helpers/mocks/PositionManagerBaseWrapper.sol';

abstract contract BaseConfigEngineTest is Test, Create2TestHelper {
  uint256 internal constant NUM_HUBS = 2;
  uint256 internal constant NUM_SPOKES = 3;
  uint256 internal constant NUM_TOKENS = 4;

  uint256 internal constant TOKEN_WETH = 0;
  uint256 internal constant TOKEN_USDX = 1;
  uint256 internal constant TOKEN_DAI = 2;
  uint256 internal constant TOKEN_WBTC = 3;

  struct TokenInfo {
    address token;
    address priceFeed;
    uint8 decimals;
  }

  uint256 internal constant LIQUIDITY_FEE = 5_00;
  uint256 internal constant DYNAMIC_CONFIG_KEY = 0;

  IAssetInterestRateStrategy.InterestRateData internal IR_DATA =
    IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 80_00,
      baseDrawnRate: 1_00,
      rateGrowthBeforeOptimal: 4_00,
      rateGrowthAfterOptimal: 60_00
    });

  address internal ADMIN = makeAddr('ADMIN');
  address internal FEE_RECEIVER = makeAddr('FEE_RECEIVER');
  address internal REINVESTMENT_CONTROLLER = makeAddr('REINVESTMENT_CONTROLLER');
  address internal ACCOUNT = makeAddr('ACCOUNT');
  address internal TARGET = makeAddr('TARGET');
  address internal USER = makeAddr('USER');
  address internal PAYLOADS_CONTROLLER = makeAddr('PAYLOADS_CONTROLLER');
  address internal PROXY_ADMIN_OWNER = makeAddr('PROXY_ADMIN_OWNER');

  MockGovernanceExecutor internal executor;
  AaveV4ConfigEngine internal engine;
  IAccessManager internal accessManager;
  IHubConfigurator internal hubConfigurator;
  ISpokeConfigurator internal spokeConfigurator;
  PositionManagerBaseWrapper internal positionManager;

  IHub[NUM_HUBS] internal hubs;
  AssetInterestRateStrategy[NUM_HUBS] internal irStrategies;

  ISpoke[NUM_SPOKES] internal spokes;
  IAaveOracle[NUM_SPOKES] internal oracles;

  WETH9 internal weth;
  TestnetERC20 internal usdx;
  TestnetERC20 internal dai;
  TestnetERC20 internal wbtc;
  TestnetERC20 internal newToken;

  MockPriceFeed internal priceFeedWeth;
  MockPriceFeed internal priceFeedUsdx;
  MockPriceFeed internal priceFeedDai;
  MockPriceFeed internal priceFeedWbtc;
  MockPriceFeed internal priceFeedNew;

  TokenInfo[NUM_TOKENS] internal tokenList;

  uint256[NUM_TOKENS][NUM_HUBS] internal assetIds;

  uint256[NUM_TOKENS][NUM_SPOKES] internal reserveIds;

  function setUp() public virtual {
    _etchCreate2Factory();

    weth = new WETH9();
    usdx = new TestnetERC20('USDX', 'USDX', 6);
    dai = new TestnetERC20('DAI', 'DAI', 18);
    wbtc = new TestnetERC20('WBTC', 'WBTC', 8);
    newToken = new TestnetERC20('NEW', 'NEW', 18);

    priceFeedWeth = new MockPriceFeed(8, 'ETH/USD', 2000e8);
    priceFeedUsdx = new MockPriceFeed(8, 'USDX/USD', 1e8);
    priceFeedDai = new MockPriceFeed(8, 'DAI/USD', 1e8);
    priceFeedWbtc = new MockPriceFeed(8, 'WBTC/USD', 40000e8);
    priceFeedNew = new MockPriceFeed(8, 'NEW/USD', 100e8);

    tokenList[TOKEN_WETH] = TokenInfo(address(weth), address(priceFeedWeth), 18);
    tokenList[TOKEN_USDX] = TokenInfo(address(usdx), address(priceFeedUsdx), 6);
    tokenList[TOKEN_DAI] = TokenInfo(address(dai), address(priceFeedDai), 18);
    tokenList[TOKEN_WBTC] = TokenInfo(address(wbtc), address(priceFeedWbtc), 8);

    vm.startPrank(ADMIN);
    TestTypes.TestEnvReport memory report = AaveV4TestOrchestration.deployTestEnv({
      admin: ADMIN,
      treasuryAdmin: ADMIN,
      hubCount: NUM_HUBS,
      spokeCount: NUM_SPOKES,
      nativeWrapper: address(weth),
      hubBytecode: BytecodeHelper.getHubBytecode(),
      spokeBytecode: BytecodeHelper.getSpokeBytecode(),
      salt: bytes32(0)
    });
    vm.stopPrank();

    accessManager = IAccessManager(report.accessManager);
    hubConfigurator = IHubConfigurator(report.configuratorReport.hubConfigurator);
    spokeConfigurator = ISpokeConfigurator(report.configuratorReport.spokeConfigurator);

    hubs[0] = IHub(report.hubReports[0].hub);
    hubs[1] = IHub(report.hubReports[1].hub);
    irStrategies[0] = AssetInterestRateStrategy(report.hubReports[0].irStrategy);
    irStrategies[1] = AssetInterestRateStrategy(report.hubReports[1].irStrategy);

    for (uint256 i; i < NUM_SPOKES; ++i) {
      spokes[i] = ISpoke(report.spokeReports[i].spoke);
      oracles[i] = IAaveOracle(report.spokeReports[i].aaveOracle);
    }

    executor = new MockGovernanceExecutor(PAYLOADS_CONTROLLER);
    engine = new AaveV4ConfigEngine();
    positionManager = new PositionManagerBaseWrapper(address(engine));

    _setupRoles(report);

    vm.label(address(hubs[0]), 'hub1');
    vm.label(address(hubs[1]), 'hub2');
    vm.label(address(spokes[0]), 'spoke1');
    vm.label(address(spokes[1]), 'spoke2');
    vm.label(address(spokes[2]), 'spoke3');
  }

  function hub1() public view returns (IHub) {
    return hubs[0];
  }
  function hub2() public view returns (IHub) {
    return hubs[1];
  }
  function spoke1() public view returns (ISpoke) {
    return spokes[0];
  }
  function spoke2() public view returns (ISpoke) {
    return spokes[1];
  }
  function spoke3() public view returns (ISpoke) {
    return spokes[2];
  }
  function irStrategy1() public view returns (AssetInterestRateStrategy) {
    return irStrategies[0];
  }
  function irStrategy2() public view returns (AssetInterestRateStrategy) {
    return irStrategies[1];
  }

  function _assertExactEventCount(uint256 expectedCount) internal {
    assertEq(vm.getRecordedLogs().length, expectedCount);
  }

  function _deployNewSpoke() internal returns (ISpoke, IAaveOracle) {
    vm.startPrank(ADMIN);
    TestTypes.TestSpokeReport memory report = AaveV4TestOrchestration.deployTestSpoke(
      ADMIN,
      address(accessManager),
      BytecodeHelper.getSpokeBytecode(),
      type(uint16).max,
      keccak256(abi.encodePacked('new-spoke', gasleft()))
    );
    AaveV4SpokeRolesProcedure.setupSpokeAllRoles(address(accessManager), report.spoke);
    vm.stopPrank();
    return (ISpoke(report.spoke), IAaveOracle(report.aaveOracle));
  }

  function _setupRoles(TestTypes.TestEnvReport memory report) internal {
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(this), 0);
    vm.stopPrank();

    AaveV4TestOrchestration.setRolesTestEnv(report);
    AaveV4TestOrchestration.grantRolesTestEnv(report, ADMIN, ADMIN, ADMIN);

    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(
      address(accessManager),
      address(engine)
    );
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(
      address(accessManager),
      address(engine)
    );

    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(engine), 0);
    accessManager.renounceRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(this));
  }

  function _seedAsset(
    IHub hub,
    AssetInterestRateStrategy strategy,
    address token,
    uint8 decimals
  ) internal returns (uint256 assetId) {
    vm.prank(ADMIN);
    assetId = hub.addAsset(token, decimals, FEE_RECEIVER, address(strategy), abi.encode(IR_DATA));
  }

  function _seedSpokeOnAsset(IHub hub, uint256 assetId, ISpoke spoke) internal {
    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      addCap: type(uint40).max,
      drawCap: type(uint40).max,
      riskPremiumThreshold: 100_00,
      active: true,
      halted: false
    });
    vm.prank(ADMIN);
    hub.addSpoke(assetId, address(spoke), config);
  }

  function _seedReserve(
    ISpoke spoke,
    IHub hub,
    uint256 assetId,
    address priceSource
  ) internal returns (uint256 reserveId) {
    ISpoke.ReserveConfig memory config = ISpoke.ReserveConfig({
      collateralRisk: 15_00,
      paused: false,
      frozen: false,
      borrowable: true,
      receiveSharesEnabled: true
    });
    ISpoke.DynamicReserveConfig memory dynConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 105_00,
      liquidationFee: 10_00
    });
    vm.prank(ADMIN);
    reserveId = spoke.addReserve(address(hub), assetId, priceSource, config, dynConfig);
  }

  function _getAssetId(uint256 hubIdx, uint256 tokenIdx) internal view returns (uint256) {
    return assetIds[hubIdx][tokenIdx];
  }

  function _getReserveId(uint256 spokeIdx, uint256 tokenIdx) internal view returns (uint256) {
    return reserveIds[spokeIdx][tokenIdx];
  }

  function _seedFullEnvironment() internal {
    for (uint256 h; h < NUM_HUBS; ++h) {
      for (uint256 t; t < NUM_TOKENS; ++t) {
        assetIds[h][t] = _seedAsset(
          hubs[h],
          irStrategies[h],
          tokenList[t].token,
          tokenList[t].decimals
        );
      }
    }

    for (uint256 h; h < NUM_HUBS; ++h) {
      for (uint256 t; t < NUM_TOKENS; ++t) {
        for (uint256 s; s < NUM_SPOKES; ++s) {
          _seedSpokeOnAsset(hubs[h], assetIds[h][t], spokes[s]);
        }
      }
    }

    for (uint256 s; s < NUM_SPOKES; ++s) {
      for (uint256 t; t < NUM_TOKENS; ++t) {
        address pf = _deployMockPriceFeed(spokes[s], tokenList[t].priceFeed);
        reserveIds[s][t] = _seedReserve(spokes[s], hubs[0], assetIds[0][t], pf);
      }
    }

    for (uint256 s; s < NUM_SPOKES; ++s) {
      vm.prank(ADMIN);
      spokes[s].updateLiquidationConfig(
        ISpoke.LiquidationConfig({
          targetHealthFactor: 1.05e18,
          healthFactorForMaxBonus: 0.95e18,
          liquidationBonusFactor: 100_00
        })
      );
    }
  }

  function _deployMockPriceFeed(ISpoke spoke, address baseFeed) internal returns (address) {
    IAaveOracle oracle = IAaveOracle(spoke.ORACLE());
    int256 price = MockPriceFeed(baseFeed).latestAnswer();
    return address(new MockPriceFeed(oracle.decimals(), 'mock', uint256(price)));
  }

  function _defaultAssetListing() internal view returns (IAaveV4ConfigEngine.AssetListing memory) {
    return
      IAaveV4ConfigEngine.AssetListing({
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        underlying: address(weth),
        feeReceiver: FEE_RECEIVER,
        liquidityFee: LIQUIDITY_FEE,
        irStrategy: address(irStrategy1()),
        irData: IR_DATA,
        tokenization: IAaveV4ConfigEngine.TokenizationSpokeConfig({
          addCap: 0,
          proxyAdminOwner: address(0),
          name: '',
          symbol: ''
        })
      });
  }

  function _defaultAssetConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.AssetConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.AssetConfigUpdate({
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        underlying: address(weth),
        liquidityFee: LIQUIDITY_FEE,
        feeReceiver: FEE_RECEIVER,
        irStrategy: address(irStrategy1()),
        irData: IR_DATA,
        reinvestmentController: REINVESTMENT_CONTROLLER
      });
  }

  function _defaultSpokeConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.SpokeConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.SpokeConfigUpdate({
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        underlying: address(weth),
        spoke: address(spoke1()),
        addCap: 1000,
        drawCap: 500,
        riskPremiumThreshold: 100,
        active: EngineFlags.ENABLED,
        halted: EngineFlags.DISABLED
      });
  }

  function _defaultReserveConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.ReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        priceSource: address(priceFeedWeth),
        collateralRisk: 50_00,
        paused: EngineFlags.DISABLED,
        frozen: EngineFlags.DISABLED,
        borrowable: EngineFlags.ENABLED,
        receiveSharesEnabled: EngineFlags.ENABLED
      });
  }

  function _defaultLiquidationConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: 100_00
      });
  }

  function _defaultDynamicReserveConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.DynamicReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      });
  }

  function _defaultReserveConfig() internal pure returns (ISpoke.ReserveConfig memory) {
    return
      ISpoke.ReserveConfig({
        collateralRisk: 50_00,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      });
  }

  function _defaultDynamicReserveConfig()
    internal
    pure
    returns (ISpoke.DynamicReserveConfig memory)
  {
    return
      ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      });
  }

  function _defaultReserveListing()
    internal
    view
    returns (IAaveV4ConfigEngine.ReserveListing memory)
  {
    return
      IAaveV4ConfigEngine.ReserveListing({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        priceSource: address(priceFeedWeth),
        config: _defaultReserveConfig(),
        dynamicConfig: _defaultDynamicReserveConfig()
      });
  }

  function _defaultDynamicReserveConfigAddition()
    internal
    view
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition memory)
  {
    return
      IAaveV4ConfigEngine.DynamicReserveConfigAddition({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfig: _defaultDynamicReserveConfig()
      });
  }

  function _defaultPositionManagerUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.PositionManagerUpdate memory)
  {
    return
      IAaveV4ConfigEngine.PositionManagerUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        positionManager: address(positionManager),
        active: true
      });
  }

  function _assertSpokeConfig(
    IHub hub,
    uint256 assetId,
    address spoke,
    IHub.SpokeConfig memory expected
  ) internal view {
    IHub.SpokeConfig memory actual = hub.getSpokeConfig(assetId, spoke);
    assertEq(actual.addCap, expected.addCap);
    assertEq(actual.drawCap, expected.drawCap);
    assertEq(actual.riskPremiumThreshold, expected.riskPremiumThreshold);
    assertEq(actual.active, expected.active);
    assertEq(actual.halted, expected.halted);
  }

  function _toAssetConfigUpdateArray(
    IAaveV4ConfigEngine.AssetConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.AssetConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    arr[0] = item;
  }

  function _toSpokeConfigUpdateArray(
    IAaveV4ConfigEngine.SpokeConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    arr[0] = item;
  }

  function _toSpokeToAssetsAdditionArray(
    IAaveV4ConfigEngine.SpokeToAssetsAddition memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeToAssetsAddition[](1);
    arr[0] = item;
  }

  function _toAssetHaltArray(
    IAaveV4ConfigEngine.AssetHalt memory item
  ) internal pure returns (IAaveV4ConfigEngine.AssetHalt[] memory arr) {
    arr = new IAaveV4ConfigEngine.AssetHalt[](1);
    arr[0] = item;
  }

  function _toAssetDeactivationArray(
    IAaveV4ConfigEngine.AssetDeactivation memory item
  ) internal pure returns (IAaveV4ConfigEngine.AssetDeactivation[] memory arr) {
    arr = new IAaveV4ConfigEngine.AssetDeactivation[](1);
    arr[0] = item;
  }

  function _toAssetCapsResetArray(
    IAaveV4ConfigEngine.AssetCapsReset memory item
  ) internal pure returns (IAaveV4ConfigEngine.AssetCapsReset[] memory arr) {
    arr = new IAaveV4ConfigEngine.AssetCapsReset[](1);
    arr[0] = item;
  }

  function _toSpokeDeactivationArray(
    IAaveV4ConfigEngine.SpokeDeactivation memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeDeactivation[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeDeactivation[](1);
    arr[0] = item;
  }

  function _toSpokeCapsResetArray(
    IAaveV4ConfigEngine.SpokeCapsReset memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeCapsReset[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeCapsReset[](1);
    arr[0] = item;
  }

  function _toAssetListingArray(
    IAaveV4ConfigEngine.AssetListing memory item
  ) internal pure returns (IAaveV4ConfigEngine.AssetListing[] memory arr) {
    arr = new IAaveV4ConfigEngine.AssetListing[](1);
    arr[0] = item;
  }

  function _toReserveConfigUpdateArray(
    IAaveV4ConfigEngine.ReserveConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.ReserveConfigUpdate[](1);
    arr[0] = item;
  }

  function _toLiquidationConfigUpdateArray(
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](1);
    arr[0] = item;
  }

  function _toDynamicReserveConfigUpdateArray(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](1);
    arr[0] = item;
  }

  function _toRoleMembershipArray(
    IAaveV4ConfigEngine.RoleMembership memory item
  ) internal pure returns (IAaveV4ConfigEngine.RoleMembership[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleMembership[](1);
    arr[0] = item;
  }

  function _toRoleUpdateArray(
    IAaveV4ConfigEngine.RoleUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.RoleUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleUpdate[](1);
    arr[0] = item;
  }

  function _toTargetFunctionRoleUpdateArray(
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](1);
    arr[0] = item;
  }

  function _toTargetAdminDelayUpdateArray(
    IAaveV4ConfigEngine.TargetAdminDelayUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.TargetAdminDelayUpdate[](1);
    arr[0] = item;
  }

  function _toReserveListingArray(
    IAaveV4ConfigEngine.ReserveListing memory item
  ) internal pure returns (IAaveV4ConfigEngine.ReserveListing[] memory arr) {
    arr = new IAaveV4ConfigEngine.ReserveListing[](1);
    arr[0] = item;
  }

  function _toDynamicReserveConfigAdditionArray(
    IAaveV4ConfigEngine.DynamicReserveConfigAddition memory item
  ) internal pure returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory arr) {
    arr = new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](1);
    arr[0] = item;
  }

  function _toPositionManagerUpdateArray(
    IAaveV4ConfigEngine.PositionManagerUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    arr[0] = item;
  }

  function _toSpokeRegistrationArray(
    IAaveV4ConfigEngine.SpokeRegistration memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeRegistration[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    arr[0] = item;
  }

  function _toPositionManagerRoleRenouncementArray(
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement memory item
  ) internal pure returns (IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] memory arr) {
    arr = new IAaveV4ConfigEngine.PositionManagerRoleRenouncement[](1);
    arr[0] = item;
  }

  function _keepCurrentIrData()
    internal
    pure
    returns (IAssetInterestRateStrategy.InterestRateData memory)
  {
    return
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: EngineFlags.KEEP_CURRENT_UINT16,
        baseDrawnRate: EngineFlags.KEEP_CURRENT_UINT32,
        rateGrowthBeforeOptimal: EngineFlags.KEEP_CURRENT_UINT32,
        rateGrowthAfterOptimal: EngineFlags.KEEP_CURRENT_UINT32
      });
  }
}
