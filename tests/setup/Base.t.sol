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
import {Roles} from 'src/libraries/types/Roles.sol';
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

// helpers
import {HubActions} from 'tests/helpers/hub/HubActions.sol';
import {SpokeActions} from 'tests/helpers/spoke/SpokeActions.sol';
import {DeployUtils} from 'tests/helpers/deploy/DeployUtils.sol';
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
import {IHubInstance} from 'tests/helpers/mocks/IHubInstance.sol';
import {ISpokeInstance} from 'tests/helpers/mocks/ISpokeInstance.sol';
import {DeployWrapper} from 'tests/helpers/mocks/DeployWrapper.sol';
import {SpokeUtilsWrapper} from 'tests/helpers/mocks/SpokeUtilsWrapper.sol';

abstract contract Base is BaseHelpers {
  using stdStorage for StdStorage;
  using WadRayMath for *;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;
  using MathUtils for uint256;
  using ReserveFlagsMap for ReserveFlags;

  function setUp() public virtual {
    deployFixtures();
    initEnvironment();
  }

  function deployFixtures() internal virtual {
    vm.startPrank(ADMIN);
    accessManager = IAccessManager(address(new AccessManagerEnumerable(ADMIN)));
    hub1 = DeployUtils.deployHub({authority: address(accessManager), proxyAdminOwner: ADMIN});
    irStrategy = new AssetInterestRateStrategy(address(hub1));
    (spoke1, oracle1) = _deploySpokeWithOracle(ADMIN, address(accessManager));
    (spoke2, oracle2) = _deploySpokeWithOracle(ADMIN, address(accessManager));
    (spoke3, oracle3) = _deploySpokeWithOracle(ADMIN, address(accessManager));
    TreasurySpokeInstance treasurySpokeImpl = new TreasurySpokeInstance();
    treasurySpoke = ITreasurySpoke(
      DeployUtils.proxify(
        address(treasurySpokeImpl),
        ADMIN,
        abi.encodeCall(TreasurySpokeInstance.initialize, (TREASURY_ADMIN))
      )
    );
    vm.stopPrank();

    vm.label(address(spoke1), 'spoke1');
    vm.label(address(spoke2), 'spoke2');
    vm.label(address(spoke3), 'spoke3');

    setUpRoles(hub1, spoke1, accessManager);
    setUpRoles(hub1, spoke2, accessManager);
    setUpRoles(hub1, spoke3, accessManager);
  }

  function setUpRoles(IHub hub, ISpoke spoke, IAccessManager manager) internal virtual {
    vm.startPrank(ADMIN);
    // Grant roles with 0 delay
    manager.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    manager.grantRole(Roles.HUB_ADMIN_ROLE, HUB_ADMIN, 0);

    manager.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);
    manager.grantRole(Roles.SPOKE_ADMIN_ROLE, SPOKE_ADMIN, 0);

    manager.grantRole(Roles.USER_POSITION_UPDATER_ROLE, SPOKE_ADMIN, 0);
    manager.grantRole(Roles.USER_POSITION_UPDATER_ROLE, USER_POSITION_UPDATER, 0);

    manager.grantRole(Roles.HUB_CONFIGURATOR_ROLE, HUB_CONFIGURATOR, 0);
    manager.grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, SPOKE_CONFIGURATOR, 0);

    manager.grantRole(Roles.DEFICIT_ELIMINATOR_ROLE, HUB_ADMIN, 0);
    manager.grantRole(Roles.DEFICIT_ELIMINATOR_ROLE, DEFICIT_ELIMINATOR, 0);

    // Grant responsibilities to roles
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
      manager.setTargetFunctionRole(address(hub), selectors, Roles.HUB_ADMIN_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](1);
      selectors[0] = IHub.eliminateDeficit.selector;
      manager.setTargetFunctionRole(address(hub), selectors, Roles.DEFICIT_ELIMINATOR_ROLE);
    }

    setUpHubConfiguratorRoles(HUB_CONFIGURATOR, address(manager));
    setUpSpokeConfiguratorRoles(SPOKE_CONFIGURATOR, address(manager));

    vm.stopPrank();
  }

  function setUpHubConfiguratorRoles(address hubConfigurator, address manager) internal {
    vm.startPrank(ADMIN);

    // Grant HUB_ADMIN_ROLE so the configurator can call hub functions
    IAccessManager(manager).grantRole(Roles.HUB_ADMIN_ROLE, hubConfigurator, 0);

    // Set up HubConfigurator function permissions - all functions callable by HUB_CONFIGURATOR_ROLE
    bytes4[] memory selectors = new bytes4[](22);
    selectors[0] = IHubConfigurator.updateLiquidityFee.selector;
    selectors[1] = IHubConfigurator.updateFeeReceiver.selector;
    selectors[2] = IHubConfigurator.updateFeeConfig.selector;
    selectors[3] = IHubConfigurator.updateInterestRateStrategy.selector;
    selectors[4] = IHubConfigurator.updateReinvestmentController.selector;
    selectors[5] = IHubConfigurator.resetAssetCaps.selector;
    selectors[6] = IHubConfigurator.deactivateAsset.selector;
    selectors[7] = IHubConfigurator.haltAsset.selector;
    selectors[8] = IHubConfigurator.addSpoke.selector;
    selectors[9] = IHubConfigurator.addSpokeToAssets.selector;
    selectors[10] = IHubConfigurator.updateSpokeActive.selector;
    selectors[11] = IHubConfigurator.updateSpokeHalted.selector;
    selectors[12] = IHubConfigurator.updateSpokeAddCap.selector;
    selectors[13] = IHubConfigurator.updateSpokeDrawCap.selector;
    selectors[14] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    selectors[15] = IHubConfigurator.updateSpokeCaps.selector;
    selectors[16] = IHubConfigurator.deactivateSpoke.selector;
    selectors[17] = IHubConfigurator.haltSpoke.selector;
    selectors[18] = IHubConfigurator.resetSpokeCaps.selector;
    selectors[19] = IHubConfigurator.updateInterestRateData.selector;
    selectors[20] = IHubConfigurator.addAsset.selector;
    selectors[21] = IHubConfigurator.addAssetWithDecimals.selector;
    IAccessManager(manager).setTargetFunctionRole(
      hubConfigurator,
      selectors,
      Roles.HUB_CONFIGURATOR_ROLE
    );

    vm.stopPrank();
  }

  function setUpSpokeConfiguratorRoles(address spokeConfigurator, address manager) internal {
    vm.startPrank(ADMIN);

    // Grant SPOKE_ADMIN_ROLE so the configurator can call spoke functions
    IAccessManager(manager).grantRole(Roles.SPOKE_ADMIN_ROLE, spokeConfigurator, 0);

    // Set up SpokeConfigurator function permissions - all functions callable by SPOKE_CONFIGURATOR_ROLE
    bytes4[] memory selectors = new bytes4[](24);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectors[1] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[2] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[3] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[4] = ISpokeConfigurator.updateLiquidationConfig.selector;
    selectors[5] = ISpokeConfigurator.addReserve.selector;
    selectors[6] = ISpokeConfigurator.updatePaused.selector;
    selectors[7] = ISpokeConfigurator.updateFrozen.selector;
    selectors[8] = ISpokeConfigurator.updateBorrowable.selector;
    selectors[9] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectors[10] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[11] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[12] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[13] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[14] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[15] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[16] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectors[17] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[18] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    selectors[19] = ISpokeConfigurator.pauseAllReserves.selector;
    selectors[20] = ISpokeConfigurator.freezeAllReserves.selector;
    selectors[21] = ISpokeConfigurator.pauseReserve.selector;
    selectors[22] = ISpokeConfigurator.freezeReserve.selector;
    selectors[23] = ISpokeConfigurator.updatePositionManager.selector;
    IAccessManager(manager).setTargetFunctionRole(
      spokeConfigurator,
      selectors,
      Roles.SPOKE_CONFIGURATOR_ROLE
    );

    vm.stopPrank();
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
      new TestnetERC20('WBTC', 'WBTC', 8),
      new TestnetERC20('USDY', 'USDY', 18),
      new TestnetERC20('USDZ', 'USDZ', 18)
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
    MAX_SUPPLY_AMOUNT_USDZ = MAX_SUPPLY_ASSET_UNITS * 10 ** tokenList.usdz.decimals();

    address[7] memory users = [
      alice,
      bob,
      carol,
      derl,
      LIQUIDATOR,
      TREASURY_ADMIN,
      POSITION_MANAGER
    ];

    address[4] memory spokes = [
      address(spoke1),
      address(spoke2),
      address(spoke3),
      address(treasurySpoke)
    ];

    for (uint256 x; x < users.length; ++x) {
      tokenList.usdx.mint(users[x], MAX_SUPPLY_AMOUNT);
      tokenList.dai.mint(users[x], MAX_SUPPLY_AMOUNT);
      tokenList.wbtc.mint(users[x], MAX_SUPPLY_AMOUNT);
      tokenList.usdy.mint(users[x], MAX_SUPPLY_AMOUNT);
      tokenList.usdz.mint(users[x], MAX_SUPPLY_AMOUNT);
      deal(address(tokenList.weth), users[x], MAX_SUPPLY_AMOUNT);

      vm.startPrank(users[x]);
      for (uint256 y; y < spokes.length; ++y) {
        tokenList.weth.approve(spokes[y], UINT256_MAX);
        tokenList.usdx.approve(spokes[y], UINT256_MAX);
        tokenList.dai.approve(spokes[y], UINT256_MAX);
        tokenList.wbtc.approve(spokes[y], UINT256_MAX);
        tokenList.usdy.approve(spokes[y], UINT256_MAX);
        tokenList.usdz.approve(spokes[y], UINT256_MAX);
      }
      vm.stopPrank();
    }
  }

  function configureTokenList() internal {
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
    });

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseDrawnRate: 5_00, // 5.00%
        rateGrowthBeforeOptimal: 5_00, // 5.00%
        rateGrowthAfterOptimal: 5_00 // 5.00%
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
    // add USDX
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
    // add DAI
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
    // add WBTC
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
    // add USDY
    hub1.addAsset(
      address(tokenList.usdy),
      tokenList.usdy.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      usdyAssetId,
      IHub.AssetConfig({
        liquidityFee: 10_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    // add USDZ
    hub1.addAsset(
      address(tokenList.usdz),
      tokenList.usdz.decimals(),
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      hub1.getAssetCount() - 1,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );

    // Liquidation configs
    spoke1.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.7e18,
        liquidationBonusFactor: 20_00
      })
    );
    spoke2.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.04e18,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 15_00
      })
    );
    spoke3.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.03e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 10_00
      })
    );

    // Spoke 1 reserve configs
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
    spokeInfo[spoke1].usdy.reserveConfig = _getDefaultReserveConfig(50_00);
    spokeInfo[spoke1].usdy.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 101_50,
      liquidationFee: 15_00
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
    spokeInfo[spoke2].wbtc.reserveConfig = _getDefaultReserveConfig(0);
    spokeInfo[spoke2].wbtc.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 105_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke2].weth.reserveConfig = _getDefaultReserveConfig(10_00);
    spokeInfo[spoke2].weth.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 76_00,
      maxLiquidationBonus: 103_00,
      liquidationFee: 15_00
    });
    spokeInfo[spoke2].dai.reserveConfig = _getDefaultReserveConfig(20_00);
    spokeInfo[spoke2].dai.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 72_00,
      maxLiquidationBonus: 102_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke2].usdx.reserveConfig = _getDefaultReserveConfig(50_00);
    spokeInfo[spoke2].usdx.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 72_00,
      maxLiquidationBonus: 101_00,
      liquidationFee: 12_00
    });
    spokeInfo[spoke2].usdy.reserveConfig = _getDefaultReserveConfig(50_00);
    spokeInfo[spoke2].usdy.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 72_00,
      maxLiquidationBonus: 101_50,
      liquidationFee: 15_00
    });
    spokeInfo[spoke2].usdz.reserveConfig = _getDefaultReserveConfig(100_00);
    spokeInfo[spoke2].usdz.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 70_00,
      maxLiquidationBonus: 106_00,
      liquidationFee: 10_00
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
    spokeInfo[spoke2].usdz.reserveId = spoke2.addReserve(
      address(hub1),
      usdzAssetId,
      _deployMockPriceFeed(spoke2, 1e8),
      spokeInfo[spoke2].usdz.reserveConfig,
      spokeInfo[spoke2].usdz.dynReserveConfig
    );

    hub1.addSpoke(wbtcAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(wethAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(daiAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(usdyAssetId, address(spoke2), spokeConfig);
    hub1.addSpoke(usdzAssetId, address(spoke2), spokeConfig);

    // Spoke 3 reserve configs
    spokeInfo[spoke3].dai.reserveConfig = _getDefaultReserveConfig(0);
    spokeInfo[spoke3].dai.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 75_00,
      maxLiquidationBonus: 104_00,
      liquidationFee: 11_00
    });
    spokeInfo[spoke3].usdx.reserveConfig = _getDefaultReserveConfig(10_00);
    spokeInfo[spoke3].usdx.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 75_00,
      maxLiquidationBonus: 103_00,
      liquidationFee: 15_00
    });
    spokeInfo[spoke3].weth.reserveConfig = _getDefaultReserveConfig(20_00);
    spokeInfo[spoke3].weth.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 79_00,
      maxLiquidationBonus: 102_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke3].wbtc.reserveConfig = _getDefaultReserveConfig(50_00);
    spokeInfo[spoke3].wbtc.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 77_00,
      maxLiquidationBonus: 101_00,
      liquidationFee: 12_00
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
    IAccessManager accessManager2 = IAccessManager(address(new AccessManagerEnumerable(ADMIN)));
    IHub hub2 = DeployUtils.deployHub({authority: address(accessManager2), proxyAdminOwner: ADMIN});
    vm.label(address(hub2), 'Hub2');
    AssetInterestRateStrategy hub2IrStrategy = new AssetInterestRateStrategy(address(hub2));

    // Configure IR Strategy for hub 2
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseDrawnRate: 5_00, // 5.00%
        rateGrowthBeforeOptimal: 5_00, // 5.00%
        rateGrowthAfterOptimal: 5_00 // 5.00%
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
    IAccessManager accessManager3 = IAccessManager(address(new AccessManagerEnumerable(ADMIN)));
    IHub hub3 = DeployUtils.deployHub({authority: address(accessManager3), proxyAdminOwner: ADMIN});
    AssetInterestRateStrategy hub3IrStrategy = new AssetInterestRateStrategy(address(hub3));

    // Configure IR Strategy for hub 3
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseDrawnRate: 5_00, // 5.00%
        rateGrowthBeforeOptimal: 5_00, // 5.00%
        rateGrowthAfterOptimal: 5_00 // 5.00%
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
