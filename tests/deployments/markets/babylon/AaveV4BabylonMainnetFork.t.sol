// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, Vm} from 'forge-std/Test.sol';
import {
  AaveV4DeployBabylonSpokeHarness,
  AaveV4BabylonVerifyHarness
} from 'tests/deployments/markets/babylon/AaveV4Babylon.t.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {AaveV4BabylonHandover} from 'scripts/markets/babylon/AaveV4BabylonHandover.s.sol';
import {AaveV4BabylonVerification} from 'scripts/markets/babylon/AaveV4BabylonVerification.sol';
import {IBabylonBTCVaultSwap} from 'scripts/markets/babylon/interfaces/IBabylonIntegration.sol';
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
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

interface IVaultBTC {
  function HUB() external view returns (address);

  function adapter() external view returns (address);

  function mint(address to, uint256 amount) external;

  function addValidProxy(address proxyAddress) external;
}

interface IAaveAdapter {
  function BTC_VAULT_CORE_SPOKE() external view returns (address);

  function BTC_VAULT_HUB() external view returns (address);

  function EXIT_BTC_RESERVE_ID() external view returns (uint256);

  function liquidationFeeBps() external view returns (uint256);

  function VAULT_BTC_ASSET_ID() external view returns (uint256);

  function VAULT_BTC_RESERVE_ID() external view returns (uint256);
}

interface IBTCVaultSwap {
  function ADAPTER() external view returns (address);

  function HUB() external view returns (address);

  function EXIT_BTC_ASSET_ID() external view returns (uint256);

  function isPaused() external view returns (bool);

  function isFrozen() external view returns (bool);

  function setSwapFeeBps(uint256 sellDiscountBps, uint256 minimumProfitThresholdBps) external;

  function pause() external;

  function unpause() external;

  function freeze() external;

  function unfreeze() external;
}

/// @dev The Ethereum V4 RiskSteward entry points the tests call.
interface IV4RiskSteward {
  function updateHubSpokeCaps(IAaveV4ConfigEngine.SpokeConfigUpdate[] calldata updates) external;

  function updateDynamicReserveConfigs(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] calldata updates
  ) external;
}

/// @dev Babylon's BTCVaultRegistry vault record, as the AaveAdapter reads it.
struct BTCVaultBasicInfo {
  address depositor;
  bytes32 depositorBtcPubKey;
  uint256 amount;
  address vaultProvider;
  uint8 status;
  address applicationEntryPoint;
  uint256 createdAt;
}

struct BTCVaultProtocolInfo {
  bytes depositorSignedPeginTx;
  uint16 universalChallengersVersion;
  uint16 appVaultKeepersVersion;
  uint16 offchainParamsVersion;
  uint256 verifiedAt;
  bytes32 depositorWotsPkHash;
  bytes32 hashlock;
  uint8 htlcVout;
  bytes depositorPopSignature;
  bytes32 prePeginTxHash;
  uint16 vaultProviderCommissionBps;
  uint256 claimExpiredUntil;
  uint16 vaultCoreVersion;
  uint64 vpKeyEpoch;
  uint64 appKeeperKeyEpoch;
  uint64 ucKeyEpoch;
}

struct TokenAmount {
  address token;
  uint256 amount;
}

struct MarketPosition {
  bytes32[] vaultIds;
  uint256 totalCollateralBTC;
  address proxyContract;
}

/// @dev The AaveAdapter entry points the liquidation tests call.
interface IAaveAdapterFlows {
  function activateVault(
    bytes32 vaultId,
    BTCVaultBasicInfo memory info,
    bytes memory data
  ) external;

  function borrowFromCorePosition(
    uint256 debtReserveId,
    uint256 amount,
    address receiver
  ) external returns (uint256, uint256);

  function liquidate(
    address borrower,
    uint256 debtReserveId,
    uint256 maxDebtToRepay,
    uint256 maxExitBtc,
    bytes32 claimerBtcPubKey
  ) external returns (bytes32, uint256);

  function liquidateWithLLP(
    address borrower,
    address llp,
    uint256 debtReserveId,
    uint256 maxDebtToRepay,
    uint256 maxExitBtc,
    TokenAmount[] memory minPayouts
  ) external returns (bytes32, uint256, TokenAmount[] memory);

  function getPosition(address borrower) external view returns (MarketPosition memory);

  function unfreeze() external;

  function applicationRecipient() external view returns (address);

  function BTC_VAULT_REGISTRY() external view returns (address);

  function APP_REGISTRY() external view returns (address);
}

interface IBTCVaultSwapFlows {
  function swapExitBtcForVault(bytes32 vaultId, uint256 maxExitBtc) external returns (uint256);
}

interface IBTCVaultRegistry {
  function getBtcVaultBasicInfo(bytes32 vaultId) external view returns (BTCVaultBasicInfo memory);

  function getBTCVaultAmountsBatch(
    bytes32[] calldata vaultIds
  ) external view returns (uint256[] memory);

  function redeemVaultForAVK(bytes32 vaultId, bytes32 claimerBtcPubKey) external;

  function redeemVaultForDepositor(bytes32 vaultId) external;

  function getBtcVaultProtocolInfo(
    bytes32 vaultId
  ) external view returns (BTCVaultProtocolInfo memory);
}

interface IApplicationRegistry {
  function getVaultKeeperBTCKeyInVersion(address, address, uint16) external view returns (bytes32);

  function getOperationBtcKeyAtEpochOrGenesis(
    address,
    address,
    uint64,
    bytes32
  ) external view returns (bytes32);
}

