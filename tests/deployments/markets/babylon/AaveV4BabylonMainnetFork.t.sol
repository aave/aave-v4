// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, Vm} from 'forge-std/Test.sol';
import {
  AaveV4DeployBabylonHubHarness,
  AaveV4DeployBabylonSpokeHarness,
  AaveV4DeployBabylonTokenizationHarness,
  AaveV4BabylonConfigureHarness,
  AaveV4BabylonHandoverHarness,
  AaveV4BabylonVerifyHarness
} from 'tests/deployments/markets/babylon/AaveV4Babylon.t.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IPriceFeed} from 'src/spoke/interfaces/IPriceFeed.sol';
import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

interface IBabylonLiquidationLogic {
  function getLiquidationLogic() external pure returns (address);
}

interface IVaultBTC {
  function HUB() external view returns (address);

  function adapter() external view returns (address);
}

interface IAaveAdapter {
  function BTC_VAULT_CORE_SPOKE() external view returns (address);

  function BTC_VAULT_HUB() external view returns (address);

  function EXIT_BTC_RESERVE_ID() external view returns (uint256);

  function VAULT_BTC_ASSET_ID() external view returns (uint256);

  function VAULT_BTC_RESERVE_ID() external view returns (uint256);
}

interface IBTCVaultSwap {
  function ADAPTER() external view returns (address);

  function HUB() external view returns (address);

  function EXIT_BTC_ASSET_ID() external view returns (uint256);
}

