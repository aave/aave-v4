// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {stdError} from 'forge-std/StdError.sol';
import {stdMath} from 'forge-std/StdMath.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {Vm, VmSafe} from 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';

// dependencies
import {
  TransparentUpgradeableProxy,
  ITransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {ReentrancyGuardTransient} from 'src/dependencies/openzeppelin/ReentrancyGuardTransient.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC5267} from 'src/dependencies/openzeppelin/IERC5267.sol';
import {IERC4626} from 'src/dependencies/openzeppelin/IERC4626.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {AuthorityUtils} from 'src/dependencies/openzeppelin/AuthorityUtils.sol';
import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {SlotDerivation} from 'src/dependencies/openzeppelin/SlotDerivation.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {LibBit} from 'src/dependencies/solady/LibBit.sol';

import {Initializable} from 'src/dependencies/openzeppelin-upgradeable/Initializable.sol';
import {OwnableUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/OwnableUpgradeable.sol';
import {IERC1967} from 'src/dependencies/openzeppelin/IERC1967.sol';

// shared
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Rescuable, IRescuable} from 'src/utils/Rescuable.sol';
import {NoncesKeyed, INoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {IntentConsumer, IIntentConsumer} from 'src/utils/IntentConsumer.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

// hub
import {HubConfigurator, IHubConfigurator} from 'src/hub/HubConfigurator.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {
  AssetInterestRateStrategy,
  IAssetInterestRateStrategy,
  IBasicInterestRateStrategy
} from 'src/hub/AssetInterestRateStrategy.sol';

// fee minter
import {FeeSharesMinter, IFeeSharesMinter} from 'src/utils/FeeSharesMinter.sol';

// spoke
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {TreasurySpoke, ITreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {TreasurySpokeInstance} from 'src/spoke/instances/TreasurySpokeInstance.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {IPriceFeed} from 'src/spoke/interfaces/IPriceFeed.sol';
import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {SpokeConfigurator, ISpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';
import {SpokeUtils} from 'src/spoke/libraries/SpokeUtils.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';

// tokenization spoke
import {TokenizationSpoke, ITokenizationSpoke} from 'src/spoke/TokenizationSpoke.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

// position manager
import {
  PositionManagerBase,
  IPositionManagerBase
} from 'src/position-manager/PositionManagerBase.sol';
import {NativeTokenGateway, INativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import {SignatureGateway, ISignatureGateway} from 'src/position-manager/SignatureGateway.sol';
import {
  GiverPositionManager,
  IGiverPositionManager
} from 'src/position-manager/GiverPositionManager.sol';
import {
  TakerPositionManager,
  ITakerPositionManager
} from 'src/position-manager/TakerPositionManager.sol';
import {
  ConfigPositionManager,
  IConfigPositionManager
} from 'src/position-manager/ConfigPositionManager.sol';
import {
  ConfigPermissions,
  ConfigPermissionsMap
} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';

// orchestration
import {ConfigData} from 'tests/utils/ConfigData.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';

// helpers
import {TestTypes} from 'tests/utils/TestTypes.sol';
import {HubActions} from 'tests/helpers/hub/HubActions.sol';
import {SpokeActions} from 'tests/helpers/spoke/SpokeActions.sol';
import {BaseHelpers} from 'tests/setup/BaseHelpers.sol';

// mocks
import {EIP712Types} from 'tests/helpers/mocks/EIP712Types.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {MockERC20} from 'tests/helpers/mocks/MockERC20.sol';
import {MockPriceFeed} from 'tests/helpers/mocks/MockPriceFeed.sol';
import {PositionStatusMapWrapper} from 'tests/helpers/mocks/PositionStatusMapWrapper.sol';
import {RescuableWrapper} from 'tests/helpers/mocks/RescuableWrapper.sol';
import {PositionManagerBaseWrapper} from 'tests/helpers/mocks/PositionManagerBaseWrapper.sol';
import {PositionManagerNoMulticall} from 'tests/helpers/mocks/PositionManagerNoMulticall.sol';
import {MockNoncesKeyed} from 'tests/helpers/mocks/MockNoncesKeyed.sol';
import {MockSpoke} from 'tests/helpers/mocks/MockSpoke.sol';
import {MockERC1271Wallet} from 'tests/helpers/mocks/MockERC1271Wallet.sol';
import {MockHubInstance} from 'tests/helpers/mocks/MockHubInstance.sol';
import {MockSpokeInstance} from 'tests/helpers/mocks/MockSpokeInstance.sol';
import {MockTreasurySpokeInstance} from 'tests/helpers/mocks/MockTreasurySpokeInstance.sol';
import {MockSkimSpoke} from 'tests/helpers/mocks/MockSkimSpoke.sol';
import {MockReentrantCaller} from 'tests/helpers/mocks/MockReentrantCaller.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';
import {AaveV4TestOrchestrationWrapper} from 'tests/helpers/mocks/AaveV4TestOrchestrationWrapper.sol';
import {SpokeUtilsWrapper} from 'tests/helpers/mocks/SpokeUtilsWrapper.sol';

import 'tests/utils/BatchTestProcedures.sol';

abstract contract Base is BaseHelpers, BatchTestProcedures {
  using stdStorage for StdStorage;
  using WadRayMath for *;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;
  using MathUtils for uint256;
  using ReserveFlagsMap for ReserveFlags;

  function setUp() public virtual override {
    _etchSetup();
    _initTokenList();
    _setupFixtures();
    _initEnvironment();
  }

  function _deployFixtures(
    uint256 numHubs,
    uint256 numSpokes
  ) internal virtual returns (TestTypes.TestEnvReport memory report) {
    report = AaveV4TestOrchestration.deployTestEnv({
      admin: ADMIN,
      treasuryAdmin: TREASURY_ADMIN,
      hubCount: numHubs,
      spokeCount: numSpokes,
      nativeWrapper: address(tokenList.weth),
      hubBytecode: BytecodeHelper.getHubBytecode(),
      spokeBytecode: BytecodeHelper.getSpokeBytecode(),
      salt: bytes32(vm.randomBytes(32))
    });
    for (uint256 i; i < numHubs; ++i) {
      _hubs.push(IHub(report.hubReports[i].hub));
      _irStrategies.push(IAssetInterestRateStrategy(report.hubReports[i].irStrategy));

      vm.label(report.hubReports[i].hub, string.concat('hub', string(abi.encode(i))));
      vm.label(report.hubReports[i].irStrategy, string.concat('irStrategy', string(abi.encode(i))));
    }
    vm.label(report.treasurySpoke, 'treasurySpoke');

    for (uint256 i; i < numSpokes; ++i) {
      _spokes.push(ISpoke(report.spokeReports[i].spoke));
      _oracles.push(IAaveOracle(report.spokeReports[i].aaveOracle));

      vm.label(report.spokeReports[i].spoke, string.concat('spoke', string(abi.encode(i))));
      vm.label(report.spokeReports[i].aaveOracle, string.concat('oracle', string(abi.encode(i))));
    }

    vm.label(report.configuratorReport.hubConfigurator, 'hubConfigurator');
    vm.label(report.configuratorReport.spokeConfigurator, 'spokeConfigurator');

    return report;
  }

  function _setupFixtures() internal virtual {
    TestTypes.TestEnvReport memory report = _deployFixtures({numHubs: 1, numSpokes: 3});
    _setupFixturesRoles(report);

    // todo rm when tests adapted to multiple hubs and spokes
    hub1 = IHub(report.hubReports[0].hub);
    irStrategy = IAssetInterestRateStrategy(report.hubReports[0].irStrategy);
    treasurySpoke = ITreasurySpoke(report.treasurySpoke);
    spoke1 = ISpoke(report.spokeReports[0].spoke);
    spoke2 = ISpoke(report.spokeReports[1].spoke);
    spoke3 = ISpoke(report.spokeReports[2].spoke);
    oracle1 = IAaveOracle(report.spokeReports[0].aaveOracle);
    oracle2 = IAaveOracle(report.spokeReports[1].aaveOracle);
    oracle3 = IAaveOracle(report.spokeReports[2].aaveOracle);
    accessManager = IAccessManager(report.accessManager);
    hubConfigurator = IHubConfigurator(report.configuratorReport.hubConfigurator);
    spokeConfigurator = ISpokeConfigurator(report.configuratorReport.spokeConfigurator);
  }

  function _setupFixturesRoles(TestTypes.TestEnvReport memory report) internal virtual {
    if (report.accessManager == address(0)) report.accessManager = address(accessManager);

    // temporary grant admin role to address(this) to execute setAndGrantRolesTestEnv from its context
    vm.startPrank(ADMIN);
    IAccessManager(report.accessManager).grantRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      address(this),
      0
    );
    vm.stopPrank();

    AaveV4TestOrchestration.setRolesTestEnv(report);
    AaveV4TestOrchestration.grantRolesTestEnv(report, ADMIN, HUB_ADMIN, SPOKE_ADMIN);

    // Grant HubConfigurator granular roles to HUB_CONFIGURATOR_ADMIN so it can call
    // HubConfigurator functions (deactivateAsset, resetAssetCaps, haltAsset, etc.)
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(
      report.accessManager,
      HUB_CONFIGURATOR_ADMIN
    );

    // Grant SpokeConfigurator granular roles to SPOKE_CONFIGURATOR_ADMIN so it can call
    // SpokeConfigurator functions (addReserve, updateMaxReserves, freezeReserve, etc.)
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(
      report.accessManager,
      SPOKE_CONFIGURATOR_ADMIN
    );

    IAccessManager(report.accessManager).renounceRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      address(this)
    );
  }

  /// @dev Standalone role setup for a hub+spoke pair outside the main orchestration (e.g. upgrade tests).
  function setUpRoles(IHub targetHub, ISpoke spoke, IAccessManager manager) internal virtual {
    vm.startPrank(ADMIN);
    manager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(this), 0);
    vm.stopPrank();

    AaveV4HubRolesProcedure.grantHubAllRoles(address(manager), ADMIN);
    AaveV4HubRolesProcedure.grantHubAllRoles(address(manager), HUB_ADMIN);
    AaveV4HubRolesProcedure.setupHubAllRoles(address(manager), address(targetHub));

    AaveV4SpokeRolesProcedure.grantSpokeAllRoles(address(manager), ADMIN);
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles(address(manager), SPOKE_ADMIN);
    AaveV4SpokeRolesProcedure.setupSpokeAllRoles(address(manager), address(spoke));

    IAccessManager(address(manager)).renounceRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(this));
  }

  function _initEnvironment() internal {
    _mintAndApproveTokenList();
    _configureHubsAndSpokes();
  }

  function _initTokenList() internal {
    TestTypes.TestTokenInput[] memory tokenInputs = new TestTypes.TestTokenInput[](5);
    tokenInputs[0] = TestTypes.TestTokenInput({
      name: 'USDX',
      symbol: 'USDX',
      decimals: _decimals.usdx
    });
    tokenInputs[1] = TestTypes.TestTokenInput({
      name: 'DAI',
      symbol: 'DAI',
      decimals: _decimals.dai
    });
    tokenInputs[2] = TestTypes.TestTokenInput({
      name: 'WBTC',
      symbol: 'WBTC',
      decimals: _decimals.wbtc
    });
    tokenInputs[3] = TestTypes.TestTokenInput({
      name: 'USDY',
      symbol: 'USDY',
      decimals: _decimals.usdy
    });
    tokenInputs[4] = TestTypes.TestTokenInput({
      name: 'USDZ',
      symbol: 'USDZ',
      decimals: _decimals.usdz
    });

    tokenList = AaveV4TestOrchestration.deployTestTokens(tokenInputs);

    vm.label(address(tokenList.weth), 'WETH');
    vm.label(address(tokenList.usdx), 'USDX');
    vm.label(address(tokenList.dai), 'DAI');
    vm.label(address(tokenList.wbtc), 'WBTC');
    vm.label(address(tokenList.usdy), 'USDY');
    vm.label(address(tokenList.usdz), 'USDZ');

    MAX_SUPPLY_AMOUNT_USDX = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.usdx.decimals();
    MAX_SUPPLY_AMOUNT_WETH = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.weth.decimals();
    MAX_SUPPLY_AMOUNT_DAI = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.dai.decimals();
    MAX_SUPPLY_AMOUNT_WBTC = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.wbtc.decimals();
    MAX_SUPPLY_AMOUNT_USDY = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.usdy.decimals();
    MAX_SUPPLY_AMOUNT_USDZ = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.usdz.decimals();
  }

  function _mintAndApproveTokenList() internal {
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
      tokenList.usdz.mint(users[x], mintAmount_USDZ);
      deal(address(tokenList.weth), users[x], mintAmount_WETH);

      vm.startPrank(users[x]);
      for (uint256 y; y < _spokes.length; ++y) {
        address spoke = address(_spokes[y]);
        tokenList.weth.approve(spoke, UINT256_MAX);
        tokenList.usdx.approve(spoke, UINT256_MAX);
        tokenList.dai.approve(spoke, UINT256_MAX);
        tokenList.wbtc.approve(spoke, UINT256_MAX);
        tokenList.usdy.approve(spoke, UINT256_MAX);
        tokenList.usdz.approve(spoke, UINT256_MAX);
      }
      {
        address spoke = address(treasurySpoke);
        tokenList.weth.approve(spoke, UINT256_MAX);
        tokenList.usdx.approve(spoke, UINT256_MAX);
        tokenList.dai.approve(spoke, UINT256_MAX);
        tokenList.wbtc.approve(spoke, UINT256_MAX);
        tokenList.usdy.approve(spoke, UINT256_MAX);
        tokenList.usdz.approve(spoke, UINT256_MAX);
      }
      vm.stopPrank();
    }
  }

  function spokeMintAndApprove() internal {
    uint256 spokeMintAmount_USDX = 100e6 * 10 ** tokenList.usdx.decimals();
    uint256 spokeMintAmount_DAI = 1e60;
    uint256 spokeMintAmount_WBTC = 100e6 * 10 ** tokenList.wbtc.decimals();
    uint256 spokeMintAmount_WETH = 100e6 * 10 ** tokenList.weth.decimals();
    uint256 spokeMintAmount_USDY = 100e6 * 10 ** tokenList.usdy.decimals();
    uint256 spokeMintAmount_USDZ = 100e6 * 10 ** tokenList.usdz.decimals();
    address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];

    for (uint256 x; x < spokes.length; ++x) {
      tokenList.usdx.mint(spokes[x], spokeMintAmount_USDX);
      tokenList.dai.mint(spokes[x], spokeMintAmount_DAI);
      tokenList.wbtc.mint(spokes[x], spokeMintAmount_WBTC);
      tokenList.usdy.mint(spokes[x], spokeMintAmount_USDY);
      tokenList.usdz.mint(spokes[x], spokeMintAmount_USDZ);
      deal(address(tokenList.weth), spokes[x], spokeMintAmount_WETH);

      vm.startPrank(spokes[x]);
      tokenList.weth.approve(address(hub1), UINT256_MAX);
      tokenList.usdx.approve(address(hub1), UINT256_MAX);
      tokenList.dai.approve(address(hub1), UINT256_MAX);
      tokenList.wbtc.approve(address(hub1), UINT256_MAX);
      tokenList.usdy.approve(address(hub1), UINT256_MAX);
      tokenList.usdz.approve(address(hub1), UINT256_MAX);
      vm.stopPrank();
    }
  }

  function _configureHubsAndSpokes() internal {
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_ROLE, address(this), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(this), 0);
    vm.stopPrank();

    (
      ConfigData.UpdateLiquidationConfigParams[] memory liquidationParams,
      ConfigData.AddReserveParams[] memory reserveParams
    ) = _getSpokeReserveParams();
    AaveV4TestOrchestration.configureHubsAssets(_getAddAssetParams());
    AaveV4TestOrchestration.configureHubsSpokes(_getAddSpokeParams());
    TestTypes.SpokeReserveId[] memory spokeReserveIds = AaveV4TestOrchestration.configureSpokes(
      liquidationParams,
      reserveParams
    );

    _loadSpokeInfo(spokeReserveIds);

    accessManager.renounceRole(Roles.HUB_CONFIGURATOR_ROLE, address(this));
    accessManager.renounceRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(this));
  }

  function _loadSpokeInfo(TestTypes.SpokeReserveId[] memory spokeReserveIds) internal {
    // Persist reserveIds and configs into spokeInfo to mirror manual configureTokenList setup
    for (uint256 i; i < spokeReserveIds.length; ++i) {
      TestTypes.SpokeReserveId memory spokeReserveId = spokeReserveIds[i];
      uint256 reserveId = spokeReserveId.reserveId;
      ISpoke spoke = ISpoke(spokeReserveId.spoke);
      uint256 assetId = spoke.getReserve(reserveId).assetId;

      ReserveInfo storage info;
      if (assetId == wethAssetId) {
        info = spokeInfo[spoke].weth;
      } else if (assetId == wbtcAssetId) {
        info = spokeInfo[spoke].wbtc;
      } else if (assetId == daiAssetId) {
        info = spokeInfo[spoke].dai;
      } else if (assetId == usdxAssetId) {
        info = spokeInfo[spoke].usdx;
      } else if (assetId == usdyAssetId) {
        info = spokeInfo[spoke].usdy;
      } else if (assetId == usdzAssetId) {
        info = spokeInfo[spoke].usdz;
      } else {
        continue;
      }

      info.reserveId = reserveId;
      info.reserveConfig = spoke.getReserveConfig(reserveId);
      info.dynReserveConfig = _getLatestDynamicReserveConfig(spoke, reserveId);
    }
  }

  function _getAddSpokeParams()
    internal
    view
    returns (ConfigData.AddSpokeParams[] memory paramsList)
  {
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
    });
    paramsList = new ConfigData.AddSpokeParams[](15);

    // spoke1
    paramsList[0] = ConfigData.AddSpokeParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: wethAssetId,
      config: spokeConfig
    });
    paramsList[1] = ConfigData.AddSpokeParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: wbtcAssetId,
      config: spokeConfig
    });
    paramsList[2] = ConfigData.AddSpokeParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: daiAssetId,
      config: spokeConfig
    });
    paramsList[3] = ConfigData.AddSpokeParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: usdxAssetId,
      config: spokeConfig
    });
    paramsList[4] = ConfigData.AddSpokeParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: usdyAssetId,
      config: spokeConfig
    });

    // spoke2
    paramsList[5] = ConfigData.AddSpokeParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: wbtcAssetId,
      config: spokeConfig
    });
    paramsList[6] = ConfigData.AddSpokeParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: wethAssetId,
      config: spokeConfig
    });
    paramsList[7] = ConfigData.AddSpokeParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: daiAssetId,
      config: spokeConfig
    });
    paramsList[8] = ConfigData.AddSpokeParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: usdxAssetId,
      config: spokeConfig
    });
    paramsList[9] = ConfigData.AddSpokeParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: usdyAssetId,
      config: spokeConfig
    });
    paramsList[10] = ConfigData.AddSpokeParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: usdzAssetId,
      config: spokeConfig
    });

    // spoke3
    paramsList[11] = ConfigData.AddSpokeParams({
      spoke: address(spoke3),
      hub: address(hub1),
      assetId: daiAssetId,
      config: spokeConfig
    });
    paramsList[12] = ConfigData.AddSpokeParams({
      spoke: address(spoke3),
      hub: address(hub1),
      assetId: usdxAssetId,
      config: spokeConfig
    });
    paramsList[13] = ConfigData.AddSpokeParams({
      spoke: address(spoke3),
      hub: address(hub1),
      assetId: wethAssetId,
      config: spokeConfig
    });
    paramsList[14] = ConfigData.AddSpokeParams({
      spoke: address(spoke3),
      hub: address(hub1),
      assetId: wbtcAssetId,
      config: spokeConfig
    });

    return paramsList;
  }

  function _getSpokeReserveParams()
    internal
    returns (
      ConfigData.UpdateLiquidationConfigParams[] memory,
      ConfigData.AddReserveParams[] memory
    )
  {
    ConfigData.UpdateLiquidationConfigParams[]
      memory liquidationParams = new ConfigData.UpdateLiquidationConfigParams[](3);
    liquidationParams[0] = ConfigData.UpdateLiquidationConfigParams({
      spoke: address(spoke1),
      config: ISpoke.LiquidationConfig({
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.7e18,
        liquidationBonusFactor: 20_00
      })
    });
    liquidationParams[1] = ConfigData.UpdateLiquidationConfigParams({
      spoke: address(spoke2),
      config: ISpoke.LiquidationConfig({
        targetHealthFactor: 1.04e18,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 15_00
      })
    });
    liquidationParams[2] = ConfigData.UpdateLiquidationConfigParams({
      spoke: address(spoke3),
      config: ISpoke.LiquidationConfig({
        targetHealthFactor: 1.03e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 10_00
      })
    });

    ConfigData.AddReserveParams[] memory reserveParams = new ConfigData.AddReserveParams[](15);
    // spoke1
    reserveParams[0] = ConfigData.AddReserveParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: wethAssetId,
      priceSource: _deployMockPriceFeed(spoke1, 2000e8),
      config: _getDefaultReserveConfig(15_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      })
    });
    reserveParams[1] = ConfigData.AddReserveParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: wbtcAssetId,
      priceSource: _deployMockPriceFeed(spoke1, 50_000e8),
      config: _getDefaultReserveConfig(15_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 103_00,
        liquidationFee: 15_00
      })
    });
    reserveParams[2] = ConfigData.AddReserveParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: daiAssetId,
      priceSource: _deployMockPriceFeed(spoke1, 1e8),
      config: _getDefaultReserveConfig(20_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 102_00,
        liquidationFee: 10_00
      })
    });
    reserveParams[3] = ConfigData.AddReserveParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: usdxAssetId,
      priceSource: _deployMockPriceFeed(spoke1, 1e8),
      config: _getDefaultReserveConfig(50_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 101_00,
        liquidationFee: 12_00
      })
    });
    reserveParams[4] = ConfigData.AddReserveParams({
      spoke: address(spoke1),
      hub: address(hub1),
      assetId: usdyAssetId,
      priceSource: _deployMockPriceFeed(spoke1, 1e8),
      config: _getDefaultReserveConfig(50_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 101_50,
        liquidationFee: 15_00
      })
    });

    // spoke2
    reserveParams[5] = ConfigData.AddReserveParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: wbtcAssetId,
      priceSource: _deployMockPriceFeed(spoke2, 50_000e8),
      config: _getDefaultReserveConfig(0),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      })
    });
    reserveParams[6] = ConfigData.AddReserveParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: wethAssetId,
      priceSource: _deployMockPriceFeed(spoke2, 2000e8),
      config: _getDefaultReserveConfig(10_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 76_00,
        maxLiquidationBonus: 103_00,
        liquidationFee: 15_00
      })
    });
    reserveParams[7] = ConfigData.AddReserveParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: daiAssetId,
      priceSource: _deployMockPriceFeed(spoke2, 1e8),
      config: _getDefaultReserveConfig(20_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 72_00,
        maxLiquidationBonus: 102_00,
        liquidationFee: 10_00
      })
    });
    reserveParams[8] = ConfigData.AddReserveParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: usdxAssetId,
      priceSource: _deployMockPriceFeed(spoke2, 1e8),
      config: _getDefaultReserveConfig(50_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 72_00,
        maxLiquidationBonus: 101_00,
        liquidationFee: 12_00
      })
    });
    reserveParams[9] = ConfigData.AddReserveParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: usdyAssetId,
      priceSource: _deployMockPriceFeed(spoke2, 1e8),
      config: _getDefaultReserveConfig(50_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 72_00,
        maxLiquidationBonus: 101_50,
        liquidationFee: 15_00
      })
    });
    reserveParams[10] = ConfigData.AddReserveParams({
      spoke: address(spoke2),
      hub: address(hub1),
      assetId: usdzAssetId,
      priceSource: _deployMockPriceFeed(spoke2, 1e8),
      config: _getDefaultReserveConfig(100_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 70_00,
        maxLiquidationBonus: 106_00,
        liquidationFee: 10_00
      })
    });

    // spoke3
    reserveParams[11] = ConfigData.AddReserveParams({
      spoke: address(spoke3),
      hub: address(hub1),
      assetId: daiAssetId,
      priceSource: _deployMockPriceFeed(spoke3, 1e8),
      config: _getDefaultReserveConfig(0),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 104_00,
        liquidationFee: 11_00
      })
    });
    reserveParams[12] = ConfigData.AddReserveParams({
      spoke: address(spoke3),
      hub: address(hub1),
      assetId: usdxAssetId,
      priceSource: _deployMockPriceFeed(spoke3, 1e8),
      config: _getDefaultReserveConfig(10_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 103_00,
        liquidationFee: 15_00
      })
    });
    reserveParams[13] = ConfigData.AddReserveParams({
      spoke: address(spoke3),
      hub: address(hub1),
      assetId: wethAssetId,
      priceSource: _deployMockPriceFeed(spoke3, 2000e8),
      config: _getDefaultReserveConfig(20_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 79_00,
        maxLiquidationBonus: 102_00,
        liquidationFee: 10_00
      })
    });
    reserveParams[14] = ConfigData.AddReserveParams({
      spoke: address(spoke3),
      hub: address(hub1),
      assetId: wbtcAssetId,
      priceSource: _deployMockPriceFeed(spoke3, 50_000e8),
      config: _getDefaultReserveConfig(50_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 77_00,
        maxLiquidationBonus: 101_00,
        liquidationFee: 12_00
      })
    });

    return (liquidationParams, reserveParams);
  }

  function _getAddAssetParams() internal view returns (ConfigData.AddAssetParams[] memory) {
    bytes memory encodedIrData = abi.encode(_defaultIrData);

    ConfigData.AddAssetParams[] memory assetParams = new ConfigData.AddAssetParams[](6);
    assetParams[0] = ConfigData.AddAssetParams({
      hub: address(hub1),
      underlying: address(tokenList.weth),
      decimals: tokenList.weth.decimals(),
      feeReceiver: address(treasurySpoke),
      liquidityFee: 10_00,
      irStrategy: address(irStrategy),
      reinvestmentController: address(0),
      irData: encodedIrData
    });
    assetParams[1] = ConfigData.AddAssetParams({
      hub: address(hub1),
      underlying: address(tokenList.usdx),
      decimals: tokenList.usdx.decimals(),
      feeReceiver: address(treasurySpoke),
      liquidityFee: 5_00,
      irStrategy: address(irStrategy),
      reinvestmentController: address(0),
      irData: encodedIrData
    });
    assetParams[2] = ConfigData.AddAssetParams({
      hub: address(hub1),
      underlying: address(tokenList.dai),
      decimals: tokenList.dai.decimals(),
      feeReceiver: address(treasurySpoke),
      liquidityFee: 5_00,
      irStrategy: address(irStrategy),
      reinvestmentController: address(0),
      irData: encodedIrData
    });
    assetParams[3] = ConfigData.AddAssetParams({
      hub: address(hub1),
      underlying: address(tokenList.wbtc),
      decimals: tokenList.wbtc.decimals(),
      feeReceiver: address(treasurySpoke),
      liquidityFee: 10_00,
      irStrategy: address(irStrategy),
      reinvestmentController: address(0),
      irData: encodedIrData
    });
    assetParams[4] = ConfigData.AddAssetParams({
      hub: address(hub1),
      underlying: address(tokenList.usdy),
      decimals: tokenList.usdy.decimals(),
      feeReceiver: address(treasurySpoke),
      liquidityFee: 10_00,
      irStrategy: address(irStrategy),
      reinvestmentController: address(0),
      irData: encodedIrData
    });
    assetParams[5] = ConfigData.AddAssetParams({
      hub: address(hub1),
      underlying: address(tokenList.usdz),
      decimals: tokenList.usdz.decimals(),
      feeReceiver: address(treasurySpoke),
      liquidityFee: 5_00,
      irStrategy: address(irStrategy),
      reinvestmentController: address(0),
      irData: encodedIrData
    });
    return assetParams;
  }

  function _grantSpokeConfiguratorRole(ISpoke spoke, address configurator) internal {
    vm.startPrank(ADMIN);
    IAccessManager(spoke.authority()).grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, configurator, 0);
    vm.stopPrank();
  }

  function _grantHubAdminRole(IHub hub, address admin) internal {
    vm.startPrank(ADMIN);
    // hub admin consists of hub admin role and hub configurator role
    IAccessManager(hub.authority()).grantRole(Roles.HUB_FEE_MINTER_ROLE, admin, 0);
    IAccessManager(hub.authority()).grantRole(Roles.HUB_CONFIGURATOR_ROLE, admin, 0);
    vm.stopPrank();
  }

  function _grantHubConfiguratorRole(IHub hub, address admin) internal {
    vm.startPrank(ADMIN);
    IAccessManager(hub.authority()).grantRole(Roles.HUB_CONFIGURATOR_ROLE, admin, 0);
    vm.stopPrank();
  }

  /* @dev Configures Hub 2 with the following assetIds:
   * 0: WETH
   * 1: USDX
   * 2: DAI
   * 3: WBTC
   */
  function _hub2Fixture() internal returns (IHub, IAssetInterestRateStrategy) {
    FixtureAssetList[] memory assetsList = new FixtureAssetList[](4);
    assetsList[0] = FixtureAssetList({
      underlying: IERC20Metadata(address(tokenList.weth)),
      liquidityFee: 0,
      reinvestmentController: address(0),
      irData: abi.encode(_defaultIrData)
    });
    assetsList[1] = FixtureAssetList({
      underlying: IERC20Metadata(address(tokenList.usdx)),
      liquidityFee: 0,
      reinvestmentController: address(0),
      irData: abi.encode(_defaultIrData)
    });
    assetsList[2] = FixtureAssetList({
      underlying: IERC20Metadata(address(tokenList.dai)),
      liquidityFee: 0,
      reinvestmentController: address(0),
      irData: abi.encode(_defaultIrData)
    });
    assetsList[3] = FixtureAssetList({
      underlying: IERC20Metadata(address(tokenList.wbtc)),
      liquidityFee: 0,
      reinvestmentController: address(0),
      irData: abi.encode(_defaultIrData)
    });

    TestTypes.TestHubReport memory report = _addHubFixture('2', assetsList);
    return (IHub(report.hub), IAssetInterestRateStrategy(report.irStrategy));
  }

  /* @dev Configures Hub 3 with the following assetIds:
   * 0: DAI
   * 1: USDX
   * 2: WBTC
   * 3: WETH
   */
  function _hub3Fixture() internal returns (IHub, IAssetInterestRateStrategy) {
    FixtureAssetList[] memory assetsList = new FixtureAssetList[](4);
    assetsList[0] = FixtureAssetList({
      underlying: IERC20Metadata(address(tokenList.dai)),
      liquidityFee: 0,
      reinvestmentController: address(0),
      irData: abi.encode(_defaultIrData)
    });
    assetsList[1] = FixtureAssetList({
      underlying: IERC20Metadata(address(tokenList.usdx)),
      liquidityFee: 0,
      reinvestmentController: address(0),
      irData: abi.encode(_defaultIrData)
    });
    assetsList[2] = FixtureAssetList({
      underlying: IERC20Metadata(address(tokenList.wbtc)),
      liquidityFee: 0,
      reinvestmentController: address(0),
      irData: abi.encode(_defaultIrData)
    });
    assetsList[3] = FixtureAssetList({
      underlying: IERC20Metadata(address(tokenList.weth)),
      liquidityFee: 0,
      reinvestmentController: address(0),
      irData: abi.encode(_defaultIrData)
    });

    TestTypes.TestHubReport memory report = _addHubFixture('3', assetsList);
    return (IHub(report.hub), IAssetInterestRateStrategy(report.irStrategy));
  }

  function _addHubFixture(
    string memory label,
    FixtureAssetList[] memory assetsList
  ) internal returns (TestTypes.TestHubReport memory report) {
    report = AaveV4TestOrchestration.deployTestHub(
      ADMIN,
      address(accessManager),
      BytecodeHelper.getHubBytecode(),
      label,
      keccak256(abi.encodePacked(label))
    );
    _hubs.push(IHub(report.hub));
    _irStrategies.push(IAssetInterestRateStrategy(report.irStrategy));

    vm.label(report.hub, string.concat('Hub', label));
    vm.label(report.irStrategy, string.concat('IrStrategy', label));

    ConfigData.AddAssetParams[] memory assetParams = new ConfigData.AddAssetParams[](
      assetsList.length
    );
    for (uint256 i; i < assetsList.length; ++i) {
      assetParams[i] = ConfigData.AddAssetParams({
        hub: report.hub,
        underlying: address(assetsList[i].underlying),
        decimals: assetsList[i].underlying.decimals(),
        feeReceiver: address(treasurySpoke),
        liquidityFee: assetsList[i].liquidityFee,
        irStrategy: report.irStrategy,
        irData: assetsList[i].irData,
        reinvestmentController: assetsList[i].reinvestmentController
      });
    }

    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(this), 0);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_ROLE, address(this), 0);

    AaveV4TestOrchestration.setupHubRolesTestEnv(report, address(accessManager));
    vm.stopPrank();

    AaveV4TestOrchestration.configureHubsAssets(assetParams);

    // Renounce temporary roles
    accessManager.renounceRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(this));
    accessManager.renounceRole(Roles.HUB_CONFIGURATOR_ROLE, address(this));

    return report;
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
}
