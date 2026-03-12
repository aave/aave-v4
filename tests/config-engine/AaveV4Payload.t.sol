// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {VmSafe} from 'forge-std/Vm.sol';

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

import {Roles} from 'src/libraries/types/Roles.sol';

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

import {AaveV4PayloadWrapper} from 'tests/mocks/config-engine/AaveV4PayloadWrapper.sol';
import {MockHubConfigurator} from 'tests/mocks/config-engine/MockHubConfigurator.sol';
import {MockSpokeConfigurator} from 'tests/mocks/config-engine/MockSpokeConfigurator.sol';
import {MockAccessManager} from 'tests/mocks/config-engine/MockAccessManager.sol';
import {MockPositionManager} from 'tests/mocks/config-engine/MockPositionManager.sol';
import {MockHub} from 'tests/mocks/config-engine/MockHub.sol';

contract AaveV4PayloadTest is BaseConfigEngineTest {
  AaveV4PayloadWrapper public payload;

  function setUp() public override {
    super.setUp();
    payload = new AaveV4PayloadWrapper(IAaveV4ConfigEngine(address(engine)));
  }

  function test_execute_emptyPayload_noReverts() public {
    payload.execute();
    assertTrue(payload.preExecuteCalled());
    assertTrue(payload.postExecuteCalled());
  }

  function test_execute_hookOrdering() public {
    payload.execute();
    assertTrue(payload.preExecuteCalled());
    assertTrue(payload.postExecuteCalled());
    assertLt(payload.preExecuteOrder(), payload.postExecuteOrder());
  }

  function test_execute_hubAction_delegatesCorrectly() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });
    payload.setHubAssetHalts(halts);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(address(mockHub), ASSET_ID);

    payload.execute();
  }

  function test_execute_spokeAction_delegatesCorrectly() public {
    IAaveV4ConfigEngine.SpokePause[] memory pauses = new IAaveV4ConfigEngine.SpokePause[](1);
    pauses[0] = IAaveV4ConfigEngine.SpokePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE
    });
    payload.setSpokeAllReservesPauses(pauses);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseAllReservesCalled(SPOKE);

    payload.execute();
  }

  function test_execute_accessManagerAction_delegatesCorrectly() public {
    IAaveV4ConfigEngine.RoleMembership[]
      memory memberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    memberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: true,
      executionDelay: 100
    });
    payload.setAccessManagerRoleMemberships(memberships);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.GrantRoleCalled(Roles.HUB_CONFIGURATOR_ROLE, ACCOUNT, 100);

    payload.execute();
  }

  function test_execute_multipleActions_allExecuted() public {
    // Hub action
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });
    payload.setHubAssetHalts(halts);

    // Spoke action
    IAaveV4ConfigEngine.SpokePause[] memory pauses = new IAaveV4ConfigEngine.SpokePause[](1);
    pauses[0] = IAaveV4ConfigEngine.SpokePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE
    });
    payload.setSpokeAllReservesPauses(pauses);

    // Access manager action
    IAaveV4ConfigEngine.RoleMembership[]
      memory memberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    memberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: true,
      executionDelay: 0
    });
    payload.setAccessManagerRoleMemberships(memberships);

    // Expect all 3 events
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(address(mockHub), ASSET_ID);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseAllReservesCalled(SPOKE);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.GrantRoleCalled(Roles.HUB_CONFIGURATOR_ROLE, ACCOUNT, 0);

    payload.execute();
  }

  function test_execute_emptyArraysSkipped() public {
    // Configure only 1 action, all others empty
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });
    payload.setHubAssetHalts(halts);

    // Record all emitted logs
    vm.recordLogs();
    payload.execute();

    // Only the configured action should have emitted an event (plus 2 hook tracking writes).
    // Verify the single HaltAssetCalled event was emitted by the mock.
    VmSafe.Log[] memory logs = vm.getRecordedLogs();
    bytes32 haltTopic = MockHubConfigurator.HaltAssetCalled.selector;
    uint256 haltCount;
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].topics.length > 0 && logs[i].topics[0] == haltTopic) {
        ++haltCount;
      }
    }
    assertEq(haltCount, 1);
  }

  function test_execute_revert_propagatesFromEngine() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });
    payload.setHubAssetHalts(halts);

    mockHubConfigurator.setShouldRevert(IHubConfigurator.haltAsset.selector, true);

    vm.expectRevert(MockHubConfigurator.HaltAssetReverted.selector);
    payload.execute();
  }

  function test_configEngine_immutable() public view {
    assertEq(address(payload.CONFIG_ENGINE()), address(engine));
  }

  function test_execute_hubAssetListings() public {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = _defaultAssetListing();
    payload.setHubAssetListings(listings);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddAssetCalled(
      address(mockHub),
      UNDERLYING,
      FEE_RECEIVER,
      LIQUIDITY_FEE,
      IR_STRATEGY,
      abi.encode(IR_DATA)
    );

    payload.execute();
  }

  function test_execute_hubAssetConfigUpdates_feeOnly() public {
    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING,
      liquidityFee: LIQUIDITY_FEE,
      feeReceiver: FEE_RECEIVER,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    payload.setHubAssetConfigUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeConfigCalled(
      address(mockHub),
      ASSET_ID,
      LIQUIDITY_FEE,
      FEE_RECEIVER
    );

    payload.execute();
  }

  function test_execute_hubAssetConfigUpdates_interestRateOnly() public {
    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING,
      liquidityFee: EngineFlags.KEEP_CURRENT,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: IR_STRATEGY,
      irData: IR_DATA,
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    payload.setHubAssetConfigUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateStrategyCalled(
      address(mockHub),
      ASSET_ID,
      IR_STRATEGY,
      abi.encode(IR_DATA)
    );

    payload.execute();
  }

  function test_execute_hubAssetConfigUpdates_reinvestmentOnly() public {
    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING,
      liquidityFee: EngineFlags.KEEP_CURRENT,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: REINVESTMENT_CONTROLLER
    });
    payload.setHubAssetConfigUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateReinvestmentControllerCalled(
      address(mockHub),
      ASSET_ID,
      REINVESTMENT_CONTROLLER
    );

    payload.execute();
  }

  function test_execute_hubSpokeToAssetsAdditions() public {
    IAaveV4ConfigEngine.SpokeToAssetsAddition[]
      memory additions = new IAaveV4ConfigEngine.SpokeToAssetsAddition[](1);
    IAaveV4ConfigEngine.SpokeAssetConfig[]
      memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](1);
    assets[0] = IAaveV4ConfigEngine.SpokeAssetConfig({
      underlying: UNDERLYING,
      config: IHub.SpokeConfig({
        addCap: 1000,
        drawCap: 500,
        riskPremiumThreshold: 100,
        active: true,
        halted: false
      })
    });
    additions[0] = IAaveV4ConfigEngine.SpokeToAssetsAddition({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: SPOKE,
      assets: assets
    });
    payload.setHubSpokeToAssetsAdditions(additions);

    uint256[] memory assetIds = new uint256[](1);
    assetIds[0] = ASSET_ID;
    IHub.SpokeConfig[] memory expectedConfigs = new IHub.SpokeConfig[](1);
    expectedConfigs[0] = assets[0].config;
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeToAssetsCalled(
      address(mockHub),
      SPOKE,
      assetIds,
      expectedConfigs
    );

    payload.execute();
  }

  function test_execute_hubSpokeConfigUpdates_capsOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING,
      spoke: SPOKE,
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    payload.setHubSpokeConfigUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeCapsCalled(address(mockHub), ASSET_ID, SPOKE, 1000, 500);

    payload.execute();
  }

  function test_execute_hubSpokeConfigUpdates_riskPremiumThresholdOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING,
      spoke: SPOKE,
      addCap: EngineFlags.KEEP_CURRENT,
      drawCap: EngineFlags.KEEP_CURRENT,
      riskPremiumThreshold: 200,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    payload.setHubSpokeConfigUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeRiskPremiumThresholdCalled(
      address(mockHub),
      ASSET_ID,
      SPOKE,
      200
    );

    payload.execute();
  }

  function test_execute_hubSpokeConfigUpdates_statusOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING,
      spoke: SPOKE,
      addCap: EngineFlags.KEEP_CURRENT,
      drawCap: EngineFlags.KEEP_CURRENT,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.ENABLED,
      halted: EngineFlags.DISABLED
    });
    payload.setHubSpokeConfigUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(address(mockHub), ASSET_ID, SPOKE, true);
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(address(mockHub), ASSET_ID, SPOKE, false);

    payload.execute();
  }

  function test_execute_hubAssetDeactivations() public {
    IAaveV4ConfigEngine.AssetDeactivation[]
      memory deactivations = new IAaveV4ConfigEngine.AssetDeactivation[](1);
    deactivations[0] = IAaveV4ConfigEngine.AssetDeactivation({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });
    payload.setHubAssetDeactivations(deactivations);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateAssetCalled(address(mockHub), ASSET_ID);

    payload.execute();
  }

  function test_execute_hubAssetCapsResets() public {
    IAaveV4ConfigEngine.AssetCapsReset[] memory resets = new IAaveV4ConfigEngine.AssetCapsReset[](
      1
    );
    resets[0] = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });
    payload.setHubAssetCapsResets(resets);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetAssetCapsCalled(address(mockHub), ASSET_ID);

    payload.execute();
  }

  function test_execute_hubSpokeHalts() public {
    IAaveV4ConfigEngine.SpokeHalt[] memory halts = new IAaveV4ConfigEngine.SpokeHalt[](1);
    halts[0] = IAaveV4ConfigEngine.SpokeHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: SPOKE
    });
    payload.setHubSpokeHalts(halts);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltSpokeCalled(address(mockHub), SPOKE);

    payload.execute();
  }

  function test_execute_hubSpokeDeactivations() public {
    IAaveV4ConfigEngine.SpokeDeactivation[]
      memory deactivations = new IAaveV4ConfigEngine.SpokeDeactivation[](1);
    deactivations[0] = IAaveV4ConfigEngine.SpokeDeactivation({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: SPOKE
    });
    payload.setHubSpokeDeactivations(deactivations);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateSpokeCalled(address(mockHub), SPOKE);

    payload.execute();
  }

  function test_execute_hubSpokeCapsResets() public {
    IAaveV4ConfigEngine.SpokeCapsReset[] memory resets = new IAaveV4ConfigEngine.SpokeCapsReset[](
      1
    );
    resets[0] = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: SPOKE
    });
    payload.setHubSpokeCapsResets(resets);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetSpokeCapsCalled(address(mockHub), SPOKE);

    payload.execute();
  }

  function test_execute_spokeReserveListings() public {
    IAaveV4ConfigEngine.ReserveListing[] memory listings = new IAaveV4ConfigEngine.ReserveListing[](
      1
    );
    listings[0] = IAaveV4ConfigEngine.ReserveListing({
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
        liquidationFee: 1000
      })
    });
    payload.setSpokeReserveListings(listings);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddReserveCalled(
      SPOKE,
      address(mockHub),
      ASSET_ID,
      PRICE_SOURCE,
      5000,
      false,
      false,
      true,
      true,
      8000,
      10500,
      1000
    );

    payload.execute();
  }

  function test_execute_spokeReserveConfigUpdates() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](1);
    updates[0] = _defaultReserveConfigUpdate();
    payload.setSpokeReserveConfigUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReservePriceSourceCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      PRICE_SOURCE
    );
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      5000
    );
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePausedCalled(address(mockSpokeReader), RESERVE_ID, false);
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateFrozenCalled(address(mockSpokeReader), RESERVE_ID, false);
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateBorrowableCalled(address(mockSpokeReader), RESERVE_ID, true);
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReceiveSharesEnabledCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      true
    );

    payload.execute();
  }

  function test_execute_spokeReserveConfigUpdates_priceSourceOnly() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.ReserveConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: address(mockSpokeReader),
      hub: address(mockHub),
      underlying: UNDERLYING,
      priceSource: PRICE_SOURCE,
      collateralRisk: EngineFlags.KEEP_CURRENT,
      paused: EngineFlags.KEEP_CURRENT,
      frozen: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });
    payload.setSpokeReserveConfigUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReservePriceSourceCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      PRICE_SOURCE
    );

    payload.execute();
  }

  function test_execute_spokeLiquidationConfigUpdates() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](1);
    updates[0] = _defaultLiquidationConfigUpdate();
    payload.setSpokeLiquidationConfigUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationConfigCalled(
      SPOKE,
      uint128(1.05e18),
      uint64(0.95e18),
      uint16(10000)
    );

    payload.execute();
  }

  function test_execute_spokeDynamicReserveConfigAdditions() public {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[]
      memory additions = new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](1);
    additions[0] = IAaveV4ConfigEngine.DynamicReserveConfigAddition({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: address(mockSpokeReader),
      hub: address(mockHub),
      underlying: UNDERLYING,
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 8000,
        maxLiquidationBonus: 10500,
        liquidationFee: 1000
      })
    });
    payload.setSpokeDynamicReserveConfigAdditions(additions);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      8000,
      10500,
      1000
    );

    payload.execute();
  }

  function test_execute_spokeDynamicReserveConfigUpdates() public {
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](1);
    updates[0] = _defaultDynamicReserveConfigUpdate();
    payload.setSpokeDynamicReserveConfigUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      8000,
      10500,
      1000
    );

    payload.execute();
  }

  function test_execute_spokeAllReservesFreezes() public {
    IAaveV4ConfigEngine.SpokeFreeze[] memory freezes = new IAaveV4ConfigEngine.SpokeFreeze[](1);
    freezes[0] = IAaveV4ConfigEngine.SpokeFreeze({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE
    });
    payload.setSpokeAllReservesFreezes(freezes);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeAllReservesCalled(SPOKE);

    payload.execute();
  }

  function test_execute_spokePositionManagerUpdates() public {
    IAaveV4ConfigEngine.PositionManagerUpdate[]
      memory updates = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      positionManager: POSITION_MANAGER,
      active: true
    });
    payload.setSpokePositionManagerUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePositionManagerCalled(SPOKE, POSITION_MANAGER, true);

    payload.execute();
  }

  function test_execute_accessManagerRoleMemberships_revoke() public {
    IAaveV4ConfigEngine.RoleMembership[]
      memory memberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    memberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: false,
      executionDelay: 0
    });
    payload.setAccessManagerRoleMemberships(memberships);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.RevokeRoleCalled(Roles.HUB_CONFIGURATOR_ROLE, ACCOUNT);

    payload.execute();
  }

  function test_execute_accessManagerRoleUpdates() public {
    IAaveV4ConfigEngine.RoleUpdate[] memory updates = new IAaveV4ConfigEngine.RoleUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.RoleUpdate({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      admin: Roles.HUB_CONFIGURATOR_ROLE,
      guardian: Roles.DEFICIT_ELIMINATOR_ROLE,
      grantDelay: 3600,
      label: 'FEE_UPDATER'
    });
    payload.setAccessManagerRoleUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetRoleAdminCalled(
      Roles.HUB_CONFIGURATOR_ROLE,
      Roles.HUB_CONFIGURATOR_ROLE
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetRoleGuardianCalled(
      Roles.HUB_CONFIGURATOR_ROLE,
      Roles.DEFICIT_ELIMINATOR_ROLE
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetGrantDelayCalled(Roles.HUB_CONFIGURATOR_ROLE, 3600);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.LabelRoleCalled(Roles.HUB_CONFIGURATOR_ROLE, 'FEE_UPDATER');

    payload.execute();
  }

  function test_execute_accessManagerTargetFunctionRoleUpdates() public {
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[]
      memory updates = new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](1);
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = bytes4(0xdeadbeef);
    updates[0] = IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
      authority: address(mockAccessManager),
      target: TARGET,
      selectors: selectors,
      roleId: Roles.HUB_CONFIGURATOR_ROLE
    });
    payload.setAccessManagerTargetFunctionRoleUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetTargetFunctionRoleCalled(
      TARGET,
      selectors,
      Roles.HUB_CONFIGURATOR_ROLE
    );

    payload.execute();
  }

  function test_execute_accessManagerTargetAdminDelayUpdates() public {
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[]
      memory updates = new IAaveV4ConfigEngine.TargetAdminDelayUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.TargetAdminDelayUpdate({
      authority: address(mockAccessManager),
      target: TARGET,
      newDelay: 7200
    });
    payload.setAccessManagerTargetAdminDelayUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetTargetAdminDelayCalled(TARGET, 7200);

    payload.execute();
  }

  function test_constructor_revertsOnZeroAddress() public {
    vm.expectRevert(AaveV4Payload.InvalidConfigEngine.selector);
    new AaveV4PayloadWrapper(IAaveV4ConfigEngine(address(0)));
  }

  function test_execute_hubAssetListings_withDecimals() public {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = _defaultAssetListing();
    listings[0].decimals = 18;
    payload.setHubAssetListings(listings);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddAssetWithDecimalsCalled(
      address(mockHub),
      UNDERLYING,
      18,
      FEE_RECEIVER,
      LIQUIDITY_FEE,
      IR_STRATEGY,
      abi.encode(IR_DATA)
    );

    payload.execute();
  }

  function test_execute_hubAssetHalts_multiElement() public {
    address underlying2 = makeAddr('UNDERLYING2');
    MockHub mockHub2 = new MockHub();
    mockHub2.setAssetId(underlying2, ASSET_ID + 1);
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](2);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });
    halts[1] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub2),
      underlying: underlying2
    });
    payload.setHubAssetHalts(halts);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(address(mockHub), ASSET_ID);
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(address(mockHub2), ASSET_ID + 1);

    payload.execute();
  }

  function test_execute_positionManagerSpokeRegistrations() public {
    IAaveV4ConfigEngine.SpokeRegistration[]
      memory regs = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    regs[0] = IAaveV4ConfigEngine.SpokeRegistration({
      positionManager: address(mockPositionManager),
      spoke: SPOKE,
      registered: true
    });
    payload.setPositionManagerSpokeRegistrations(regs);

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManager.RegisterSpokeCalled(SPOKE, true);

    payload.execute();
  }

  function test_execute_positionManagerRescues() public {
    IAaveV4ConfigEngine.Rescue[] memory rescues = new IAaveV4ConfigEngine.Rescue[](1);
    rescues[0] = IAaveV4ConfigEngine.Rescue({
      positionManager: address(mockPositionManager),
      token: TOKEN,
      to: RESCUE_TO,
      tokenAmount: RESCUE_AMOUNT,
      nativeAmount: RESCUE_AMOUNT
    });
    payload.setPositionManagerRescues(rescues);

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManager.RescueTokenCalled(TOKEN, RESCUE_TO, RESCUE_AMOUNT);
    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManager.RescueNativeCalled(RESCUE_TO, RESCUE_AMOUNT);

    payload.execute();
  }

  function test_execute_positionManagerRoleRenouncements() public {
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[]
      memory renouncements = new IAaveV4ConfigEngine.PositionManagerRoleRenouncement[](1);
    renouncements[0] = IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
      positionManager: address(mockPositionManager),
      spoke: SPOKE,
      user: USER
    });
    payload.setPositionManagerRoleRenouncements(renouncements);

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManager.RenouncePositionManagerRoleCalled(SPOKE, USER);

    payload.execute();
  }
}