/// @dev Runs the production Babylon market scripts on an Ethereum fork and asserts the state after
/// the handover (step 5b of the launch plan), then the state after the launch AIP actions on the
/// shared V4 contracts. Expected values come from the LlamaRisk parameters and aave-address-book,
/// not from `config/mainnet.json`. A mock vaultBTC stands in until Babylon deploys it.
contract AaveV4BabylonMainnetForkTest is Test {
  uint256 internal constant FORK_BLOCK = 26_387_600;
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal constant REPORT_NAME = 'babylon-mainnet-fork-test';
  string internal constant MAINNET_CONFIG = 'scripts/markets/babylon/config/mainnet.json';
  string internal constant VAULT_BTC_PLACEHOLDER =
    '"underlying": "0x0000000000000000000000000000000000000000"';

  // aave-address-book AaveV4Ethereum
  address internal constant ACCESS_MANAGER = 0x08aE3BE30958cDd1847ec58fFfd4C451a87fDF01;
  address internal constant HUB_CONFIGURATOR = 0x1F0753480bB03EaA00863224602267B7E0525C3d;
  address internal constant SPOKE_CONFIGURATOR = 0x9BFFf48BFb5A7AE70c348d4d4cb97E8DEFa5389a;
  address internal constant TREASURY_SPOKE = 0xB9B0b8616f6Bf6841972a52058132BE08d723155;
  address internal constant CORE_HUB = 0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9;
  address internal constant MAIN_SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
  // aave-address-book AaveV4EthereumExternalLibraries
  address internal constant LIQUIDATION_LOGIC = 0x88dF535473C5adf1f57789734A05E555F7Deb8DB;
  // aave-address-book GovernanceV3Ethereum
  address internal constant EXECUTOR_LVL_1 = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
  // aave-address-book MiscEthereum
  address internal constant V4_SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;
  // aave-address-book AaveV4Ethereum.POSITION_MANAGERS
  address internal constant CONFIG_POSITION_MANAGER = 0x51305839CE822a7b4b12AA7D86eA7005052d575c;
  address internal constant GIVER_POSITION_MANAGER = 0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e;
  address internal constant NATIVE_TOKEN_GATEWAY = 0xe68ab4F90Fe026B9873F5F276eD2d7efBbbE42Be;
  address internal constant SIGNATURE_GATEWAY = 0xfbC184337Dc6595D8bf62968Bda46e7De7AF9c3d;
  address internal constant TAKER_POSITION_MANAGER = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7;

  address internal constant AAVE_ADAPTER = 0xadca531564f3B26d0aAF48a044d741fD6cD571Ea;
  // set once deployd
  address internal constant VAULT_BTC = address(0);
  // set once deployed
  address internal constant BTC_VAULT_SWAP = address(0);
  address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address internal constant USDG = 0xe343167631d89B6Ffc58B88d6b7fB0228795491D;
  address internal constant RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
  address internal constant BTC_USD_SVR_FEED = 0xb41E773f507F7a7EA890b1afB7d2b660c30C8B0A;
  address internal constant USDT_FEED = 0x260326c220E469358846b187eE53328303Efe19C;
  address internal constant USDC_FEED = 0x3f73F03aa83B2A48ed27E964eD0fDb590332095B;
  address internal constant GHO_FEED = 0xD110cac5d8682A3b045D5524a9903E031d70FCCd;
  address internal constant WBTC_FEED = 0xDaa4B74C6bAc4e25188e64ebc68DB5050b690cAc;
  address internal constant USDG_FEED = 0x83D20dEEdcd4aC1313496c8CBcAad0fa298c0CE4;
  address internal constant RLUSD_FEED = 0xf0eaC18E908B34770FDEe46d069c846bDa866759;

  uint256 internal constant CORE_USDT_ASSET_ID = 4;
  uint256 internal constant CORE_USDC_ASSET_ID = 5;
  uint256 internal constant CORE_GHO_ASSET_ID = 6;
  uint256 internal constant CORE_RLUSD_ASSET_ID = 7;
  uint256 internal constant CORE_USDG_ASSET_ID = 8;
  uint256 internal constant CORE_WBTC_ASSET_ID = 11;

  uint256 internal constant BABYLON_VAULT_BTC_ASSET_ID = 0;
  uint256 internal constant BABYLON_USDC_ASSET_ID = 2;

  uint256 internal constant VAULT_BTC_RESERVE_ID = 0;
  uint256 internal constant BABYLON_USDC_RESERVE_ID = 2;
  uint256 internal constant EXIT_BTC_RESERVE_ID = 4;
  uint256 internal constant CORE_USDT_RESERVE_ID = 5;
  uint256 internal constant CORE_USDC_RESERVE_ID = 6;
  uint256 internal constant RESERVE_COUNT = 10;

  struct ExpectedReserve {
    address hub;
    uint256 assetId;
    address underlying;
    address priceSource;
    bool borrowable;
    uint16 collateralFactor;
    uint32 maxLiquidationBonus;
  }

  address internal _deployer = DEFAULT_SENDER;
  address internal _user = makeAddr('user');
  address internal _supplier = makeAddr('supplier');
  address internal _vaultBtc;
  string internal _marketJson;
  AaveV4BabylonConfig.Config internal _config;
  AaveV4BabylonConfig.Deployment internal _deployment;
  uint256 internal _positionManagerUpdates;
  uint256 internal _reserveAdditions;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    // deploying the market and the script harnesses exceeds the fork block gas limit
    vm.pauseGasMetering();
    vm.recordLogs();

    _config = AaveV4BabylonConfig.read('mainnet');
    _config.deployer = _deployer;
    _config.report = string.concat(OUTPUT_DIR, '1-', REPORT_NAME, '.json');

    _vaultBtc = address(new TestnetERC20('vaultBTC', 'vaultBTC', 8));
    string memory json = vm.readFile(MAINNET_CONFIG);
    assertEq(vm.split(json, VAULT_BTC_PLACEHOLDER).length, 2, 'one vaultBTC placeholder');
    _marketJson = vm.replace(
      json,
      VAULT_BTC_PLACEHOLDER,
      string.concat('"underlying": "', vm.toString(_vaultBtc), '"')
    );

    _deployAndWriteReport();
    new AaveV4BabylonConfigureHarness(_config, _marketJson).run();
    new AaveV4DeployBabylonTokenizationHarness(_config, _marketJson).run();
    AaveV4BabylonHandoverHarness handover = new AaveV4BabylonHandoverHarness(_config);
    handover.setMarketJson(_marketJson);
    handover.run();

    _deployment = AaveV4BabylonConfig.readDeployment(_config);
    Vm.Log[] memory logs = vm.getRecordedLogs();
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].topics[0] == ISpoke.UpdatePositionManager.selector) {
        ++_positionManagerUpdates;
      } else if (
        logs[i].topics[0] == ISpoke.AddReserve.selector &&
        logs[i].emitter == _deployment.babylonSpoke
      ) {
        ++_reserveAdditions;
      }
    }
    vm.resumeGasMetering();
  }

  function test_verify() public {
    new AaveV4BabylonVerifyHarness(_config, _marketJson).run();
  }

  function test_hubAndSpokeOnSharedAccessManager() public view {
    assertEq(IAccessManaged(_hub()).authority(), ACCESS_MANAGER, 'hub authority');
    assertEq(IAccessManaged(_spoke()).authority(), ACCESS_MANAGER, 'spoke authority');
    assertEq(IAccessManaged(CORE_HUB).authority(), ACCESS_MANAGER, 'core hub authority');
    assertEq(IAccessManaged(MAIN_SPOKE).authority(), ACCESS_MANAGER, 'main spoke authority');
    assertNotEq(_deployment.accessManager, ACCESS_MANAGER, 'temporary access manager');
    assertEq(
      IAccessManaged(_deployment.hubConfigurator).authority(),
      _deployment.accessManager,
      'temporary hub configurator authority'
    );
    assertEq(
      IAccessManaged(_deployment.spokeConfigurator).authority(),
      _deployment.accessManager,
      'temporary spoke configurator authority'
    );
  }

  /// @dev Until the AIP maps them, every restricted function falls back to the admin role.
  function test_restrictedFunctionsUnmappedBeforeAip() public view {
    _assertUnmapped(_hub(), _hubSelectors());
    _assertUnmapped(_spoke(), _spokeSelectors());
  }

  function test_deployerHoldsNothingOnTheMarket() public {
    IAccessManagerEnumerable temporary = IAccessManagerEnumerable(_deployment.accessManager);
    (bool isAdmin, ) = temporary.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, _deployer);
    assertFalse(isAdmin, 'deployer temporary admin');
    for (uint256 i; i < temporary.getRoleCount(); ++i) {
      (bool hasRole, ) = temporary.hasRole(temporary.getRole(i), _deployer);
      assertFalse(hasRole, 'deployer temporary role');
    }
    (isAdmin, ) = IAccessManager(ACCESS_MANAGER).hasRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      _deployer
    );
    assertFalse(isAdmin, 'deployer shared admin');

    assertEq(_proxyAdminOwner(_hub()), V4_SECURITY_COUNCIL, 'hub proxy admin owner');
    assertEq(_proxyAdminOwner(_spoke()), V4_SECURITY_COUNCIL, 'spoke proxy admin owner');

    IHub.SpokeConfig memory spokeConfig = _spokeConfig({addCap: 1, drawCap: 1, active: true});
    ISpoke.ReserveConfig memory reserveConfig = ISpoke(_spoke()).getReserveConfig(1);
    bytes memory unauthorized = abi.encodeWithSelector(
      IAccessManaged.AccessManagedUnauthorized.selector,
      _deployer
    );
    vm.startPrank(_deployer);
    vm.expectRevert(unauthorized);
    IHub(_hub()).addSpoke(0, _spoke(), spokeConfig);
    vm.expectRevert(unauthorized);
    ISpoke(_spoke()).updateReserveConfig(1, reserveConfig);
    vm.expectRevert(unauthorized);
    IHubConfigurator(_deployment.hubConfigurator).addSpoke({
      hub: _hub(),
      spoke: _spoke(),
      assetId: 0,
      config: spokeConfig
    });
    vm.expectRevert(unauthorized);
    ISpokeConfigurator(_deployment.spokeConfigurator).updateFrozen(_spoke(), 1, true);
    vm.stopPrank();
  }

  function test_unusedTreasurySpokeStaysWithDeployer() public view {
    address treasurySpoke = _deployment.treasurySpoke;
    assertEq(Ownable2StepUpgradeable(treasurySpoke).owner(), _deployer, 'owner');
    assertEq(Ownable2StepUpgradeable(treasurySpoke).pendingOwner(), address(0), 'pending owner');
    assertEq(_proxyAdminOwner(treasurySpoke), _deployer, 'proxy admin owner');
    for (uint256 assetId; assetId < IHub(_hub()).getAssetCount(); ++assetId) {
      assertEq(IHub(_hub()).getAsset(assetId).feeReceiver, TREASURY_SPOKE, 'fee receiver');
      assertFalse(IHub(_hub()).isSpokeListed(assetId, treasurySpoke), 'unused treasury listed');
      assertEq(IHub(_hub()).getSpokeAddedShares(assetId, treasurySpoke), 0, 'added shares');
      assertEq(IHub(_hub()).getSpokeDrawnShares(assetId, treasurySpoke), 0, 'drawn shares');
      (uint256 premiumShares, int256 premiumOffsetRay) = IHub(_hub()).getSpokePremiumData(
        assetId,
        treasurySpoke
      );
      assertEq(premiumShares, 0, 'premium shares');
      assertEq(premiumOffsetRay, 0, 'premium offset');
    }
  }

  function test_reserves() public view {
    ExpectedReserve[] memory expected = _expectedReserves();
    ISpoke spoke = ISpoke(_spoke());
    IAaveOracle oracle = IAaveOracle(spoke.ORACLE());
    assertEq(oracle.spoke(), _spoke(), 'oracle spoke');
    assertEq(spoke.getReserveCount(), RESERVE_COUNT, 'reserve count');

    for (uint256 reserveId; reserveId < RESERVE_COUNT; ++reserveId) {
      ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
      ExpectedReserve memory want = expected[reserveId];
      assertEq(address(reserve.hub), want.hub, 'hub');
      assertEq(reserve.assetId, want.assetId, 'asset id');
      assertEq(reserve.underlying, want.underlying, 'underlying');
      assertEq(reserve.decimals, IERC20Metadata(want.underlying).decimals(), 'decimals');
      assertEq(oracle.getReserveSource(reserveId), want.priceSource, 'price source');
      assertEq(IPriceFeed(want.priceSource).decimals(), 8, 'price source decimals');
      assertGt(oracle.getReservePrice(reserveId), 0, 'price');

      ISpoke.ReserveConfig memory config = spoke.getReserveConfig(reserveId);
      assertEq(config.collateralRisk, 0, 'collateral risk');
      assertFalse(config.paused, 'paused');
      assertFalse(config.frozen, 'frozen');
      assertEq(config.borrowable, want.borrowable, 'borrowable');
      assertFalse(config.receiveSharesEnabled, 'receive shares');

      ISpoke.DynamicReserveConfig memory dynamicConfig = spoke.getDynamicReserveConfig(
        reserveId,
        reserve.dynamicConfigKey
      );
      assertEq(dynamicConfig.collateralFactor, want.collateralFactor, 'collateral factor');
      assertEq(dynamicConfig.maxLiquidationBonus, want.maxLiquidationBonus, 'max bonus');
      assertEq(dynamicConfig.liquidationFee, 0, 'liquidation fee');
    }
  }

  /// @dev The launch AIP connects the BabylonSpoke on the Babylon Hub, the deployer only lists the assets.
  function test_babylonHubAssets() public view {
    IHub hub = IHub(_hub());
    assertEq(hub.getAssetCount(), 5, 'asset count');
    _assertBabylonHubAsset({
      assetId: 0,
      underlying: _vaultBtc,
      liquidityFee: 0,
      irData: _irData(99_00, 0, 0, 0)
    });
    _assertBabylonHubAsset({
      assetId: 1,
      underlying: USDT,
      liquidityFee: 10_00,
      irData: _irData(92_00, 0, 4_50, 20_00)
    });
    _assertBabylonHubAsset({
      assetId: 2,
      underlying: USDC,
      liquidityFee: 10_00,
      irData: _irData(92_00, 0, 4_50, 20_00)
    });
    _assertBabylonHubAsset({
      assetId: 3,
      underlying: GHO,
      liquidityFee: 10_00,
      irData: _irData(92_00, 0, 4_50, 20_00)
    });
    _assertBabylonHubAsset({
      assetId: 4,
      underlying: WBTC,
      liquidityFee: 20_00,
      irData: _irData(80_00, 25, 4_00, 60_00)
    });
  }

  /// @dev Tokenized spokes, named as every Ethereum V4 TokenizationSpoke and owned by the
  /// V4 Security Council, left unconnected until the launch AIP.
  function test_tokenizationSpokes() public view {
    address[4] memory underlyings = [USDT, USDC, GHO, WBTC];
    string[4] memory symbols = ['USDT', 'USDC', 'GHO', 'WBTC'];
    for (uint256 i; i < 4; ++i) {
      ITokenizationSpoke tokenizationSpoke = _tokenizationSpoke(symbols[i]);
      uint256 assetId = i + 1;
      assertEq(tokenizationSpoke.hub(), _hub(), 'hub');
      assertEq(tokenizationSpoke.assetId(), assetId, 'asset id');
      assertEq(tokenizationSpoke.asset(), underlyings[i], 'asset');
      assertEq(
        tokenizationSpoke.name(),
        string.concat('Wrapped Aave Babylon ', symbols[i]),
        'name'
      );
      assertEq(tokenizationSpoke.symbol(), string.concat('waBabylon', symbols[i]), 'symbol');
      assertEq(tokenizationSpoke.decimals(), IERC20Metadata(underlyings[i]).decimals(), 'decimals');
      assertEq(
        _proxyAdminOwner(address(tokenizationSpoke)),
        V4_SECURITY_COUNCIL,
        'proxy admin owner'
      );
      assertFalse(IHub(_hub()).isSpokeListed(assetId, address(tokenizationSpoke)), 'listed');
    }
  }

  function test_revert_tokenizationSpokeDeposit_beforeAip() public {
    ITokenizationSpoke tokenizationSpoke = _tokenizationSpoke('USDC');
    deal(USDC, _supplier, 1_000e6);
    vm.startPrank(_supplier);
    IERC20(USDC).approve(address(tokenizationSpoke), 1_000e6);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    tokenizationSpoke.deposit(1_000e6, _supplier);
    vm.stopPrank();
  }

  /// @dev No step activates a position manager, so only the AIP or later governance can.
  function test_noPositionManagers() public view {
    assertEq(_reserveAdditions, RESERVE_COUNT, 'deployment logs recorded');
    assertEq(_positionManagerUpdates, 0, 'position manager updates');
    address[5] memory positionManagers = [
      CONFIG_POSITION_MANAGER,
      GIVER_POSITION_MANAGER,
      NATIVE_TOKEN_GATEWAY,
      SIGNATURE_GATEWAY,
      TAKER_POSITION_MANAGER
    ];
    for (uint256 i; i < positionManagers.length; ++i) {
      assertFalse(ISpoke(_spoke()).isPositionManagerActive(positionManagers[i]), 'active');
    }
  }

  function test_coreHubUntouchedBeforeAip() public view {
    uint256[5] memory assetIds = _coreHubAssetIds();
    for (uint256 i; i < assetIds.length; ++i) {
      assertFalse(IHub(CORE_HUB).isSpokeListed(assetIds[i], _spoke()), 'spoke on core hub');
    }
  }

  /// @dev What Babylon's AaveAdapter constructor reads from the spoke.
  function test_adapterConstructorReads() public view {
    IBabylonSpoke spoke = IBabylonSpoke(_spoke());
    assertEq(spoke.LIQUIDATION_MANAGER(), AAVE_ADAPTER, 'liquidation manager');
    assertEq(spoke.MANAGED_COLLATERAL_RESERVE_ID(), VAULT_BTC_RESERVE_ID, 'managed collateral');
    ISpoke.Reserve memory vaultBtc = spoke.getReserve(VAULT_BTC_RESERVE_ID);
    assertEq(address(vaultBtc.hub), _hub(), 'vaultBTC hub');
    assertEq(vaultBtc.underlying, _vaultBtc, 'vaultBTC underlying');
    assertEq(vaultBtc.decimals, 8, 'vaultBTC decimals');
    ISpoke.Reserve memory exitBtc = spoke.getReserve(EXIT_BTC_RESERVE_ID);
    assertEq(address(exitBtc.hub), _hub(), 'exitBTC hub');
    assertEq(exitBtc.underlying, WBTC, 'exitBTC underlying');
    assertEq(exitBtc.decimals, 8, 'exitBTC decimals');
  }

  function test_liquidationConfig() public view {
    ISpoke.LiquidationConfig memory config = ISpoke(_spoke()).getLiquidationConfig();
    assertEq(config.targetHealthFactor, 1e18, 'target health factor');
    assertEq(config.healthFactorForMaxBonus, 0.9e18, 'health factor for max bonus');
    assertEq(config.liquidationBonusFactor, 90_00, 'liquidation bonus factor');
  }

  // the fork links the libraries foundry deploys, so only the links between them are checked
  function test_libraries() public view {
    address liquidationLogic = ISpoke(_spoke()).getLiquidationLogic();
    address babylonLiquidationLogic = IBabylonSpoke(_spoke()).getBabylonLiquidationLogic();
    assertGt(liquidationLogic.code.length, 0, 'liquidation logic');
    assertGt(babylonLiquidationLogic.code.length, 0, 'babylon liquidation logic');
    assertEq(
      IBabylonLiquidationLogic(babylonLiquidationLogic).getLiquidationLogic(),
      liquidationLogic,
      'babylon liquidation logic link'
    );
  }

  // verify rejects a BabylonSpoke that does not link the live LiquidationLogic
  function test_verifyLibraries_revertsWith_babylonSpokeLiquidationLogic() public {
    vm.expectRevert(bytes('babylon spoke liquidation logic'));
    this.verifyLibraries(_deployment, _config.librarySalt);
  }

  // the config's library salt resolves to the same LiquidationLogic
  function test_libraries_librarySaltResolvesToSharedLiquidationLogic() public view {
    address liquidationLogic = Create2Utils.computeCreate2Address(
      _config.librarySalt,
      vm.getCode(SpokeDeployUtils.LIQUIDATION_LOGIC_ARTIFACT)
    );
    assertEq(liquidationLogic, LIQUIDATION_LOGIC, 'liquidation logic address');
    assertGt(LIQUIDATION_LOGIC.code.length, 0, 'liquidation logic code');
  }

  /// @dev The mainnet config cannot deploy the BabylonSpoke until it has Babylon's CreateX fields.
  function test_deploySpoke_revertsWith_liquidationManagerDeployerUnset() public {
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(_config, false);
    vm.expectRevert('liquidation manager deployer unset');
    harness.run();
  }

  function test_revert_supply_marketInactive() public {
    TestnetERC20(_vaultBtc).mint(_user, 1e8);
    vm.startPrank(_user);
    IERC20(_vaultBtc).approve(_spoke(), 1e8);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    ISpoke(_spoke()).supply(VAULT_BTC_RESERVE_ID, 1e8, _user);
    vm.stopPrank();
  }

  function test_aip_roleMappingMatchesCoreHubAndMainSpoke() public {
    _executeLaunchAip();
    bytes4[] memory hubSelectors = _hubSelectors();
    for (uint256 i; i < hubSelectors.length; ++i) {
      assertEq(
        IAccessManager(ACCESS_MANAGER).getTargetFunctionRole(_hub(), hubSelectors[i]),
        IAccessManager(ACCESS_MANAGER).getTargetFunctionRole(CORE_HUB, hubSelectors[i]),
        'hub role'
      );
    }
    bytes4[] memory spokeSelectors = _spokeSelectors();
    for (uint256 i; i < spokeSelectors.length; ++i) {
      assertEq(
        IAccessManager(ACCESS_MANAGER).getTargetFunctionRole(_spoke(), spokeSelectors[i]),
        IAccessManager(ACCESS_MANAGER).getTargetFunctionRole(MAIN_SPOKE, spokeSelectors[i]),
        'spoke role'
      );
    }
  }

  function test_aip_coreHubCreditLines() public {
    _executeLaunchAip();
    uint256[5] memory assetIds = _coreHubAssetIds();
    uint40[5] memory drawCaps = [
      uint40(8_000_000),
      uint40(8_000_000),
      uint40(1_000_000),
      uint40(2_000_000),
      uint40(2_000_000)
    ];
    for (uint256 i; i < assetIds.length; ++i) {
      assertEq(
        abi.encode(IHub(CORE_HUB).getSpokeConfig(assetIds[i], _spoke())),
        abi.encode(_spokeConfig({addCap: 0, drawCap: drawCaps[i], active: true})),
        'credit line'
      );
    }
  }

  function test_aip_babylonHubActive() public {
    uint40[5] memory addCaps = [
      uint40(300),
      uint40(5_000_000),
      uint40(5_000_000),
      uint40(1_000_000),
      uint40(100)
    ];
    uint40[5] memory drawCaps = [
      uint40(0),
      uint40(4_600_000),
      uint40(4_600_000),
      uint40(920_000),
      uint40(80)
    ];
    _executeLaunchAip();
    for (uint256 assetId; assetId < 5; ++assetId) {
      assertEq(
        abi.encode(IHub(_hub()).getSpokeConfig(assetId, _spoke())),
        abi.encode(
          _spokeConfig({addCap: addCaps[assetId], drawCap: drawCaps[assetId], active: true})
        ),
        'babylon hub spoke config'
      );
    }
  }

  function test_aip_tokenizationSpokes() public {
    uint40[4] memory addCaps = [
      uint40(1_000_000),
      uint40(1_000_000),
      uint40(1_000_000),
      uint40(10)
    ];
    string[4] memory symbols = ['USDT', 'USDC', 'GHO', 'WBTC'];
    _executeLaunchAip();
    for (uint256 i; i < 4; ++i) {
      assertEq(
        abi.encode(IHub(_hub()).getSpokeConfig(i + 1, address(_tokenizationSpoke(symbols[i])))),
        abi.encode(_spokeConfig({addCap: addCaps[i], drawCap: 0, active: true})),
        'tokenization spoke config'
      );
    }
  }

  function test_aip_tokenizationSpokeDeposit() public {
    _executeLaunchAip();
    ITokenizationSpoke tokenizationSpoke = _tokenizationSpoke('USDC');
    deal(USDC, _supplier, 1_000e6);
    vm.startPrank(_supplier);
    IERC20(USDC).approve(address(tokenizationSpoke), 1_000e6);
    uint256 shares = tokenizationSpoke.deposit(1_000e6, _supplier);
    vm.stopPrank();
    assertEq(tokenizationSpoke.balanceOf(_supplier), shares, 'shares');
    assertEq(tokenizationSpoke.totalAssets(), 1_000e6, 'total assets');
  }

  function test_aip_borrowFromCoreHubCreditLine() public {
    _executeLaunchAip();
    _supplyVaultBtcAsCollateral(10e8);
    uint256 coreDrawnBefore = IHub(CORE_HUB).getSpokeDrawnShares(CORE_USDC_ASSET_ID, _spoke());

    vm.prank(_user);
    ISpoke(_spoke()).borrow(CORE_USDC_RESERVE_ID, 10_000e6, _user);

    assertEq(IERC20(USDC).balanceOf(_user), 10_000e6, 'user usdc');
    assertGe(ISpoke(_spoke()).getUserTotalDebt(CORE_USDC_RESERVE_ID, _user), 10_000e6, 'debt');
    assertGt(
      IHub(CORE_HUB).getSpokeDrawnShares(CORE_USDC_ASSET_ID, _spoke()),
      coreDrawnBefore,
      'core hub drawn'
    );
  }

  function test_aip_revertsWith_coreHubDrawCapExceeded() public {
    _executeLaunchAip();
    _supplyVaultBtcAsCollateral(300e8);
    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, 8_000_000));
    vm.prank(_user);
    ISpoke(_spoke()).borrow(CORE_USDC_RESERVE_ID, 8_000_001e6, _user);
  }

  function test_aip_revertsWith_vaultBtcAddCapExceeded() public {
    _executeLaunchAip();
    TestnetERC20(_vaultBtc).mint(_user, 301e8);
    vm.startPrank(_user);
    IERC20(_vaultBtc).approve(_spoke(), 301e8);
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, 300));
    ISpoke(_spoke()).supply(VAULT_BTC_RESERVE_ID, 301e8, _user);
    vm.stopPrank();
  }

  function test_aip_borrowFromBabylonHub() public {
    _executeLaunchAip();
    deal(USDC, _supplier, 100_000e6);
    vm.startPrank(_supplier);
    IERC20(USDC).approve(_spoke(), 100_000e6);
    ISpoke(_spoke()).supply(BABYLON_USDC_RESERVE_ID, 100_000e6, _supplier);
    vm.stopPrank();
    _supplyVaultBtcAsCollateral(10e8);

    vm.prank(_user);
    ISpoke(_spoke()).borrow(BABYLON_USDC_RESERVE_ID, 10_000e6, _user);

    assertEq(IERC20(USDC).balanceOf(_user), 10_000e6, 'user usdc');
    assertGt(IHub(_hub()).getSpokeDrawnShares(BABYLON_USDC_ASSET_ID, _spoke()), 0, 'drawn');
  }

  function test_aip_revertsWith_secondDebtReserve() public {
    _executeLaunchAip();
    _supplyVaultBtcAsCollateral(10e8);
    vm.startPrank(_user);
    ISpoke(_spoke()).borrow(CORE_USDC_RESERVE_ID, 1_000e6, _user);
    vm.expectRevert(ISpoke.MaximumUserReservesExceeded.selector);
    ISpoke(_spoke()).borrow(CORE_USDT_RESERVE_ID, 1_000e6, _user);
    vm.stopPrank();
  }

  function test_aip_revertsWith_borrowManagedCollateral() public {
    _executeLaunchAip();
    _supplyVaultBtcAsCollateral(10e8);
    vm.expectRevert(ISpoke.ReserveNotBorrowable.selector);
    vm.prank(_user);
    ISpoke(_spoke()).borrow(VAULT_BTC_RESERVE_ID, 1, _user);
  }

  function test_aip_liveConfiguratorsGovernTheMarket() public {
    _executeLaunchAip();
    vm.startPrank(EXECUTOR_LVL_1);
    ISpokeConfigurator(SPOKE_CONFIGURATOR).updateFrozen(_spoke(), BABYLON_USDC_RESERVE_ID, true);
    IHubConfigurator(HUB_CONFIGURATOR).updateSpokeDrawCap({
      hub: _hub(),
      assetId: BABYLON_USDC_ASSET_ID,
      spoke: _spoke(),
      drawCap: 1
    });
    vm.stopPrank();

    assertTrue(ISpoke(_spoke()).getReserveConfig(BABYLON_USDC_RESERVE_ID).frozen, 'frozen');
    assertEq(IHub(_hub()).getSpokeConfig(BABYLON_USDC_ASSET_ID, _spoke()).drawCap, 1, 'draw cap');
  }

  function test_aip_revertsWith_liquidationNotFromAdapter() public {
    _executeLaunchAip();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    IBabylonSpoke(_spoke()).liquidationCall(CORE_USDC_RESERVE_ID, 1, _user, 1);
    vm.expectRevert(IBabylonSpoke.UnsupportedLiquidationCall.selector);
    ISpoke(_spoke()).liquidationCall(VAULT_BTC_RESERVE_ID, CORE_USDC_RESERVE_ID, _user, 1, false);
  }

  // will fail until Babylon deploys vaultBTC
  function test_babylon_vaultBtc() public view {
    vm.skip(true, 'post-babylon deployment, step 3');
    assertEq(IVaultBTC(VAULT_BTC).HUB(), _hub(), 'hub');
    assertEq(IVaultBTC(VAULT_BTC).adapter(), AAVE_ADAPTER, 'adapter');
  }

  // will fail until Babylon deploys the AaveAdapter
  function test_babylon_aaveAdapter() public view {
    vm.skip(true, 'post-babylon deployment, step 5');
    assertEq(IAaveAdapter(AAVE_ADAPTER).BTC_VAULT_CORE_SPOKE(), _spoke(), 'babylon spoke');
    assertEq(IAaveAdapter(AAVE_ADAPTER).EXIT_BTC_RESERVE_ID(), EXIT_BTC_RESERVE_ID, 'exitBTC');
    assertEq(
      IAaveAdapter(AAVE_ADAPTER).VAULT_BTC_RESERVE_ID(),
      VAULT_BTC_RESERVE_ID,
      'vaultBTC reserve id'
    );
    assertEq(IAaveAdapter(AAVE_ADAPTER).BTC_VAULT_HUB(), _hub(), 'babylon hub');
    assertEq(
      IAaveAdapter(AAVE_ADAPTER).VAULT_BTC_ASSET_ID(),
      BABYLON_VAULT_BTC_ASSET_ID,
      'vaultBTC asset id'
    );
  }

  // will fail until Babylon deploys BTCVaultSwap
  function test_babylon_btcVaultSwap() public view {
    vm.skip(true, 'post-babylon deployment, step 5');
    IBTCVaultSwap btcVaultSwap = IBTCVaultSwap(BTC_VAULT_SWAP);
    assertEq(btcVaultSwap.ADAPTER(), AAVE_ADAPTER, 'adapter');
    assertEq(btcVaultSwap.HUB(), CORE_HUB, 'hub');
    assertEq(btcVaultSwap.EXIT_BTC_ASSET_ID(), CORE_WBTC_ASSET_ID, 'exitBTC asset id');
    assertEq(IAccessManaged(BTC_VAULT_SWAP).authority(), ACCESS_MANAGER, 'authority');
    assertEq(_proxyAdminOwner(BTC_VAULT_SWAP), V4_SECURITY_COUNCIL, 'proxy admin owner');
  }

  function verifyLibraries(
    AaveV4BabylonConfig.Deployment memory deployment,
    bytes32 librarySalt
  ) external view {
    AaveV4BabylonVerification.verifyLibraries(deployment, librarySalt);
  }

  function deployHubs() external returns (OrchestrationReports.FullDeploymentReport memory report) {
    InputUtils.FullDeployInputs memory inputs = new AaveV4DeployBabylonHubHarness(_config)
      .sanitizedDeployInputs(_deployer);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    bytes memory hubBytecode = BytecodeHelper.getHubBytecode();
    bytes memory spokeBytecode = BytecodeHelper.getSpokeBytecode();
    bytes memory babylonSpokeBytecode = BytecodeHelper.getBabylonSpokeBytecode();
    vm.startPrank(_deployer);
    report = AaveV4DeployOrchestration.deployAaveV4({
      logger: logger,
      deployer: _deployer,
      deployInputs: inputs,
      hubBytecode: hubBytecode,
      spokeBytecode: spokeBytecode,
      babylonSpokeBytecode: babylonSpokeBytecode
    });
    vm.stopPrank();
  }

  /// @dev Launch AIP actions in proposal order: the Hub and BabylonSpoke role mappings, the BabylonSpoke
  /// and TokenizationSpoke connections on the Babylon Hub, then the Core Hub credit lines. Caps follow
  /// the LlamaRisk parameters of 10 Nov 2026. BTCVaultSwap, which Babylon deploys, is not covered.
  function _executeLaunchAip() internal {
    vm.deal(EXECUTOR_LVL_1, 1 ether);
    vm.startPrank(EXECUTOR_LVL_1);
    IAccessManager accessManager = IAccessManager(ACCESS_MANAGER);
    accessManager.setTargetFunctionRole(
      _hub(),
      Roles.getHubConfiguratorRoleSelectors(),
      Roles.HUB_CONFIGURATOR_ROLE
    );
    accessManager.setTargetFunctionRole(
      _hub(),
      Roles.getHubFeeMinterRoleSelectors(),
      Roles.HUB_FEE_MINTER_ROLE
    );
    accessManager.setTargetFunctionRole(
      _hub(),
      Roles.getHubDeficitEliminatorRoleSelectors(),
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE
    );
    accessManager.setTargetFunctionRole(
      _spoke(),
      Roles.getSpokeConfiguratorRoleSelectors(),
      Roles.SPOKE_CONFIGURATOR_ROLE
    );
    accessManager.setTargetFunctionRole(
      _spoke(),
      Roles.getSpokePositionUpdaterRoleSelectors(),
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE
    );

    uint40[5] memory babylonAddCaps = [
      uint40(300),
      uint40(5_000_000),
      uint40(5_000_000),
      uint40(1_000_000),
      uint40(100)
    ];
    uint40[5] memory babylonDrawCaps = [
      uint40(0),
      uint40(4_600_000),
      uint40(4_600_000),
      uint40(920_000),
      uint40(80)
    ];
    for (uint256 assetId; assetId < 5; ++assetId) {
      IHubConfigurator(HUB_CONFIGURATOR).addSpoke({
        hub: _hub(),
        spoke: _spoke(),
        assetId: assetId,
        config: _spokeConfig({
          addCap: babylonAddCaps[assetId],
          drawCap: babylonDrawCaps[assetId],
          active: true
        })
      });
    }
    uint40[4] memory tokenizedAddCaps = [
      uint40(1_000_000),
      uint40(1_000_000),
      uint40(1_000_000),
      uint40(10)
    ];
    string[4] memory tokenizedSymbols = ['USDT', 'USDC', 'GHO', 'WBTC'];
    for (uint256 i; i < 4; ++i) {
      IHubConfigurator(HUB_CONFIGURATOR).addSpoke({
        hub: _hub(),
        spoke: address(_tokenizationSpoke(tokenizedSymbols[i])),
        assetId: i + 1,
        config: _spokeConfig({addCap: tokenizedAddCaps[i], drawCap: 0, active: true})
      });
    }
    uint256[5] memory assetIds = _coreHubAssetIds();
    uint40[5] memory drawCaps = [
      uint40(8_000_000),
      uint40(8_000_000),
      uint40(1_000_000),
      uint40(2_000_000),
      uint40(2_000_000)
    ];
    for (uint256 i; i < assetIds.length; ++i) {
      IHubConfigurator(HUB_CONFIGURATOR).addSpoke({
        hub: CORE_HUB,
        spoke: _spoke(),
        assetId: assetIds[i],
        config: _spokeConfig({addCap: 0, drawCap: drawCaps[i], active: true})
      });
    }
    vm.stopPrank();
  }

  function _supplyVaultBtcAsCollateral(uint256 amount) internal {
    TestnetERC20(_vaultBtc).mint(_user, amount);
    vm.startPrank(_user);
    IERC20(_vaultBtc).approve(_spoke(), amount);
    ISpoke(_spoke()).supply(VAULT_BTC_RESERVE_ID, amount, _user);
    ISpoke(_spoke()).setUsingAsCollateral(VAULT_BTC_RESERVE_ID, true, _user);
    vm.stopPrank();
  }

  /// @dev Step 2 deploys the Hub and writes the report, step 3 runs the BabylonSpoke script on it.
  /// The CreateX check is skipped until Babylon shares its deployer and salt.
  function _deployAndWriteReport() internal {
    OrchestrationReports.FullDeploymentReport memory report = this.deployHubs();
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    logger.writeJsonReportMarket(report);
    logger.save({fileName: REPORT_NAME, withTimestamp: false});
    new AaveV4DeployBabylonSpokeHarness(_config, true).run();
  }

  function _assertBabylonHubAsset(
    uint256 assetId,
    address underlying,
    uint16 liquidityFee,
    IAssetInterestRateStrategy.InterestRateData memory irData
  ) internal view {
    IHub.Asset memory asset = IHub(_hub()).getAsset(assetId);
    assertEq(asset.underlying, underlying, 'asset underlying');
    assertEq(asset.feeReceiver, TREASURY_SPOKE, 'asset fee receiver');
    assertEq(asset.liquidityFee, liquidityFee, 'asset liquidity fee');
    assertEq(
      abi.encode(IAssetInterestRateStrategy(asset.irStrategy).getInterestRateData(assetId)),
      abi.encode(irData),
      'asset ir data'
    );
    assertFalse(IHub(_hub()).isSpokeListed(assetId, _spoke()), 'babylon spoke listed');
    assertEq(IHub(_hub()).getSpokeCount(assetId), 1, 'only the fee receiver');
  }

  function _assertUnmapped(address target, bytes4[] memory selectors) internal view {
    for (uint256 i; i < selectors.length; ++i) {
      assertEq(
        IAccessManager(ACCESS_MANAGER).getTargetFunctionRole(target, selectors[i]),
        Roles.ACCESS_MANAGER_ADMIN_ROLE,
        'unmapped selector'
      );
      (bool executorCan, ) = IAccessManager(ACCESS_MANAGER).canCall(
        EXECUTOR_LVL_1,
        target,
        selectors[i]
      );
      assertTrue(executorCan, 'executor can call');
      (bool hubConfiguratorCan, ) = IAccessManager(ACCESS_MANAGER).canCall(
        HUB_CONFIGURATOR,
        target,
        selectors[i]
      );
      assertFalse(hubConfiguratorCan, 'hub configurator cannot call');
      (bool spokeConfiguratorCan, ) = IAccessManager(ACCESS_MANAGER).canCall(
        SPOKE_CONFIGURATOR,
        target,
        selectors[i]
      );
      assertFalse(spokeConfiguratorCan, 'spoke configurator cannot call');
    }
  }

  function _expectedReserves() internal view returns (ExpectedReserve[] memory expected) {
    expected = new ExpectedReserve[](RESERVE_COUNT);
    expected[0] = ExpectedReserve({
      hub: _hub(),
      assetId: 0,
      underlying: _vaultBtc,
      priceSource: BTC_USD_SVR_FEED,
      borrowable: false,
      collateralFactor: 78_00,
      maxLiquidationBonus: 105_55
    });
    expected[1] = ExpectedReserve({
      hub: _hub(),
      assetId: 1,
      underlying: USDT,
      priceSource: USDT_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[2] = ExpectedReserve({
      hub: _hub(),
      assetId: 2,
      underlying: USDC,
      priceSource: USDC_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[3] = ExpectedReserve({
      hub: _hub(),
      assetId: 3,
      underlying: GHO,
      priceSource: GHO_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[4] = ExpectedReserve({
      hub: _hub(),
      assetId: 4,
      underlying: WBTC,
      priceSource: WBTC_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[5] = ExpectedReserve({
      hub: CORE_HUB,
      assetId: CORE_USDT_ASSET_ID,
      underlying: USDT,
      priceSource: USDT_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[6] = ExpectedReserve({
      hub: CORE_HUB,
      assetId: CORE_USDC_ASSET_ID,
      underlying: USDC,
      priceSource: USDC_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[7] = ExpectedReserve({
      hub: CORE_HUB,
      assetId: CORE_GHO_ASSET_ID,
      underlying: GHO,
      priceSource: GHO_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[8] = ExpectedReserve({
      hub: CORE_HUB,
      assetId: CORE_USDG_ASSET_ID,
      underlying: USDG,
      priceSource: USDG_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
    expected[9] = ExpectedReserve({
      hub: CORE_HUB,
      assetId: CORE_RLUSD_ASSET_ID,
      underlying: RLUSD,
      priceSource: RLUSD_FEED,
      borrowable: true,
      collateralFactor: 0,
      maxLiquidationBonus: 100_00
    });
  }

  function _coreHubAssetIds() internal pure returns (uint256[5] memory) {
    return
      [
        CORE_USDT_ASSET_ID,
        CORE_USDC_ASSET_ID,
        CORE_GHO_ASSET_ID,
        CORE_USDG_ASSET_ID,
        CORE_RLUSD_ASSET_ID
      ];
  }

  function _hubSelectors() internal pure returns (bytes4[] memory) {
    return
      _concat(
        _concat(Roles.getHubConfiguratorRoleSelectors(), Roles.getHubFeeMinterRoleSelectors()),
        Roles.getHubDeficitEliminatorRoleSelectors()
      );
  }

  function _spokeSelectors() internal pure returns (bytes4[] memory) {
    return
      _concat(
        Roles.getSpokeConfiguratorRoleSelectors(),
        Roles.getSpokePositionUpdaterRoleSelectors()
      );
  }

  function _concat(bytes4[] memory a, bytes4[] memory b) internal pure returns (bytes4[] memory c) {
    c = new bytes4[](a.length + b.length);
    for (uint256 i; i < a.length; ++i) {
      c[i] = a[i];
    }
    for (uint256 i; i < b.length; ++i) {
      c[a.length + i] = b[i];
    }
  }

  function _spokeConfig(
    uint40 addCap,
    uint40 drawCap,
    bool active
  ) internal pure returns (IHub.SpokeConfig memory) {
    return
      IHub.SpokeConfig({
        addCap: addCap,
        drawCap: drawCap,
        riskPremiumThreshold: 0,
        active: active,
        halted: false
      });
  }

  function _irData(
    uint16 optimalUsageRatio,
    uint32 baseDrawnRate,
    uint32 rateGrowthBeforeOptimal,
    uint32 rateGrowthAfterOptimal
  ) internal pure returns (IAssetInterestRateStrategy.InterestRateData memory) {
    return
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: optimalUsageRatio,
        baseDrawnRate: baseDrawnRate,
        rateGrowthBeforeOptimal: rateGrowthBeforeOptimal,
        rateGrowthAfterOptimal: rateGrowthAfterOptimal
      });
  }

  function _tokenizationSpoke(string memory symbol) internal view returns (ITokenizationSpoke) {
    (address proxy, ) = AaveV4BabylonConfig.readTokenizationSpoke(
      _config,
      string.concat('waBabylon', symbol)
    );
    return ITokenizationSpoke(proxy);
  }

  function _hub() internal view returns (address) {
    return _deployment.hubs[0];
  }

  function _spoke() internal view returns (address) {
    return _deployment.babylonSpoke;
  }

  function _proxyAdminOwner(address proxy) internal view returns (address) {
    return ProxyAdmin(ProxyHelper.getProxyAdmin(proxy)).owner();
  }
}
