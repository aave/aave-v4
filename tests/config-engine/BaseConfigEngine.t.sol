// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

import {MockHubConfigurator} from 'tests/mocks/config-engine/MockHubConfigurator.sol';
import {MockSpokeConfigurator} from 'tests/mocks/config-engine/MockSpokeConfigurator.sol';
import {MockAccessManager} from 'tests/mocks/config-engine/MockAccessManager.sol';
import {MockSpokeReader} from 'tests/mocks/config-engine/MockSpokeReader.sol';
import {MockPositionManager} from 'tests/mocks/config-engine/MockPositionManager.sol';
import {MockHub} from 'tests/mocks/config-engine/MockHub.sol';
import {MockInterestRateStrategy} from 'tests/mocks/config-engine/MockInterestRateStrategy.sol';

abstract contract BaseConfigEngineTest is Test {
  uint256 constant ASSET_ID = 1;
  uint256 constant RESERVE_ID = 2;
  uint256 constant LIQUIDITY_FEE = 500;
  uint256 constant DYNAMIC_CONFIG_KEY = 3;
  uint256 constant RESCUE_AMOUNT = 1000e18;

  IAssetInterestRateStrategy.InterestRateData internal IR_DATA =
    IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 8000,
      baseDrawnRate: 100,
      rateGrowthBeforeOptimal: 400,
      rateGrowthAfterOptimal: 6000
    });

  address internal SPOKE = makeAddr('SPOKE');
  address internal UNDERLYING = makeAddr('UNDERLYING');
  address internal FEE_RECEIVER = makeAddr('FEE_RECEIVER');
  address internal IR_STRATEGY = makeAddr('IR_STRATEGY');
  address internal PRICE_SOURCE = makeAddr('PRICE_SOURCE');
  address internal ACCOUNT = makeAddr('ACCOUNT');
  address internal TARGET = makeAddr('TARGET');
  address internal POSITION_MANAGER = makeAddr('POSITION_MANAGER');
  address internal REINVESTMENT_CONTROLLER = makeAddr('REINVESTMENT_CONTROLLER');
  address internal TOKEN = makeAddr('TOKEN');
  address internal RESCUE_TO = makeAddr('RESCUE_TO');
  address internal USER = makeAddr('USER');

  AaveV4ConfigEngine public engine;
  MockHubConfigurator public mockHubConfigurator;
  MockSpokeConfigurator public mockSpokeConfigurator;
  MockAccessManager public mockAccessManager;
  MockSpokeReader public mockSpokeReader;
  MockPositionManager public mockPositionManager;
  MockHub public mockHub;
  MockInterestRateStrategy public mockIrStrategy;

  function setUp() public virtual {
    engine = new AaveV4ConfigEngine();
    mockHubConfigurator = new MockHubConfigurator();
    mockSpokeConfigurator = new MockSpokeConfigurator();
    mockAccessManager = new MockAccessManager();
    mockSpokeReader = new MockSpokeReader();
    mockPositionManager = new MockPositionManager();
    mockHub = new MockHub();
    mockIrStrategy = new MockInterestRateStrategy();

    // Set up default underlying → assetId mapping
    mockHub.setAssetId(UNDERLYING, ASSET_ID);
    // Set up default asset config with IR strategy
    mockHub.setAssetConfig(
      ASSET_ID,
      IHub.AssetConfig({
        feeReceiver: FEE_RECEIVER,
        liquidityFee: uint16(LIQUIDITY_FEE),
        irStrategy: address(mockIrStrategy),
        reinvestmentController: REINVESTMENT_CONTROLLER
      })
    );
    // Set up default reserve ID mapping
    mockSpokeReader.setReserveId(address(mockHub), ASSET_ID, RESERVE_ID);
  }

  /// Default AssetListing (decimals=0 -> addAsset branch)
  function _defaultAssetListing() internal view returns (IAaveV4ConfigEngine.AssetListing memory) {
    return
      IAaveV4ConfigEngine.AssetListing({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        underlying: UNDERLYING,
        decimals: 0,
        feeReceiver: FEE_RECEIVER,
        liquidityFee: LIQUIDITY_FEE,
        irStrategy: IR_STRATEGY,
        irData: IR_DATA
      });
  }

  /// Default AssetConfigUpdate (all fields set)
  function _defaultAssetConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.AssetConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.AssetConfigUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        underlying: UNDERLYING,
        liquidityFee: LIQUIDITY_FEE,
        feeReceiver: FEE_RECEIVER,
        irStrategy: IR_STRATEGY,
        irData: IR_DATA,
        reinvestmentController: REINVESTMENT_CONTROLLER
      });
  }

  /// Default SpokeConfigUpdate (all fields set)
  function _defaultSpokeConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.SpokeConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.SpokeConfigUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        underlying: UNDERLYING,
        spoke: SPOKE,
        addCap: 1000,
        drawCap: 500,
        riskPremiumThreshold: 100,
        active: EngineFlags.ENABLED,
        halted: EngineFlags.DISABLED
      });
  }

  /// Default ReserveConfigUpdate (all fields set)
  function _defaultReserveConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        priceSource: PRICE_SOURCE,
        collateralRisk: 5000,
        paused: EngineFlags.DISABLED,
        frozen: EngineFlags.DISABLED,
        borrowable: EngineFlags.ENABLED,
        receiveSharesEnabled: EngineFlags.ENABLED
      });
  }

  /// Default LiquidationConfigUpdate (all fields set)
  function _defaultLiquidationConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: 10000
      });
  }

  /// Default DynamicReserveConfigUpdate (all fields set)
  function _defaultDynamicReserveConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: 8000,
        maxLiquidationBonus: 10500,
        liquidationFee: 1000
      });
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

  function _toSpokeHaltArray(
    IAaveV4ConfigEngine.SpokeHalt memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeHalt[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeHalt[](1);
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

  function _toSpokePauseArray(
    IAaveV4ConfigEngine.SpokePause memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokePause[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokePause[](1);
    arr[0] = item;
  }

  function _toSpokeFreezeArray(
    IAaveV4ConfigEngine.SpokeFreeze memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeFreeze[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeFreeze[](1);
    arr[0] = item;
  }

  function _toPositionManagerUpdateArray(
    IAaveV4ConfigEngine.PositionManagerUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    arr[0] = item;
  }

  function _defaultReserveListing()
    internal
    view
    returns (IAaveV4ConfigEngine.ReserveListing memory)
  {
    return
      IAaveV4ConfigEngine.ReserveListing({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        hub: address(mockHub),
        underlying: UNDERLYING,
        priceSource: PRICE_SOURCE,
        config: ISpoke.ReserveConfig({
          collateralRisk: 5000,
          paused: false,
          frozen: false,
          borrowable: true,
          receiveSharesEnabled: true
        }),
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: 8000,
          maxLiquidationBonus: 10500,
          liquidationFee: 200
        })
      });
  }

  function _defaultDynamicReserveConfigAddition()
    internal
    view
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition memory)
  {
    return
      IAaveV4ConfigEngine.DynamicReserveConfigAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: 8000,
          maxLiquidationBonus: 10500,
          liquidationFee: 200
        })
      });
  }

  function _defaultSpokePause() internal view returns (IAaveV4ConfigEngine.SpokePause memory) {
    return
      IAaveV4ConfigEngine.SpokePause({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE
      });
  }

  function _defaultSpokeFreeze() internal view returns (IAaveV4ConfigEngine.SpokeFreeze memory) {
    return
      IAaveV4ConfigEngine.SpokeFreeze({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE
      });
  }

  function _defaultPositionManagerUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.PositionManagerUpdate memory)
  {
    return
      IAaveV4ConfigEngine.PositionManagerUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        positionManager: POSITION_MANAGER,
        active: true
      });
  }

  function _toSpokeRegistrationArray(
    IAaveV4ConfigEngine.SpokeRegistration memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeRegistration[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    arr[0] = item;
  }

  function _toRescueArray(
    IAaveV4ConfigEngine.Rescue memory item
  ) internal pure returns (IAaveV4ConfigEngine.Rescue[] memory arr) {
    arr = new IAaveV4ConfigEngine.Rescue[](1);
    arr[0] = item;
  }

  function _toPositionManagerRoleRenouncementArray(
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement memory item
  ) internal pure returns (IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] memory arr) {
    arr = new IAaveV4ConfigEngine.PositionManagerRoleRenouncement[](1);
    arr[0] = item;
  }

  function _setupDynamicReserveConfig(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) internal {
    mockSpokeReader.setDynamicReserveConfig(
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      ISpoke.DynamicReserveConfig({
        collateralFactor: collateralFactor,
        maxLiquidationBonus: maxLiquidationBonus,
        liquidationFee: liquidationFee
      })
    );
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
