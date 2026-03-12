// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

import {MockHubConfigurator} from 'tests/mocks/config-engine/MockHubConfigurator.sol';

contract HubEngineTest is BaseConfigEngineTest {
  function test_executeHubAssetListings_decimalsZero() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddAssetCalled(
      address(mockHub),
      UNDERLYING,
      FEE_RECEIVER,
      LIQUIDITY_FEE,
      IR_STRATEGY,
      abi.encode(IR_DATA)
    );

    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_decimalsNonZero() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.decimals = 18;

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

    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function testFuzz_executeHubAssetListings(uint256 decimals) public {
    decimals = bound(decimals, 0, 255);
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.decimals = decimals;

    if (decimals == 0) {
      vm.expectEmit(address(mockHubConfigurator));
      emit MockHubConfigurator.AddAssetCalled(
        address(mockHub),
        UNDERLYING,
        FEE_RECEIVER,
        LIQUIDITY_FEE,
        IR_STRATEGY,
        abi.encode(IR_DATA)
      );
    } else {
      vm.expectEmit(address(mockHubConfigurator));
      emit MockHubConfigurator.AddAssetWithDecimalsCalled(
        address(mockHub),
        UNDERLYING,
        uint8(decimals),
        FEE_RECEIVER,
        LIQUIDITY_FEE,
        IR_STRATEGY,
        abi.encode(IR_DATA)
      );
    }

    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.addAsset.selector, true);

    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();

    vm.expectRevert(MockHubConfigurator.AddAssetReverted.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_revertWithDecimals() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.addAssetWithDecimals.selector, true);

    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.decimals = 18;

    vm.expectRevert(MockHubConfigurator.AddAssetWithDecimalsReverted.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetConfigUpdates_feeBoth() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    // Skip IR and reinvestment
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeConfigCalled(
      address(mockHub),
      ASSET_ID,
      LIQUIDITY_FEE,
      FEE_RECEIVER
    );

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_feeOnly() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    // Skip IR and reinvestment
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateLiquidityFeeCalled(address(mockHub), ASSET_ID, LIQUIDITY_FEE);

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_receiverOnly() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    // Skip IR and reinvestment
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeReceiverCalled(address(mockHub), ASSET_ID, FEE_RECEIVER);

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_feeNeither() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    // Skip IR and reinvestment
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    // No event expected; should be a no-op
    vm.recordLogs();
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeHubAssetConfigUpdates_fee(uint256 fee, address receiver) public {
    vm.assume(fee != EngineFlags.KEEP_CURRENT);
    vm.assume(receiver != EngineFlags.KEEP_CURRENT_ADDRESS);
    vm.assume(receiver != address(0));

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = fee;
    update.feeReceiver = receiver;
    // Skip IR and reinvestment
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeConfigCalled(address(mockHub), ASSET_ID, fee, receiver);

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_feeRevert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.updateFeeConfig.selector, true);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    // Skip IR and reinvestment
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectRevert(MockHubConfigurator.UpdateFeeConfigReverted.selector);
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_strategyChange() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    // Skip fee and reinvestment
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateStrategyCalled(
      address(mockHub),
      ASSET_ID,
      IR_STRATEGY,
      abi.encode(IR_DATA)
    );

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_irDataOnly() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    // irData has non-sentinel values from default
    // Skip fee and reinvestment
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateDataCalled(
      address(mockHub),
      ASSET_ID,
      abi.encode(IR_DATA)
    );

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_irNoOp() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    // Skip fee and reinvestment
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    // No event expected; should be a no-op
    vm.recordLogs();
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeHubAssetConfigUpdates_ir(address strategy) public {
    vm.assume(strategy != EngineFlags.KEEP_CURRENT_ADDRESS);
    vm.assume(strategy != address(0));

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.irStrategy = strategy;
    // Skip fee and reinvestment
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateStrategyCalled(
      address(mockHub),
      ASSET_ID,
      strategy,
      abi.encode(IR_DATA)
    );

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_irRevert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.updateInterestRateStrategy.selector, true);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    // Skip fee and reinvestment
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectRevert(MockHubConfigurator.UpdateInterestRateStrategyReverted.selector);
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_reinvestmentController() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    // Skip fee and IR
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateReinvestmentControllerCalled(
      address(mockHub),
      ASSET_ID,
      REINVESTMENT_CONTROLLER
    );

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function testFuzz_executeHubAssetConfigUpdates_reinvestmentController(address controller) public {
    vm.assume(controller != address(0));
    vm.assume(controller != EngineFlags.KEEP_CURRENT_ADDRESS);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.reinvestmentController = controller;
    // Skip fee and IR
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateReinvestmentControllerCalled(
      address(mockHub),
      ASSET_ID,
      controller
    );

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_reinvestmentControllerRevert() public {
    mockHubConfigurator.setShouldRevert(
      IHubConfigurator.updateReinvestmentController.selector,
      true
    );

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    // Skip fee and IR
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();

    vm.expectRevert(MockHubConfigurator.UpdateReinvestmentControllerReverted.selector);
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_allFields() public {
    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();

    // Expect fee config
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeConfigCalled(
      address(mockHub),
      ASSET_ID,
      LIQUIDITY_FEE,
      FEE_RECEIVER
    );

    // Expect IR strategy update
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateStrategyCalled(
      address(mockHub),
      ASSET_ID,
      IR_STRATEGY,
      abi.encode(IR_DATA)
    );

    // Expect reinvestment controller update
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateReinvestmentControllerCalled(
      address(mockHub),
      ASSET_ID,
      REINVESTMENT_CONTROLLER
    );

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_capsBoth() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    // Skip riskPremiumThreshold and status
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeCapsCalled(address(mockHub), ASSET_ID, SPOKE, 1000, 500);

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_addCapOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.drawCap = EngineFlags.KEEP_CURRENT;
    // Skip riskPremiumThreshold and status
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeAddCapCalled(address(mockHub), ASSET_ID, SPOKE, 1000);

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_drawCapOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = EngineFlags.KEEP_CURRENT;
    // Skip riskPremiumThreshold and status
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeDrawCapCalled(address(mockHub), ASSET_ID, SPOKE, 500);

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_capsNeither() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    // Skip riskPremiumThreshold and status
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.recordLogs();
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeHubSpokeConfigUpdates_caps(uint256 addCap, uint256 drawCap) public {
    vm.assume(addCap != EngineFlags.KEEP_CURRENT);
    vm.assume(drawCap != EngineFlags.KEEP_CURRENT);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = addCap;
    update.drawCap = drawCap;
    // Skip riskPremiumThreshold and status
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeCapsCalled(
      address(mockHub),
      ASSET_ID,
      SPOKE,
      addCap,
      drawCap
    );

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_capsRevert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.updateSpokeCaps.selector, true);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    // Skip riskPremiumThreshold and status
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectRevert(MockHubConfigurator.UpdateSpokeCapsReverted.selector);
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_statusBoth() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    // active=ENABLED, halted=DISABLED from default
    // Skip caps and riskPremiumThreshold
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(address(mockHub), ASSET_ID, SPOKE, true);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(address(mockHub), ASSET_ID, SPOKE, false);

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_activeOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.halted = EngineFlags.KEEP_CURRENT;
    // Skip caps and riskPremiumThreshold
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(address(mockHub), ASSET_ID, SPOKE, true);

    vm.recordLogs();
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    // Only one event should have been emitted (UpdateSpokeActiveCalled)
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeHubSpokeConfigUpdates_haltedOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.ENABLED;
    // Skip caps and riskPremiumThreshold
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(address(mockHub), ASSET_ID, SPOKE, true);

    vm.recordLogs();
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeHubSpokeConfigUpdates_statusNeither() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;
    // Skip caps and riskPremiumThreshold
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;

    vm.recordLogs();
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeHubSpokeConfigUpdates_status(uint256 active, uint256 halted) public {
    // Bound to valid flag values (ENABLED or DISABLED only, not KEEP_CURRENT)
    active = bound(active, 0, 1);
    halted = bound(halted, 0, 1);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.active = active;
    update.halted = halted;
    // Skip caps and riskPremiumThreshold
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(
      address(mockHub),
      ASSET_ID,
      SPOKE,
      EngineFlags.toBool(active)
    );

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(
      address(mockHub),
      ASSET_ID,
      SPOKE,
      EngineFlags.toBool(halted)
    );

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_statusRevert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.updateSpokeActive.selector, true);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    // Skip caps and riskPremiumThreshold
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;

    vm.expectRevert(MockHubConfigurator.UpdateSpokeActiveReverted.selector);
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_riskPremiumThreshold() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.riskPremiumThreshold = 300;
    // Skip caps and status
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeRiskPremiumThresholdCalled(
      address(mockHub),
      ASSET_ID,
      SPOKE,
      300
    );

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function testFuzz_executeHubSpokeConfigUpdates_riskPremiumThreshold(uint256 threshold) public {
    vm.assume(threshold != EngineFlags.KEEP_CURRENT);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.riskPremiumThreshold = threshold;
    // Skip caps and status
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeRiskPremiumThresholdCalled(
      address(mockHub),
      ASSET_ID,
      SPOKE,
      threshold
    );

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_riskPremiumThresholdRevert() public {
    mockHubConfigurator.setShouldRevert(
      IHubConfigurator.updateSpokeRiskPremiumThreshold.selector,
      true
    );

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.riskPremiumThreshold = 300;
    // Skip caps and status
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectRevert(MockHubConfigurator.UpdateSpokeRiskPremiumThresholdReverted.selector);
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeConfigUpdates_allFields() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();

    // Expect caps update
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeCapsCalled(address(mockHub), ASSET_ID, SPOKE, 1000, 500);

    // Expect risk premium threshold update
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeRiskPremiumThresholdCalled(
      address(mockHub),
      ASSET_ID,
      SPOKE,
      100
    );

    // Expect status updates
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(address(mockHub), ASSET_ID, SPOKE, true);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(address(mockHub), ASSET_ID, SPOKE, false);

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
  }

  function test_executeHubSpokeToAssetsAdditions() public {
    address underlying2 = makeAddr('UNDERLYING2');
    mockHub.setAssetId(underlying2, 2);

    IAaveV4ConfigEngine.SpokeAssetConfig[]
      memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](2);
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
    assets[1] = IAaveV4ConfigEngine.SpokeAssetConfig({
      underlying: underlying2,
      config: IHub.SpokeConfig({
        addCap: 2000,
        drawCap: 1000,
        riskPremiumThreshold: 200,
        active: true,
        halted: false
      })
    });

    IAaveV4ConfigEngine.SpokeToAssetsAddition memory addition = IAaveV4ConfigEngine
      .SpokeToAssetsAddition({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        spoke: SPOKE,
        assets: assets
      });

    uint256[] memory expectedAssetIds = new uint256[](2);
    expectedAssetIds[0] = 1;
    expectedAssetIds[1] = 2;

    IHub.SpokeConfig[] memory expectedConfigs = new IHub.SpokeConfig[](2);
    expectedConfigs[0] = assets[0].config;
    expectedConfigs[1] = assets[1].config;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeToAssetsCalled(
      address(mockHub),
      SPOKE,
      expectedAssetIds,
      expectedConfigs
    );

    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  function testFuzz_executeHubSpokeToAssetsAdditions(uint40 addCap, uint40 drawCap) public {
    IAaveV4ConfigEngine.SpokeAssetConfig[]
      memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](1);
    assets[0] = IAaveV4ConfigEngine.SpokeAssetConfig({
      underlying: UNDERLYING,
      config: IHub.SpokeConfig({
        addCap: addCap,
        drawCap: drawCap,
        riskPremiumThreshold: 100,
        active: true,
        halted: false
      })
    });

    IAaveV4ConfigEngine.SpokeToAssetsAddition memory addition = IAaveV4ConfigEngine
      .SpokeToAssetsAddition({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        spoke: SPOKE,
        assets: assets
      });

    uint256[] memory expectedAssetIds = new uint256[](1);
    expectedAssetIds[0] = ASSET_ID;

    IHub.SpokeConfig[] memory expectedConfigs = new IHub.SpokeConfig[](1);
    expectedConfigs[0] = assets[0].config;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeToAssetsCalled(
      address(mockHub),
      SPOKE,
      expectedAssetIds,
      expectedConfigs
    );

    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  function test_executeHubSpokeToAssetsAdditions_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.addSpokeToAssets.selector, true);

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

    IAaveV4ConfigEngine.SpokeToAssetsAddition memory addition = IAaveV4ConfigEngine
      .SpokeToAssetsAddition({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        spoke: SPOKE,
        assets: assets
      });

    vm.expectRevert(MockHubConfigurator.AddSpokeToAssetsReverted.selector);
    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  function test_executeHubAssetHalts() public {
    IAaveV4ConfigEngine.AssetHalt memory halt = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(address(mockHub), ASSET_ID);

    engine.executeHubAssetHalts(_toAssetHaltArray(halt));
  }

  function testFuzz_executeHubAssetHalts(address underlying, uint256 assetId) public {
    mockHub.setAssetId(underlying, assetId);

    IAaveV4ConfigEngine.AssetHalt memory halt = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: underlying
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(address(mockHub), assetId);

    engine.executeHubAssetHalts(_toAssetHaltArray(halt));
  }

  function test_executeHubAssetHalts_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.haltAsset.selector, true);

    IAaveV4ConfigEngine.AssetHalt memory halt = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });

    vm.expectRevert(MockHubConfigurator.HaltAssetReverted.selector);
    engine.executeHubAssetHalts(_toAssetHaltArray(halt));
  }

  function test_executeHubAssetDeactivations() public {
    IAaveV4ConfigEngine.AssetDeactivation memory deactivation = IAaveV4ConfigEngine
      .AssetDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        underlying: UNDERLYING
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateAssetCalled(address(mockHub), ASSET_ID);

    engine.executeHubAssetDeactivations(_toAssetDeactivationArray(deactivation));
  }

  function testFuzz_executeHubAssetDeactivations(address underlying, uint256 assetId) public {
    mockHub.setAssetId(underlying, assetId);

    IAaveV4ConfigEngine.AssetDeactivation memory deactivation = IAaveV4ConfigEngine
      .AssetDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        underlying: underlying
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateAssetCalled(address(mockHub), assetId);

    engine.executeHubAssetDeactivations(_toAssetDeactivationArray(deactivation));
  }

  function test_executeHubAssetDeactivations_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.deactivateAsset.selector, true);

    IAaveV4ConfigEngine.AssetDeactivation memory deactivation = IAaveV4ConfigEngine
      .AssetDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        underlying: UNDERLYING
      });

    vm.expectRevert(MockHubConfigurator.DeactivateAssetReverted.selector);
    engine.executeHubAssetDeactivations(_toAssetDeactivationArray(deactivation));
  }

  function test_executeHubAssetCapsResets() public {
    IAaveV4ConfigEngine.AssetCapsReset memory reset = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetAssetCapsCalled(address(mockHub), ASSET_ID);

    engine.executeHubAssetCapsResets(_toAssetCapsResetArray(reset));
  }

  function testFuzz_executeHubAssetCapsResets(address underlying, uint256 assetId) public {
    mockHub.setAssetId(underlying, assetId);

    IAaveV4ConfigEngine.AssetCapsReset memory reset = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: underlying
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetAssetCapsCalled(address(mockHub), assetId);

    engine.executeHubAssetCapsResets(_toAssetCapsResetArray(reset));
  }

  function test_executeHubAssetCapsResets_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.resetAssetCaps.selector, true);

    IAaveV4ConfigEngine.AssetCapsReset memory reset = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      underlying: UNDERLYING
    });

    vm.expectRevert(MockHubConfigurator.ResetAssetCapsReverted.selector);
    engine.executeHubAssetCapsResets(_toAssetCapsResetArray(reset));
  }

  function test_executeHubSpokeHalts() public {
    IAaveV4ConfigEngine.SpokeHalt memory halt = IAaveV4ConfigEngine.SpokeHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: SPOKE
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltSpokeCalled(address(mockHub), SPOKE);

    engine.executeHubSpokeHalts(_toSpokeHaltArray(halt));
  }

  function testFuzz_executeHubSpokeHalts(address spoke) public {
    vm.assume(spoke != address(0));

    IAaveV4ConfigEngine.SpokeHalt memory halt = IAaveV4ConfigEngine.SpokeHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: spoke
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltSpokeCalled(address(mockHub), spoke);

    engine.executeHubSpokeHalts(_toSpokeHaltArray(halt));
  }

  function test_executeHubSpokeHalts_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.haltSpoke.selector, true);

    IAaveV4ConfigEngine.SpokeHalt memory halt = IAaveV4ConfigEngine.SpokeHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: SPOKE
    });

    vm.expectRevert(MockHubConfigurator.HaltSpokeReverted.selector);
    engine.executeHubSpokeHalts(_toSpokeHaltArray(halt));
  }

  function test_executeHubSpokeDeactivations() public {
    IAaveV4ConfigEngine.SpokeDeactivation memory deactivation = IAaveV4ConfigEngine
      .SpokeDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        spoke: SPOKE
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateSpokeCalled(address(mockHub), SPOKE);

    engine.executeHubSpokeDeactivations(_toSpokeDeactivationArray(deactivation));
  }

  function testFuzz_executeHubSpokeDeactivations(address spoke) public {
    vm.assume(spoke != address(0));

    IAaveV4ConfigEngine.SpokeDeactivation memory deactivation = IAaveV4ConfigEngine
      .SpokeDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        spoke: spoke
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateSpokeCalled(address(mockHub), spoke);

    engine.executeHubSpokeDeactivations(_toSpokeDeactivationArray(deactivation));
  }

  function test_executeHubSpokeDeactivations_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.deactivateSpoke.selector, true);

    IAaveV4ConfigEngine.SpokeDeactivation memory deactivation = IAaveV4ConfigEngine
      .SpokeDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: address(mockHub),
        spoke: SPOKE
      });

    vm.expectRevert(MockHubConfigurator.DeactivateSpokeReverted.selector);
    engine.executeHubSpokeDeactivations(_toSpokeDeactivationArray(deactivation));
  }

  function test_executeHubSpokeCapsResets() public {
    IAaveV4ConfigEngine.SpokeCapsReset memory reset = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: SPOKE
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetSpokeCapsCalled(address(mockHub), SPOKE);

    engine.executeHubSpokeCapsResets(_toSpokeCapsResetArray(reset));
  }

  function testFuzz_executeHubSpokeCapsResets(address spoke) public {
    vm.assume(spoke != address(0));

    IAaveV4ConfigEngine.SpokeCapsReset memory reset = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: spoke
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetSpokeCapsCalled(address(mockHub), spoke);

    engine.executeHubSpokeCapsResets(_toSpokeCapsResetArray(reset));
  }

  function test_executeHubSpokeCapsResets_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.resetSpokeCaps.selector, true);

    IAaveV4ConfigEngine.SpokeCapsReset memory reset = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: address(mockHub),
      spoke: SPOKE
    });

    vm.expectRevert(MockHubConfigurator.ResetSpokeCapsReverted.selector);
    engine.executeHubSpokeCapsResets(_toSpokeCapsResetArray(reset));
  }
}