/// @dev Repeats `AaveV4BabylonHandover.run` on the mainnet config, broadcasting as the config
/// deployer, whose key a test cannot use.
contract AaveV4BabylonHandoverForkHarness is AaveV4BabylonHandover {
  string internal constant CONFIG_NAME = 'mainnet';

  function runAsConfigDeployer() external {
    AaveV4BabylonConfig.Config memory config = _config();
    AaveV4BabylonConfig.Deployment memory deployment = AaveV4BabylonConfig.readDeployment(config);
    AaveV4BabylonConfig.MarketConfig memory marketConfig = _marketConfig(config, deployment);

    AaveV4BabylonVerification.verifyDeployment({
      config: config,
      deployment: deployment,
      authority: deployment.accessManager
    });
    AaveV4BabylonVerification.verifyMarketConfig({
      deployment: deployment,
      marketConfig: marketConfig,
      feeReceiver: AaveV4BabylonConfig.feeReceiver(config, deployment)
    });
    AaveV4BabylonVerification.verifyTokenizationSpokes({
      config: config,
      marketConfig: marketConfig,
      owner: config.admin
    });
    AaveV4BabylonVerification.verifyBabylonContracts(config, deployment);
    AaveV4BabylonVerification.verifyProductionConfig(config);
    AaveV4BabylonVerification.verifyAuthorityTargets(config, deployment);

    vm.startBroadcast(config.deployer);
    (, address deployer, ) = vm.readCallers();
    AaveV4BabylonConfig.requireDeployer(config, deployer);
    _handover({config: config, deployment: deployment, deployer: deployer});
    vm.stopBroadcast();

    AaveV4BabylonVerification.verifyDeployment({
      config: config,
      deployment: deployment,
      authority: AaveV4BabylonConfig.finalAuthority(config, deployment)
    });
    if (config.authority == address(0)) {
      AaveV4BabylonVerification.verifyRoles({
        deployment: deployment,
        admin: config.admin,
        deployer: config.deployer
      });
    } else {
      AaveV4BabylonVerification.verifyAbandonedAccessManager({
        deployment: deployment,
        admin: config.admin,
        deployer: deployer
      });
    }
    AaveV4BabylonVerification.verifyProxyAdmins({
      deployment: deployment,
      owner: config.admin,
      externalSpokes: marketConfig.externalSpokes,
      externalFeeReceiver: config.feeReceiver,
      treasurySpokeOwner: AaveV4BabylonConfig.treasurySpokeOwner(config)
    });
    AaveV4BabylonVerification.verifyTreasurySpokeOwner({
      deployment: deployment,
      owner: AaveV4BabylonConfig.treasurySpokeOwner(config),
      allowPending: config.feeReceiver == address(0)
    });
  }

  function _config() internal view override returns (AaveV4BabylonConfig.Config memory) {
    return AaveV4BabylonConfig.read(CONFIG_NAME);
  }

  function _marketConfig(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view override returns (AaveV4BabylonConfig.MarketConfig memory) {
    return
      AaveV4BabylonConfig.parseMarketConfig({
        json: vm.readFile(AaveV4BabylonConfig.path(CONFIG_NAME)),
        config: config,
        deployment: deployment
      });
  }
}

/// @dev Runs the production handover on the deployed Babylon market on an Ethereum fork and asserts
/// the state after it (step 5b of the launch plan), then the state after the launch AIP actions on
/// the shared V4 contracts. Expected values come from the LlamaRisk parameters, aave-address-book
/// and Babylon's deployment, not from `config/mainnet.json`.
contract AaveV4BabylonMainnetForkTest is Test {
  uint256 internal constant FORK_BLOCK = 26_407_250;
  uint256 internal constant SPOKE_DEPLOY_BLOCK = 26_394_302;
  string internal constant MAINNET_CONFIG = 'scripts/markets/babylon/config/mainnet.json';

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
  address internal constant V4_SECURITY_COUNCIL_EXECUTOR =
    0x14339e2178A954d5FB839D5Ff31644fE0F25F517;
  // aave-address-book AaveV4Ethereum
  address internal constant RISK_STEWARD = 0x6f48d9Cdb8EE6E17c96B2d8Aec128af426A295c1;
  address internal constant RISK_COUNCIL = 0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8;
  // aave-address-book AaveV4Ethereum.POSITION_MANAGERS
  address internal constant CONFIG_POSITION_MANAGER = 0x51305839CE822a7b4b12AA7D86eA7005052d575c;
  address internal constant GIVER_POSITION_MANAGER = 0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e;
  address internal constant NATIVE_TOKEN_GATEWAY = 0xe68ab4F90Fe026B9873F5F276eD2d7efBbbE42Be;
  address internal constant SIGNATURE_GATEWAY = 0xfbC184337Dc6595D8bf62968Bda46e7De7AF9c3d;
  address internal constant TAKER_POSITION_MANAGER = 0x6c044c0D3801499bCAbfAd458B70880bc518e9F7;

  address internal constant AAVE_ADAPTER = 0xadca531564f3B26d0aAF48a044d741fD6cD571Ea;
  address internal constant VAULT_BTC = 0x69712D713FD30aBEF48b5D14eC2a9FB834D2c341;
  address internal constant BTC_VAULT_SWAP = 0xFe354b6A67E9a308B600d35B0b3e2e6F33f3c6d9;
  // 2-of-3 Safe setting the BTCVaultSwap fees
  address internal constant BTC_VAULT_SWAP_MULTISIG = 0x828AA986e31D60Eb07EFC1543FF9297835f4A9f7;
  // Babylon's Interim Governance Safe, which unfreezes the AaveAdapter
  address internal constant BABYLON_INTERIM_GOVERNANCE = 0xcd9e54acA1B7fb9BcE10208201b01559A6B01949;
  bytes32 internal constant VAULT_ID = keccak256('vault');
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

  uint64 internal constant BTC_VAULT_SWAP_FEE_ROLE = 2001;
  uint64 internal constant BTC_VAULT_SWAP_GUARDIAN_ROLE = 2002;
  uint32 internal constant BTC_VAULT_SWAP_FEE_DELAY = 5 days;
  uint40 internal constant BTC_VAULT_SWAP_DRAW_CAP = 20;

  struct ExpectedReserve {
    address hub;
    uint256 assetId;
    address underlying;
    address priceSource;
    bool borrowable;
    uint16 collateralFactor;
    uint32 maxLiquidationBonus;
  }

  address internal _deployer;
  address internal _user = makeAddr('user');
  address internal _supplier = makeAddr('supplier');
  address internal _liquidator = makeAddr('liquidator');
  string internal _marketJson;
  AaveV4BabylonConfig.Config internal _config;
  AaveV4BabylonConfig.Deployment internal _deployment;
  uint256 internal _handoverPositionManagerUpdates;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    _config = AaveV4BabylonConfig.read('mainnet');
    _deployer = _config.deployer;
    _marketJson = vm.readFile(MAINNET_CONFIG);
    _deployment = AaveV4BabylonConfig.readDeployment(_config);

    vm.recordLogs();
    new AaveV4BabylonHandoverForkHarness().runAsConfigDeployer();
    Vm.Log[] memory logs = vm.getRecordedLogs();
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].topics[0] == ISpoke.UpdatePositionManager.selector) {
        ++_handoverPositionManagerUpdates;
      }
    }
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

  function test_btcVaultSwapUnmappedBeforeAip() public view {
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(ACCESS_MANAGER);
    assertEq(
      accessManager.getTargetFunctionRole(BTC_VAULT_SWAP, IBTCVaultSwap.setSwapFeeBps.selector),
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      'fee selector'
    );
    bytes4[] memory selectors = _btcVaultSwapGuardianSelectors();
    for (uint256 i; i < selectors.length; ++i) {
      assertEq(
        accessManager.getTargetFunctionRole(BTC_VAULT_SWAP, selectors[i]),
        Roles.ACCESS_MANAGER_ADMIN_ROLE,
        'guardian selector'
      );
    }
    assertFalse(accessManager.isRole(BTC_VAULT_SWAP_FEE_ROLE), 'fee role');
    assertFalse(accessManager.isRole(BTC_VAULT_SWAP_GUARDIAN_ROLE), 'guardian role');
    assertFalse(IHub(CORE_HUB).isSpokeListed(CORE_WBTC_ASSET_ID, BTC_VAULT_SWAP), 'credit line');
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
      underlying: VAULT_BTC,
      liquidityFee: 0,
      irData: _irData(99_00, 0, 0, 0)
    });
    _assertBabylonHubAsset({
      assetId: 1,
      underlying: USDT,
      liquidityFee: 10_00,
      irData: _irData(90_00, 0, 4_50, 20_00)
    });
    _assertBabylonHubAsset({
      assetId: 2,
      underlying: USDC,
      liquidityFee: 10_00,
      irData: _irData(90_00, 0, 4_50, 20_00)
    });
    _assertBabylonHubAsset({
      assetId: 3,
      underlying: GHO,
      liquidityFee: 10_00,
      irData: _irData(90_00, 0, 4_50, 20_00)
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
    bytes32[] memory topics = new bytes32[](1);
    topics[0] = ISpoke.AddReserve.selector;
    assertEq(
      vm.eth_getLogs(SPOKE_DEPLOY_BLOCK, FORK_BLOCK, _spoke(), topics).length,
      RESERVE_COUNT,
      'deployment logs read'
    );
    topics[0] = ISpoke.UpdatePositionManager.selector;
    assertEq(
      vm.eth_getLogs(SPOKE_DEPLOY_BLOCK, FORK_BLOCK, _spoke(), topics).length,
      0,
      'position manager updates'
    );
    assertEq(_handoverPositionManagerUpdates, 0, 'handover position manager updates');
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
    assertEq(vaultBtc.underlying, VAULT_BTC, 'vaultBTC underlying');
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

  function test_libraries() public view {
    assertGt(ISpoke(_spoke()).getLiquidationLogic().code.length, 0, 'liquidation logic');
    assertGt(
      IBabylonSpoke(_spoke()).getBabylonLiquidationLogic().code.length,
      0,
      'babylon liquidation logic'
    );
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

  /// @dev Babylon's CreateX deployer and salt map to the configured liquidation manager on CreateX.
  function test_requireLiquidationManager() public {
    AaveV4BabylonConfig.Config memory config = AaveV4BabylonConfig.read('mainnet');
    assertEq(config.liquidationManager, AAVE_ADAPTER, 'liquidation manager');
    new AaveV4DeployBabylonSpokeHarness(config, false).requireLiquidationManager(config);
  }

  function test_requireLiquidationManager_revertsWith_notCreateXAddress() public {
    AaveV4BabylonConfig.Config memory config = AaveV4BabylonConfig.read('mainnet');
    config.liquidationManagerDeployer = makeAddr('other deployer');
    AaveV4DeployBabylonSpokeHarness harness = new AaveV4DeployBabylonSpokeHarness(config, false);
    vm.expectRevert('liquidation manager is not the createx address');
    harness.requireLiquidationManager(config);
  }

  function test_revert_supply_marketInactive() public {
    _mintVaultBtc(_user, 1e8);
    vm.startPrank(_user);
    IERC20(VAULT_BTC).approve(_spoke(), 1e8);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    ISpoke(_spoke()).supply(VAULT_BTC_RESERVE_ID, 1e8, _user);
    vm.stopPrank();
  }

  function test_aip_supply() public {
    _executeLaunchAip();
    _mintVaultBtc(_user, 1e8);
    vm.startPrank(_user);
    IERC20(VAULT_BTC).approve(_spoke(), 1e8);
    ISpoke(_spoke()).supply(VAULT_BTC_RESERVE_ID, 1e8, _user);
    vm.stopPrank();
    assertEq(ISpoke(_spoke()).getUserSuppliedAssets(VAULT_BTC_RESERVE_ID, _user), 1e8, 'supplied');
    assertEq(
      IHub(_hub()).getSpokeAddedAssets(BABYLON_VAULT_BTC_ASSET_ID, _spoke()),
      1e8,
      'hub added assets'
    );
    assertEq(IERC20(VAULT_BTC).balanceOf(_hub()), 1e8, 'hub balance');
  }

  /// @dev No position manager is active, so nobody supplies on behalf of another account.
  function test_aip_revertsWith_supplyOnBehalfOf() public {
    _executeLaunchAip();
    _mintVaultBtc(_supplier, 1e8);
    vm.startPrank(_supplier);
    IERC20(VAULT_BTC).approve(_spoke(), 1e8);
    vm.expectRevert(ISpoke.Unauthorized.selector);
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
      uint40(500_000),
      uint40(500_000),
      uint40(100_000),
      uint40(250_000),
      uint40(100_000)
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
      uint40(20),
      uint40(5_000_000),
      uint40(5_000_000),
      uint40(1_000_000),
      uint40(100)
    ];
    uint40[5] memory drawCaps = [
      uint40(0),
      uint40(250_000),
      uint40(250_000),
      uint40(100_000),
      uint40(20)
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
    _supplyVaultBtcAsCollateral(20e8);
    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, 500_000));
    vm.prank(_user);
    ISpoke(_spoke()).borrow(CORE_USDC_RESERVE_ID, 500_001e6, _user);
  }

  function test_aip_revertsWith_vaultBtcAddCapExceeded() public {
    _executeLaunchAip();
    _mintVaultBtc(_user, 21e8);
    vm.startPrank(_user);
    IERC20(VAULT_BTC).approve(_spoke(), 21e8);
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, 20));
    ISpoke(_spoke()).supply(VAULT_BTC_RESERVE_ID, 21e8, _user);
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

  /// @dev The RiskSteward governs the Babylon Hub through the shared HubConfigurator once the AIP maps
  /// its selectors.
  function test_aip_riskStewardUpdatesBabylonHubCaps() public {
    _executeLaunchAip();
    IHub.SpokeConfig memory spokeConfig = IHub(_hub()).getSpokeConfig(
      BABYLON_USDC_ASSET_ID,
      _spoke()
    );
    uint40 addCap = spokeConfig.addCap + 1;
    uint40 drawCap = spokeConfig.drawCap - 1;
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: IHubConfigurator(HUB_CONFIGURATOR),
      hub: _hub(),
      underlying: USDC,
      spoke: _spoke(),
      addCap: addCap,
      drawCap: drawCap,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    vm.prank(RISK_COUNCIL);
    IV4RiskSteward(RISK_STEWARD).updateHubSpokeCaps(updates);
    spokeConfig = IHub(_hub()).getSpokeConfig(BABYLON_USDC_ASSET_ID, _spoke());
    assertEq(spokeConfig.addCap, addCap, 'add cap');
    assertEq(spokeConfig.drawCap, drawCap, 'draw cap');
  }

  /// @dev The RiskSteward governs the BabylonSpoke through the shared SpokeConfigurator once the AIP
  /// maps its selectors.
  function test_aip_riskStewardUpdatesBabylonSpokeCollateralFactor() public {
    _executeLaunchAip();
    uint32 dynamicConfigKey = ISpoke(_spoke()).getReserve(VAULT_BTC_RESERVE_ID).dynamicConfigKey;
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(SPOKE_CONFIGURATOR),
      spoke: _spoke(),
      hub: _hub(),
      underlying: VAULT_BTC,
      dynamicConfigKey: dynamicConfigKey,
      // the RiskSteward allows at most 50 BPS per collateral factor update
      collateralFactor: 77_50,
      maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
      liquidationFee: EngineFlags.KEEP_CURRENT
    });
    vm.prank(RISK_COUNCIL);
    IV4RiskSteward(RISK_STEWARD).updateDynamicReserveConfigs(updates);
    assertEq(
      ISpoke(_spoke())
        .getDynamicReserveConfig(VAULT_BTC_RESERVE_ID, dynamicConfigKey)
        .collateralFactor,
      77_50,
      'collateral factor'
    );
  }

  function test_aip_btcVaultSwapRoles() public {
    _executeLaunchAip();
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(ACCESS_MANAGER);
    assertEq(IBTCVaultSwap.setSwapFeeBps.selector, bytes4(0x1891b442), 'fee selector');
    assertEq(
      accessManager.getTargetFunctionRole(BTC_VAULT_SWAP, IBTCVaultSwap.setSwapFeeBps.selector),
      BTC_VAULT_SWAP_FEE_ROLE,
      'fee selector role'
    );
    bytes4[] memory selectors = _btcVaultSwapGuardianSelectors();
    for (uint256 i; i < selectors.length; ++i) {
      assertEq(
        accessManager.getTargetFunctionRole(BTC_VAULT_SWAP, selectors[i]),
        BTC_VAULT_SWAP_GUARDIAN_ROLE,
        'guardian selector role'
      );
    }
    assertEq(accessManager.getRoleTargetSelectorCount(BTC_VAULT_SWAP_FEE_ROLE, BTC_VAULT_SWAP), 1);
    assertEq(
      accessManager.getRoleTargetSelectorCount(BTC_VAULT_SWAP_GUARDIAN_ROLE, BTC_VAULT_SWAP),
      4
    );
    assertEq(accessManager.getRoleTargetCount(BTC_VAULT_SWAP_FEE_ROLE), 1, 'fee role targets');
    assertEq(
      accessManager.getRoleTargetCount(BTC_VAULT_SWAP_GUARDIAN_ROLE),
      1,
      'guardian role targets'
    );

    assertEq(
      accessManager.getLabelOfRole(BTC_VAULT_SWAP_FEE_ROLE),
      'BTC_VAULT_SWAP_FEE_ROLE',
      'fee role label'
    );
    assertEq(
      accessManager.getLabelOfRole(BTC_VAULT_SWAP_GUARDIAN_ROLE),
      'BTC_VAULT_SWAP_GUARDIAN_ROLE',
      'guardian role label'
    );
    assertEq(
      accessManager.getRoleGuardian(BTC_VAULT_SWAP_FEE_ROLE),
      BTC_VAULT_SWAP_GUARDIAN_ROLE,
      'fee role guardian'
    );
    assertEq(
      accessManager.getRoleGuardian(BTC_VAULT_SWAP_GUARDIAN_ROLE),
      0,
      'guardian role guardian'
    );
    uint64[2] memory roles = [BTC_VAULT_SWAP_FEE_ROLE, BTC_VAULT_SWAP_GUARDIAN_ROLE];
    for (uint256 i; i < roles.length; ++i) {
      assertEq(accessManager.getRoleAdmin(roles[i]), Roles.ACCESS_MANAGER_ADMIN_ROLE, 'role admin');
      assertEq(accessManager.getRoleGrantDelay(roles[i]), 0, 'grant delay');
    }

    assertEq(accessManager.getRoleMemberCount(BTC_VAULT_SWAP_FEE_ROLE), 1, 'fee role members');
    (bool isMember, uint32 executionDelay) = accessManager.hasRole(
      BTC_VAULT_SWAP_FEE_ROLE,
      BTC_VAULT_SWAP_MULTISIG
    );
    assertTrue(isMember, 'multisig fee role');
    assertEq(executionDelay, BTC_VAULT_SWAP_FEE_DELAY, 'fee role execution delay');
    assertEq(executionDelay, 432_000, 'five days');

    address[4] memory guardians = _btcVaultSwapGuardians();
    assertEq(
      accessManager.getRoleMemberCount(BTC_VAULT_SWAP_GUARDIAN_ROLE),
      guardians.length,
      'guardian role members'
    );
    for (uint256 i; i < guardians.length; ++i) {
      (isMember, executionDelay) = accessManager.hasRole(
        BTC_VAULT_SWAP_GUARDIAN_ROLE,
        guardians[i]
      );
      assertTrue(isMember, 'guardian role');
      assertEq(executionDelay, 0, 'guardian execution delay');
    }
  }

  function test_aip_btcVaultSwapFeeChange() public {
    _executeLaunchAip();
    IAccessManager accessManager = IAccessManager(ACCESS_MANAGER);
    bytes memory data = abi.encodeCall(IBTCVaultSwap.setSwapFeeBps, (2_50, 60));
    bytes32 operationId = accessManager.hashOperation(
      BTC_VAULT_SWAP_MULTISIG,
      BTC_VAULT_SWAP,
      data
    );

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerNotScheduled.selector, operationId)
    );
    vm.prank(BTC_VAULT_SWAP_MULTISIG);
    IBTCVaultSwap(BTC_VAULT_SWAP).setSwapFeeBps(2_50, 60);

    vm.prank(BTC_VAULT_SWAP_MULTISIG);
    accessManager.schedule(BTC_VAULT_SWAP, data, 0);

    skip(BTC_VAULT_SWAP_FEE_DELAY - 1);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerNotReady.selector, operationId)
    );
    vm.prank(BTC_VAULT_SWAP_MULTISIG);
    IBTCVaultSwap(BTC_VAULT_SWAP).setSwapFeeBps(2_50, 60);

    skip(1);
    vm.prank(BTC_VAULT_SWAP_MULTISIG);
    IBTCVaultSwap(BTC_VAULT_SWAP).setSwapFeeBps(2_50, 60);
    assertEq(IBabylonBTCVaultSwap(BTC_VAULT_SWAP).sellDiscountBps(), 2_50, 'sell discount');
    assertEq(
      IBabylonBTCVaultSwap(BTC_VAULT_SWAP).minimumProfitThresholdBps(),
      60,
      'minimum profit threshold'
    );
  }

  function test_aip_btcVaultSwapFeeChange_cancelledByGuardian() public {
    _executeLaunchAip();
    IAccessManager accessManager = IAccessManager(ACCESS_MANAGER);
    bytes memory data = abi.encodeCall(IBTCVaultSwap.setSwapFeeBps, (2_50, 60));
    bytes32 operationId = accessManager.hashOperation(
      BTC_VAULT_SWAP_MULTISIG,
      BTC_VAULT_SWAP,
      data
    );
    address[4] memory guardians = _btcVaultSwapGuardians();
    for (uint256 i; i < guardians.length; ++i) {
      vm.prank(BTC_VAULT_SWAP_MULTISIG);
      accessManager.schedule(BTC_VAULT_SWAP, data, 0);

      vm.prank(guardians[i]);
      accessManager.cancel(BTC_VAULT_SWAP_MULTISIG, BTC_VAULT_SWAP, data);

      skip(BTC_VAULT_SWAP_FEE_DELAY);
      vm.expectRevert(
        abi.encodeWithSelector(IAccessManager.AccessManagerNotScheduled.selector, operationId)
      );
      vm.prank(BTC_VAULT_SWAP_MULTISIG);
      IBTCVaultSwap(BTC_VAULT_SWAP).setSwapFeeBps(2_50, 60);
    }
    assertEq(IBabylonBTCVaultSwap(BTC_VAULT_SWAP).sellDiscountBps(), 2_00, 'sell discount');
  }

  function test_aip_revertsWith_feeChangeNotFromMultisig() public {
    _executeLaunchAip();
    bytes memory data = abi.encodeCall(IBTCVaultSwap.setSwapFeeBps, (2_50, 60));
    address[5] memory callers = [
      V4_SECURITY_COUNCIL,
      V4_SECURITY_COUNCIL_EXECUTOR,
      EXECUTOR_LVL_1,
      RISK_STEWARD,
      _user
    ];
    for (uint256 i; i < callers.length; ++i) {
      vm.expectRevert(
        abi.encodeWithSelector(
          IAccessManager.AccessManagerUnauthorizedCall.selector,
          callers[i],
          BTC_VAULT_SWAP,
          IBTCVaultSwap.setSwapFeeBps.selector
        )
      );
      vm.prank(callers[i]);
      IAccessManager(ACCESS_MANAGER).schedule(BTC_VAULT_SWAP, data, 0);

      vm.expectRevert(
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, callers[i])
      );
      vm.prank(callers[i]);
      IBTCVaultSwap(BTC_VAULT_SWAP).setSwapFeeBps(2_50, 60);
    }
  }

  function test_aip_btcVaultSwapGuardiansPauseAndFreeze() public {
    _executeLaunchAip();
    IBTCVaultSwap btcVaultSwap = IBTCVaultSwap(BTC_VAULT_SWAP);
    address[4] memory guardians = _btcVaultSwapGuardians();
    for (uint256 i; i < guardians.length; ++i) {
      vm.startPrank(guardians[i]);
      btcVaultSwap.pause();
      assertTrue(btcVaultSwap.isPaused(), 'paused');
      btcVaultSwap.unpause();
      assertFalse(btcVaultSwap.isPaused(), 'unpaused');
      btcVaultSwap.freeze();
      assertTrue(btcVaultSwap.isFrozen(), 'frozen');
      btcVaultSwap.unfreeze();
      assertFalse(btcVaultSwap.isFrozen(), 'unfrozen');
      vm.stopPrank();
    }
  }

  function test_aip_revertsWith_pauseNotFromGuardian() public {
    _executeLaunchAip();
    address[2] memory callers = [RISK_STEWARD, _user];
    for (uint256 i; i < callers.length; ++i) {
      vm.expectRevert(
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, callers[i])
      );
      vm.prank(callers[i]);
      IBTCVaultSwap(BTC_VAULT_SWAP).pause();

      vm.expectRevert(
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, callers[i])
      );
      vm.prank(callers[i]);
      IBTCVaultSwap(BTC_VAULT_SWAP).freeze();
    }
  }

  function test_aip_btcVaultSwapCreditLine() public {
    _executeLaunchAip();
    assertEq(
      abi.encode(IHub(CORE_HUB).getSpokeConfig(CORE_WBTC_ASSET_ID, BTC_VAULT_SWAP)),
      abi.encode(_spokeConfig({addCap: 0, drawCap: 20, active: true})),
      'credit line'
    );

    uint256 balanceBefore = IERC20(WBTC).balanceOf(BTC_VAULT_SWAP);
    vm.prank(BTC_VAULT_SWAP);
    IHub(CORE_HUB).draw(CORE_WBTC_ASSET_ID, 20e8, BTC_VAULT_SWAP);
    assertEq(IERC20(WBTC).balanceOf(BTC_VAULT_SWAP), balanceBefore + 20e8, 'drawn');
  }

  function test_aip_revertsWith_btcVaultSwapDrawCapExceeded() public {
    _executeLaunchAip();
    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, 20));
    vm.prank(BTC_VAULT_SWAP);
    IHub(CORE_HUB).draw(CORE_WBTC_ASSET_ID, 20e8 + 1, BTC_VAULT_SWAP);
  }

  function test_aip_revertsWith_liquidationNotFromAdapter() public {
    _executeLaunchAip();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    IBabylonSpoke(_spoke()).liquidationCall(CORE_USDC_RESERVE_ID, 1, _user, 1);
    vm.expectRevert(IBabylonSpoke.UnsupportedLiquidationCall.selector);
    ISpoke(_spoke()).liquidationCall(VAULT_BTC_RESERVE_ID, CORE_USDC_RESERVE_ID, _user, 1, false);
  }

  /// @dev Babylon's deployed AaveAdapter liquidates a position on the BabylonSpoke. The liquidator
  /// repays the debt, takes the whole vault and pays the adapter fee and the fairness payment in WBTC.
  function test_aip_liquidation() public {
    _executeLaunchAip();
    address proxy = _openAdapterPositionAndDropPrice();
    uint256 debt = ISpoke(_spoke()).getUserTotalDebt(CORE_USDC_RESERVE_ID, proxy);
    _fundLiquidator({usdc: debt * 2, wbtc: 1e8});
    address recipient = IAaveAdapterFlows(AAVE_ADAPTER).applicationRecipient();
    uint256 recipientBefore = IERC20(WBTC).balanceOf(recipient);

    vm.prank(_liquidator);
    (bytes32 vaultId, uint256 seized) = IAaveAdapterFlows(AAVE_ADAPTER).liquidate({
      borrower: _user,
      debtReserveId: CORE_USDC_RESERVE_ID,
      maxDebtToRepay: debt * 2,
      maxExitBtc: type(uint256).max,
      claimerBtcPubKey: bytes32(uint256(7))
    });

    assertEq(vaultId, VAULT_ID, 'vault');
    assertEq(seized, 1e8, 'whole vault seized');
    assertEq(debt * 2 - IERC20(USDC).balanceOf(_liquidator), debt, 'debt repaid by liquidator');
    assertGt(IERC20(WBTC).balanceOf(recipient), recipientBefore, 'adapter fee');
    assertGt(IERC20(WBTC).balanceOf(_user), 0, 'fairness payment');
    assertEq(ISpoke(_spoke()).getUserSuppliedAssets(VAULT_BTC_RESERVE_ID, proxy), 0, 'collateral');
    assertEq(ISpoke(_spoke()).getUserTotalDebt(CORE_USDC_RESERVE_ID, proxy), 0, 'debt');
    assertEq(IERC20(VAULT_BTC).totalSupply(), 0, 'vaultBTC burned');
    assertEq(IHub(CORE_HUB).getSpokeDrawnShares(CORE_USDC_ASSET_ID, _spoke()), 0, 'drawn');
    assertEq(IHub(CORE_HUB).getSpokeDeficitRay(CORE_USDC_ASSET_ID, _spoke()), 0, 'deficit');
  }

  /// @dev BTCVaultSwap pays the liquidator in WBTC drawn from its Core Hub credit line, then an
  /// arbitrageur buys the escrowed vault and the draw is repaid.
  function test_aip_liquidationWithBtcVaultSwap() public {
    _executeLaunchAip();
    uint256 liquidityBefore = IHub(CORE_HUB).getAssetLiquidity(CORE_WBTC_ASSET_ID);
    address proxy = _openAdapterPositionAndDropPrice();
    uint256 debt = ISpoke(_spoke()).getUserTotalDebt(CORE_USDC_RESERVE_ID, proxy);
    _fundLiquidator({usdc: debt * 2, wbtc: 0});

    vm.prank(_liquidator);
    (, , TokenAmount[] memory payouts) = IAaveAdapterFlows(AAVE_ADAPTER).liquidateWithLLP({
      borrower: _user,
      llp: BTC_VAULT_SWAP,
      debtReserveId: CORE_USDC_RESERVE_ID,
      maxDebtToRepay: debt * 2,
      maxExitBtc: type(uint256).max,
      minPayouts: new TokenAmount[](0)
    });

    IAaveOracle oracle = IAaveOracle(ISpoke(_spoke()).ORACLE());
    uint256 vaultValue = (1e8 * oracle.getReservePrice(VAULT_BTC_RESERVE_ID)) /
      oracle.getReservePrice(EXIT_BTC_RESERVE_ID);
    // 2% sell discount
    assertApproxEqAbs(payouts[0].amount, (vaultValue * 98) / 100, 3, 'payout');
    assertEq(
      liquidityBefore - IHub(CORE_HUB).getAssetLiquidity(CORE_WBTC_ASSET_ID),
      payouts[0].amount,
      'core hub liquidity drawn'
    );
    assertEq(ISpoke(_spoke()).getUserTotalDebt(CORE_USDC_RESERVE_ID, proxy), 0, 'debt');
    assertEq(ISpoke(_spoke()).getUserSuppliedAssets(VAULT_BTC_RESERVE_ID, proxy), 0, 'collateral');

    _buyEscrowedVault();
    assertEq(IHub(CORE_HUB).getSpokeDrawnShares(CORE_WBTC_ASSET_ID, BTC_VAULT_SWAP), 0, 'repaid');
    assertEq(IHub(CORE_HUB).getSpokeDeficitRay(CORE_WBTC_ASSET_ID, BTC_VAULT_SWAP), 0, 'deficit');
    assertGe(IHub(CORE_HUB).getAssetLiquidity(CORE_WBTC_ASSET_ID), liquidityBefore, 'restored');
  }

  function test_babylon_vaultBtc() public view {
    assertEq(IVaultBTC(VAULT_BTC).HUB(), _hub(), 'hub');
    assertEq(IVaultBTC(VAULT_BTC).adapter(), AAVE_ADAPTER, 'adapter');
  }

  function test_babylon_aaveAdapter() public view {
    assertEq(IAaveAdapter(AAVE_ADAPTER).BTC_VAULT_CORE_SPOKE(), _spoke(), 'babylon spoke');
    assertEq(IAaveAdapter(AAVE_ADAPTER).EXIT_BTC_RESERVE_ID(), EXIT_BTC_RESERVE_ID, 'exitBTC');
    assertEq(
      IAaveAdapter(AAVE_ADAPTER).VAULT_BTC_RESERVE_ID(),
      VAULT_BTC_RESERVE_ID,
      'vaultBTC reserve id'
    );
    assertEq(IAaveAdapter(AAVE_ADAPTER).BTC_VAULT_HUB(), _hub(), 'babylon hub');
    // 10% of the liquidator's bonus
    assertEq(IAaveAdapter(AAVE_ADAPTER).liquidationFeeBps(), 10_00, 'liquidation fee');
    assertEq(
      IAaveAdapter(AAVE_ADAPTER).VAULT_BTC_ASSET_ID(),
      BABYLON_VAULT_BTC_ASSET_ID,
      'vaultBTC asset id'
    );
  }

  function test_babylon_btcVaultSwap() public view {
    assertEq(_config.btcVaultSwap.swap, BTC_VAULT_SWAP, 'configured swap');
    IBTCVaultSwap btcVaultSwap = IBTCVaultSwap(BTC_VAULT_SWAP);
    assertEq(btcVaultSwap.ADAPTER(), AAVE_ADAPTER, 'adapter');
    assertEq(btcVaultSwap.HUB(), CORE_HUB, 'hub');
    assertEq(IBabylonBTCVaultSwap(BTC_VAULT_SWAP).EXIT_BTC(), WBTC, 'exitBTC');
    assertEq(btcVaultSwap.EXIT_BTC_ASSET_ID(), CORE_WBTC_ASSET_ID, 'exitBTC asset id');
    assertEq(IBabylonBTCVaultSwap(BTC_VAULT_SWAP).sellDiscountBps(), 2_00, 'sell discount');
    assertEq(
      IBabylonBTCVaultSwap(BTC_VAULT_SWAP).minimumProfitThresholdBps(),
      50,
      'minimum profit threshold'
    );
    assertEq(IAccessManaged(BTC_VAULT_SWAP).authority(), ACCESS_MANAGER, 'authority');
    assertEq(_proxyAdminOwner(BTC_VAULT_SWAP), V4_SECURITY_COUNCIL, 'proxy admin owner');
  }

  /// @dev Launch AIP actions in proposal order: the Hub and BabylonSpoke role mappings, the BabylonSpoke
  /// and TokenizationSpoke connections on the Babylon Hub, the Core Hub credit lines, then the
  /// BTCVaultSwap roles and its WBTC credit line. Caps follow the LlamaRisk parameters of 10 Nov 2026.
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
      uint40(20),
      uint40(5_000_000),
      uint40(5_000_000),
      uint40(1_000_000),
      uint40(100)
    ];
    uint40[5] memory babylonDrawCaps = [
      uint40(0),
      uint40(250_000),
      uint40(250_000),
      uint40(100_000),
      uint40(20)
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
      uint40(500_000),
      uint40(500_000),
      uint40(100_000),
      uint40(250_000),
      uint40(100_000)
    ];
    for (uint256 i; i < assetIds.length; ++i) {
      IHubConfigurator(HUB_CONFIGURATOR).addSpoke({
        hub: CORE_HUB,
        spoke: _spoke(),
        assetId: assetIds[i],
        config: _spokeConfig({addCap: 0, drawCap: drawCaps[i], active: true})
      });
    }

    bytes4[] memory feeSelectors = new bytes4[](1);
    feeSelectors[0] = IBTCVaultSwap.setSwapFeeBps.selector;
    accessManager.setTargetFunctionRole(BTC_VAULT_SWAP, feeSelectors, BTC_VAULT_SWAP_FEE_ROLE);
    accessManager.setTargetFunctionRole(
      BTC_VAULT_SWAP,
      _btcVaultSwapGuardianSelectors(),
      BTC_VAULT_SWAP_GUARDIAN_ROLE
    );
    accessManager.labelRole(BTC_VAULT_SWAP_FEE_ROLE, 'BTC_VAULT_SWAP_FEE_ROLE');
    accessManager.labelRole(BTC_VAULT_SWAP_GUARDIAN_ROLE, 'BTC_VAULT_SWAP_GUARDIAN_ROLE');
    accessManager.setRoleGuardian(BTC_VAULT_SWAP_FEE_ROLE, BTC_VAULT_SWAP_GUARDIAN_ROLE);
    accessManager.grantRole(
      BTC_VAULT_SWAP_FEE_ROLE,
      BTC_VAULT_SWAP_MULTISIG,
      BTC_VAULT_SWAP_FEE_DELAY
    );
    address[4] memory guardians = _btcVaultSwapGuardians();
    for (uint256 i; i < guardians.length; ++i) {
      accessManager.grantRole(BTC_VAULT_SWAP_GUARDIAN_ROLE, guardians[i], 0);
    }
    IHubConfigurator(HUB_CONFIGURATOR).addSpoke({
      hub: CORE_HUB,
      spoke: BTC_VAULT_SWAP,
      assetId: CORE_WBTC_ASSET_ID,
      config: _spokeConfig({addCap: 0, drawCap: BTC_VAULT_SWAP_DRAW_CAP, active: true})
    });
    vm.stopPrank();
  }

  function _btcVaultSwapGuardianSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = IBTCVaultSwap.pause.selector;
    selectors[1] = IBTCVaultSwap.unpause.selector;
    selectors[2] = IBTCVaultSwap.freeze.selector;
    selectors[3] = IBTCVaultSwap.unfreeze.selector;
    return selectors;
  }

  function _btcVaultSwapGuardians() internal pure returns (address[4] memory) {
    return
      [BTC_VAULT_SWAP_MULTISIG, V4_SECURITY_COUNCIL, V4_SECURITY_COUNCIL_EXECUTOR, EXECUTOR_LVL_1];
  }

  /// @dev Activates a 1 BTC vault for `_user` through the AaveAdapter, borrows USDC at 75% of its
  /// value and lowers both BTC prices by 6%. No BTC is pegged in on the fork, so the BTCVaultRegistry
  /// reads and redemptions are mocked, and the Chainlink answers are mocked to move the price.
  function _openAdapterPositionAndDropPrice() internal returns (address proxy) {
    IAaveAdapterFlows adapter = IAaveAdapterFlows(AAVE_ADAPTER);
    address registry = adapter.BTC_VAULT_REGISTRY();
    BTCVaultBasicInfo memory info = BTCVaultBasicInfo({
      depositor: _user,
      depositorBtcPubKey: bytes32(uint256(1)),
      amount: 1e8,
      vaultProvider: address(0xBEEF),
      status: 2,
      applicationEntryPoint: AAVE_ADAPTER,
      createdAt: block.number
    });
    vm.mockCall(
      registry,
      abi.encodeCall(IBTCVaultRegistry.getBtcVaultBasicInfo, (VAULT_ID)),
      abi.encode(info)
    );
    vm.mockCall(
      registry,
      abi.encodeWithSelector(IBTCVaultRegistry.redeemVaultForAVK.selector, VAULT_ID),
      ''
    );
    vm.mockCall(
      registry,
      abi.encodeCall(IBTCVaultRegistry.redeemVaultForDepositor, (VAULT_ID)),
      ''
    );
    bytes32[] memory vaultIds = new bytes32[](1);
    vaultIds[0] = VAULT_ID;
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1e8;
    vm.mockCall(
      registry,
      abi.encodeCall(IBTCVaultRegistry.getBTCVaultAmountsBatch, (vaultIds)),
      abi.encode(amounts)
    );
    vm.prank(registry);
    adapter.activateVault(VAULT_ID, info, '');
    // Babylon unfreezes the AaveAdapter once the AIP has executed
    vm.prank(BABYLON_INTERIM_GOVERNANCE);
    adapter.unfreeze();

    IAaveOracle oracle = IAaveOracle(ISpoke(_spoke()).ORACLE());
    uint256 vaultBtcPrice = oracle.getReservePrice(VAULT_BTC_RESERVE_ID);
    uint256 wbtcPrice = oracle.getReservePrice(EXIT_BTC_RESERVE_ID);
    // prices have 8 decimals and USDC has 6
    vm.prank(_user);
    adapter.borrowFromCorePosition(
      CORE_USDC_RESERVE_ID,
      (vaultBtcPrice * 75_00) / 100_00 / 100,
      _user
    );

    vm.mockCall(
      BTC_USD_SVR_FEED,
      abi.encodeWithSignature('latestAnswer()'),
      abi.encode(int256((vaultBtcPrice * 94_00) / 100_00))
    );
    vm.mockCall(
      WBTC_FEED,
      abi.encodeWithSignature('latestAnswer()'),
      abi.encode(int256((wbtcPrice * 94_00) / 100_00))
    );
    proxy = adapter.getPosition(_user).proxyContract;
    assertLt(ISpoke(_spoke()).getUserAccountData(proxy).healthFactor, 1e18, 'liquidatable');
  }

  function _fundLiquidator(uint256 usdc, uint256 wbtc) internal {
    deal(USDC, _liquidator, usdc);
    deal(WBTC, _liquidator, wbtc);
    vm.startPrank(_liquidator);
    IERC20(USDC).approve(AAVE_ADAPTER, type(uint256).max);
    IERC20(WBTC).approve(AAVE_ADAPTER, type(uint256).max);
    vm.stopPrank();
  }

  /// @dev An arbitrageur buys the escrowed vault from BTCVaultSwap. The vault protocol info and the
  /// two Bitcoin keys its redemption reads are mocked.
  function _buyEscrowedVault() internal {
    IAaveAdapterFlows adapter = IAaveAdapterFlows(AAVE_ADAPTER);
    BTCVaultProtocolInfo memory protocolInfo;
    vm.mockCall(
      adapter.BTC_VAULT_REGISTRY(),
      abi.encodeCall(IBTCVaultRegistry.getBtcVaultProtocolInfo, (VAULT_ID)),
      abi.encode(protocolInfo)
    );
    vm.mockCall(
      adapter.APP_REGISTRY(),
      abi.encodeWithSelector(IApplicationRegistry.getVaultKeeperBTCKeyInVersion.selector),
      abi.encode(bytes32(uint256(9)))
    );
    vm.mockCall(
      adapter.APP_REGISTRY(),
      abi.encodeWithSelector(IApplicationRegistry.getOperationBtcKeyAtEpochOrGenesis.selector),
      abi.encode(bytes32(uint256(9)))
    );
    skip(4 days);
    address arbitrageur = makeAddr('arbitrageur');
    deal(WBTC, arbitrageur, 2e8);
    vm.startPrank(arbitrageur);
    IERC20(WBTC).approve(BTC_VAULT_SWAP, type(uint256).max);
    IBTCVaultSwapFlows(BTC_VAULT_SWAP).swapExitBtcForVault(VAULT_ID, type(uint256).max);
    vm.stopPrank();
  }

  function _supplyVaultBtcAsCollateral(uint256 amount) internal {
    _mintVaultBtc(_user, amount);
    vm.startPrank(_user);
    IERC20(VAULT_BTC).approve(_spoke(), amount);
    ISpoke(_spoke()).supply(VAULT_BTC_RESERVE_ID, amount, _user);
    ISpoke(_spoke()).setUsingAsCollateral(VAULT_BTC_RESERVE_ID, true, _user);
    vm.stopPrank();
  }

  /// @dev vaultBTC is minted by the AaveAdapter and moves only to the Hub, the adapter or a
  /// registered position proxy.
  function _mintVaultBtc(address to, uint256 amount) internal {
    vm.startPrank(AAVE_ADAPTER);
    IVaultBTC(VAULT_BTC).addValidProxy(to);
    IVaultBTC(VAULT_BTC).mint(to, amount);
    vm.stopPrank();
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
      underlying: VAULT_BTC,
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
