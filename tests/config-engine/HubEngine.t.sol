// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

contract HubEngineTest is BaseConfigEngineTest {
  function setUp() public override {
    super.setUp();
    _seedFullEnvironment();
  }

  function _assertHubAssetConfig(uint256 assetId, IHub.AssetConfig memory expected) internal view {
    IHub.AssetConfig memory actual = hub1().getAssetConfig(assetId);
    assertEq(actual.liquidityFee, expected.liquidityFee);
    assertEq(actual.feeReceiver, expected.feeReceiver);
    assertEq(actual.irStrategy, expected.irStrategy);
    assertEq(actual.reinvestmentController, expected.reinvestmentController);
  }

  function test_executeHubAssetListings() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    uint256 assetCountBefore = hub1().getAssetCount();

    engine.executeHubAssetListings(_toAssetListingArray(listing));

    uint256 newAssetId = assetCountBefore;
    IHub.AssetConfig memory config = hub1().getAssetConfig(newAssetId);
    assertEq(config.feeReceiver, FEE_RECEIVER);
    assertEq(config.irStrategy, address(irStrategy1()));
    assertEq(hub1().getAssetCount(), assetCountBefore + 1);
  }

  function test_executeHubAssetListings_revert() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    engine.executeHubAssetListings(_toAssetListingArray(listing));

    vm.expectRevert(abi.encodeWithSelector(IHub.UnderlyingAlreadyListed.selector));
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetConfigUpdates_feeBoth() public {
    uint256 assetId = _getAssetId(0, 0);
    IHub.AssetConfig memory configBefore = hub1().getAssetConfig(assetId);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = 7_00;
    update.feeReceiver = ACCOUNT;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(IHubConfigurator.updateFeeConfig, (address(hub1()), assetId, 7_00, ACCOUNT))
    );
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.liquidityFee, 7_00);
    assertEq(configAfter.feeReceiver, ACCOUNT);
    assertEq(configAfter.irStrategy, configBefore.irStrategy);
    assertEq(configAfter.reinvestmentController, configBefore.reinvestmentController);
  }

  function test_executeHubAssetConfigUpdates_feeOnly() public {
    uint256 assetId = _getAssetId(0, 0);
    IHub.AssetConfig memory configBefore = hub1().getAssetConfig(assetId);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = 9_00;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(IHubConfigurator.updateLiquidityFee, (address(hub1()), assetId, 9_00))
    );
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.liquidityFee, 9_00);
    assertEq(configAfter.feeReceiver, configBefore.feeReceiver);
  }

  function test_fuzz_executeHubAssetConfigUpdates_feeOnly(uint256 liquidityFee) public {
    liquidityFee = bound(liquidityFee, 0, 10_000);
    uint256 assetId = _getAssetId(0, 0);
    IHub.AssetConfig memory configBefore = hub1().getAssetConfig(assetId);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = liquidityFee;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.liquidityFee, liquidityFee);
    assertEq(configAfter.feeReceiver, configBefore.feeReceiver);
    assertEq(configAfter.irStrategy, configBefore.irStrategy);
    assertEq(configAfter.reinvestmentController, configBefore.reinvestmentController);
  }

  function test_executeHubAssetConfigUpdates_receiverOnly() public {
    uint256 assetId = _getAssetId(0, 0);
    IHub.AssetConfig memory configBefore = hub1().getAssetConfig(assetId);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = ACCOUNT;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(IHubConfigurator.updateFeeReceiver, (address(hub1()), assetId, ACCOUNT))
    );
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.feeReceiver, ACCOUNT);
    assertEq(configAfter.liquidityFee, configBefore.liquidityFee);
  }

  function test_executeHubAssetConfigUpdates_feeNeither() public {
    uint256 assetId = _getAssetId(0, 0);
    IHub.AssetConfig memory configBefore = hub1().getAssetConfig(assetId);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.recordLogs();
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
    _assertExactEventCount(0);

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.liquidityFee, configBefore.liquidityFee);
    assertEq(configAfter.feeReceiver, configBefore.feeReceiver);
  }

  function test_executeHubAssetConfigUpdates_strategyChange() public {
    uint256 assetId = _getAssetId(0, 0);

    AssetInterestRateStrategy newStrategy = new AssetInterestRateStrategy(address(hub1()));

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.irStrategy = address(newStrategy);
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(
        IHubConfigurator.updateInterestRateStrategy,
        (address(hub1()), assetId, address(newStrategy), abi.encode(IR_DATA))
      )
    );
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.irStrategy, address(newStrategy));
  }

  /// @dev These tests verify that the engine reverts when trying to update a new IR strategy with
  ///   sentinel irData fields.
  function test_executeHubAssetConfigUpdates_revertsWith_sentinelIrDataOnStrategyChange() public {
    AssetInterestRateStrategy newStrategy = new AssetInterestRateStrategy(address(hub1()));

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.irStrategy = address(newStrategy);
    update.irData = _keepCurrentIrData();
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectRevert(HubEngine.InvalidIrDataWithNewStrategy.selector);
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_revertsWith_partialSentinelIrDataOnStrategyChange()
    public
  {
    AssetInterestRateStrategy newStrategy = new AssetInterestRateStrategy(address(hub1()));

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.irStrategy = address(newStrategy);
    update.irData = IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 80_00,
      baseDrawnRate: 1_00,
      rateGrowthBeforeOptimal: EngineFlags.KEEP_CURRENT_UINT32,
      rateGrowthAfterOptimal: 60_00
    });
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectRevert(HubEngine.InvalidIrDataWithNewStrategy.selector);
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));
  }

  function test_executeHubAssetConfigUpdates_irDataOnly() public {
    uint256 assetId = _getAssetId(0, 0);

    IAssetInterestRateStrategy.InterestRateData memory newIrData = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 2_00,
        rateGrowthBeforeOptimal: 5_00,
        rateGrowthAfterOptimal: 70_00
      });

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = newIrData;
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(
        IHubConfigurator.updateInterestRateData,
        (address(hub1()), assetId, abi.encode(newIrData))
      )
    );
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IAssetInterestRateStrategy.InterestRateData memory storedIrData = irStrategy1()
      .getInterestRateData(assetId);
    assertEq(storedIrData.optimalUsageRatio, 90_00);
    assertEq(storedIrData.baseDrawnRate, 2_00);
    assertEq(storedIrData.rateGrowthBeforeOptimal, 5_00);
    assertEq(storedIrData.rateGrowthAfterOptimal, 70_00);
  }

  function test_executeHubAssetConfigUpdates_irNoOp() public {
    uint256 assetId = _getAssetId(0, 0);
    IAssetInterestRateStrategy.InterestRateData memory irBefore = irStrategy1().getInterestRateData(
      assetId
    );

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IAssetInterestRateStrategy.InterestRateData memory irAfter = irStrategy1().getInterestRateData(
      assetId
    );
    assertEq(irAfter.optimalUsageRatio, irBefore.optimalUsageRatio);
    assertEq(irAfter.baseDrawnRate, irBefore.baseDrawnRate);
  }

  function test_executeHubAssetConfigUpdates_reinvestmentController() public {
    uint256 assetId = _getAssetId(0, 0);

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.reinvestmentController = REINVESTMENT_CONTROLLER;
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = _keepCurrentIrData();

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(
        IHubConfigurator.updateReinvestmentController,
        (address(hub1()), assetId, REINVESTMENT_CONTROLLER)
      )
    );
    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.reinvestmentController, REINVESTMENT_CONTROLLER);
  }

  function test_executeHubAssetConfigUpdates_allFields() public {
    uint256 assetId = _getAssetId(0, 0);

    AssetInterestRateStrategy newStrategy = new AssetInterestRateStrategy(address(hub1()));

    IAaveV4ConfigEngine.AssetConfigUpdate memory update = _defaultAssetConfigUpdate();
    update.liquidityFee = 8_00;
    update.feeReceiver = ACCOUNT;
    update.irStrategy = address(newStrategy);
    update.reinvestmentController = REINVESTMENT_CONTROLLER;

    engine.executeHubAssetConfigUpdates(_toAssetConfigUpdateArray(update));

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.liquidityFee, 8_00);
    assertEq(configAfter.feeReceiver, ACCOUNT);
    assertEq(configAfter.reinvestmentController, REINVESTMENT_CONTROLLER);
    assertEq(configAfter.irStrategy, address(newStrategy));
  }

  function test_executeHubSpokeConfigUpdates_capsBoth() public {
    uint256 assetId = _getAssetId(0, 0);
    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(assetId, address(spoke1()));

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = 1000;
    update.drawCap = 500;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(
        IHubConfigurator.updateSpokeCaps,
        (address(hub1()), assetId, address(spoke1()), 1000, 500)
      )
    );

    vm.expectEmit(address(hub1()));
    emit IHub.UpdateSpokeConfig(
      assetId,
      address(spoke1()),
      IHub.SpokeConfig({
        addCap: 1000,
        drawCap: 500,
        riskPremiumThreshold: spokeConfigBefore.riskPremiumThreshold,
        active: spokeConfigBefore.active,
        halted: spokeConfigBefore.halted
      })
    );

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.addCap, 1000);
    assertEq(spokeConfigAfter.drawCap, 500);
    assertEq(spokeConfigAfter.riskPremiumThreshold, spokeConfigBefore.riskPremiumThreshold);
    assertEq(spokeConfigAfter.active, spokeConfigBefore.active);
    assertEq(spokeConfigAfter.halted, spokeConfigBefore.halted);
  }

  function test_fuzz_executeHubSpokeConfigUpdates_capsBoth(uint256 addCap, uint256 drawCap) public {
    addCap = bound(addCap, 0, type(uint40).max);
    drawCap = bound(drawCap, 0, type(uint40).max);
    uint256 assetId = _getAssetId(0, 0);
    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(assetId, address(spoke1()));

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = addCap;
    update.drawCap = drawCap;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.addCap, addCap);
    assertEq(spokeConfigAfter.drawCap, drawCap);
    assertEq(spokeConfigAfter.riskPremiumThreshold, spokeConfigBefore.riskPremiumThreshold);
    assertEq(spokeConfigAfter.active, spokeConfigBefore.active);
    assertEq(spokeConfigAfter.halted, spokeConfigBefore.halted);
  }

  function test_executeHubSpokeConfigUpdates_addCapOnly() public {
    uint256 assetId = _getAssetId(0, 0);
    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(assetId, address(spoke1()));

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = 2000;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(
        IHubConfigurator.updateSpokeAddCap,
        (address(hub1()), assetId, address(spoke1()), 2000)
      )
    );
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.addCap, 2000);
    assertEq(spokeConfigAfter.drawCap, spokeConfigBefore.drawCap);
  }

  function test_fuzz_executeHubSpokeConfigUpdates_addCap(uint256 addCap) public {
    addCap = bound(addCap, 0, type(uint40).max);
    uint256 assetId = _getAssetId(0, 0);
    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(assetId, address(spoke1()));

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = addCap;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.addCap, addCap);
    assertEq(spokeConfigAfter.drawCap, spokeConfigBefore.drawCap);
    assertEq(spokeConfigAfter.riskPremiumThreshold, spokeConfigBefore.riskPremiumThreshold);
    assertEq(spokeConfigAfter.active, spokeConfigBefore.active);
    assertEq(spokeConfigAfter.halted, spokeConfigBefore.halted);
  }

  function test_executeHubSpokeConfigUpdates_drawCapOnly() public {
    uint256 assetId = _getAssetId(0, 0);
    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(assetId, address(spoke1()));

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = 300;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(
        IHubConfigurator.updateSpokeDrawCap,
        (address(hub1()), assetId, address(spoke1()), 300)
      )
    );
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.drawCap, 300);
    assertEq(spokeConfigAfter.addCap, spokeConfigBefore.addCap);
  }

  function test_fuzz_executeHubSpokeConfigUpdates_drawCap(uint256 drawCap) public {
    drawCap = bound(drawCap, 0, type(uint40).max);
    uint256 assetId = _getAssetId(0, 0);
    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(assetId, address(spoke1()));

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = drawCap;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.drawCap, drawCap);
    assertEq(spokeConfigAfter.addCap, spokeConfigBefore.addCap);
    assertEq(spokeConfigAfter.riskPremiumThreshold, spokeConfigBefore.riskPremiumThreshold);
    assertEq(spokeConfigAfter.active, spokeConfigBefore.active);
    assertEq(spokeConfigAfter.halted, spokeConfigBefore.halted);
  }

  function test_executeHubSpokeConfigUpdates_capsNeither() public {
    uint256 assetId = _getAssetId(0, 0);
    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(assetId, address(spoke1()));

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.recordLogs();
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));
    _assertExactEventCount(0);

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.addCap, spokeConfigBefore.addCap);
    assertEq(spokeConfigAfter.drawCap, spokeConfigBefore.drawCap);
  }

  function test_executeHubSpokeConfigUpdates_statusBoth() public {
    uint256 assetId = _getAssetId(0, 0);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.ENABLED;
    update.halted = EngineFlags.DISABLED;

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertTrue(spokeConfigAfter.active);
    assertFalse(spokeConfigAfter.halted);
  }

  function test_executeHubSpokeConfigUpdates_haltedOnly() public {
    uint256 assetId = _getAssetId(0, 0);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.ENABLED;
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.riskPremiumThreshold = EngineFlags.KEEP_CURRENT;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(
        IHubConfigurator.updateSpokeHalted,
        (address(hub1()), assetId, address(spoke1()), true)
      )
    );
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertTrue(spokeConfigAfter.halted);
  }

  function test_executeHubSpokeConfigUpdates_riskPremiumThreshold() public {
    uint256 assetId = _getAssetId(0, 0);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.riskPremiumThreshold = 300;
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectCall(
      address(hubConfigurator),
      abi.encodeCall(
        IHubConfigurator.updateSpokeRiskPremiumThreshold,
        (address(hub1()), assetId, address(spoke1()), 300)
      )
    );
    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.riskPremiumThreshold, 300);
  }

  function test_fuzz_executeHubSpokeConfigUpdates_riskPremiumThreshold(
    uint256 riskPremiumThreshold
  ) public {
    riskPremiumThreshold = bound(riskPremiumThreshold, 0, type(uint24).max);
    uint256 assetId = _getAssetId(0, 0);
    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(assetId, address(spoke1()));

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.riskPremiumThreshold = riskPremiumThreshold;
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.riskPremiumThreshold, riskPremiumThreshold);
    assertEq(spokeConfigAfter.addCap, spokeConfigBefore.addCap);
    assertEq(spokeConfigAfter.drawCap, spokeConfigBefore.drawCap);
    assertEq(spokeConfigAfter.active, spokeConfigBefore.active);
    assertEq(spokeConfigAfter.halted, spokeConfigBefore.halted);
  }

  function test_executeHubSpokeConfigUpdates_allFields() public {
    uint256 assetId = _getAssetId(0, 0);

    IAaveV4ConfigEngine.SpokeConfigUpdate memory update = _defaultSpokeConfigUpdate();
    update.addCap = 1000;
    update.drawCap = 500;
    update.riskPremiumThreshold = 100;
    update.active = EngineFlags.ENABLED;
    update.halted = EngineFlags.DISABLED;

    engine.executeHubSpokeConfigUpdates(_toSpokeConfigUpdateArray(update));

    IHub.SpokeConfig memory spokeConfigAfter = hub1().getSpokeConfig(assetId, address(spoke1()));
    assertEq(spokeConfigAfter.addCap, 1000);
    assertEq(spokeConfigAfter.drawCap, 500);
    assertEq(spokeConfigAfter.riskPremiumThreshold, 100);
    assertTrue(spokeConfigAfter.active);
    assertFalse(spokeConfigAfter.halted);
  }

  function test_executeHubSpokeToAssetsAdditions() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();

    IAaveV4ConfigEngine.SpokeAssetConfig[]
      memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](2);
    assets[0] = IAaveV4ConfigEngine.SpokeAssetConfig({
      underlying: address(weth),
      config: IHub.SpokeConfig({
        addCap: 1000,
        drawCap: 500,
        riskPremiumThreshold: 100,
        active: true,
        halted: false
      })
    });
    assets[1] = IAaveV4ConfigEngine.SpokeAssetConfig({
      underlying: address(usdx),
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
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        spoke: address(newSpoke),
        assets: assets
      });

    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));

    IHub.SpokeConfig memory wethConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(newSpoke)
    );
    assertEq(wethConfig.addCap, 1000);
    assertEq(wethConfig.drawCap, 500);
    assertTrue(wethConfig.active);

    IHub.SpokeConfig memory usdxConfig = hub1().getSpokeConfig(
      _getAssetId(0, 1),
      address(newSpoke)
    );
    assertEq(usdxConfig.addCap, 2000);
    assertEq(usdxConfig.drawCap, 1000);
  }

  function test_executeHubAssetHalts() public {
    IAaveV4ConfigEngine.AssetHalt memory halt = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });

    engine.executeHubAssetHalts(_toAssetHaltArray(halt));

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertTrue(spokeConfig.halted);
  }

  function test_executeHubAssetDeactivations() public {
    engine.executeHubAssetHalts(
      _toAssetHaltArray(
        IAaveV4ConfigEngine.AssetHalt({
          hubConfigurator: hubConfigurator,
          hub: address(hub1()),
          underlying: address(weth)
        })
      )
    );

    IAaveV4ConfigEngine.AssetDeactivation memory deactivation = IAaveV4ConfigEngine
      .AssetDeactivation({
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        underlying: address(weth)
      });

    engine.executeHubAssetDeactivations(_toAssetDeactivationArray(deactivation));

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertFalse(spokeConfig.active);
  }

  function test_executeHubAssetCapsResets() public {
    IAaveV4ConfigEngine.AssetCapsReset memory reset = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });

    engine.executeHubAssetCapsResets(_toAssetCapsResetArray(reset));

    for (uint256 s; s < NUM_SPOKES; ++s) {
      IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
        _getAssetId(0, 0),
        address(spokes[s])
      );
      assertEq(spokeConfig.addCap, 0);
      assertEq(spokeConfig.drawCap, 0);
    }
  }

  function test_executeHubSpokeDeactivations() public {
    vm.prank(ADMIN);
    hub1().updateSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1()),
      IHub.SpokeConfig({addCap: 0, drawCap: 0, riskPremiumThreshold: 0, active: true, halted: true})
    );

    IAaveV4ConfigEngine.SpokeDeactivation memory deactivation = IAaveV4ConfigEngine
      .SpokeDeactivation({
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        spoke: address(spoke1())
      });

    engine.executeHubSpokeDeactivations(_toSpokeDeactivationArray(deactivation));

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertFalse(spokeConfig.active);
  }

  function test_executeHubSpokeCapsResets() public {
    IAaveV4ConfigEngine.SpokeCapsReset memory reset = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      spoke: address(spoke1())
    });

    engine.executeHubSpokeCapsResets(_toSpokeCapsResetArray(reset));

    for (uint256 t; t < NUM_TOKENS; ++t) {
      IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
        _getAssetId(0, t),
        address(spoke1())
      );
      assertEq(spokeConfig.addCap, 0);
      assertEq(spokeConfig.drawCap, 0);
    }
  }

  function test_executeHubAssetListings_withTokenization() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Tokenized NEW',
      symbol: 'tNEW'
    });

    uint256 assetCountBefore = hub1().getAssetCount();
    engine.executeHubAssetListings(_toAssetListingArray(listing));

    IHub.AssetConfig memory config = hub1().getAssetConfig(assetCountBefore);
    assertEq(config.feeReceiver, FEE_RECEIVER);

    address predictedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(newToken),
      'Tokenized NEW',
      'tNEW',
      PROXY_ADMIN_OWNER
    );

    IHub.SpokeConfig memory tsConfig = hub1().getSpokeConfig(assetCountBefore, predictedProxy);
    assertEq(tsConfig.addCap, 1000);
    assertTrue(tsConfig.active);

    assertEq(
      Ownable(ProxyHelper.getProxyAdmin(predictedProxy)).owner(),
      PROXY_ADMIN_OWNER,
      'TokenizationSpoke ProxyAdmin owner should be the declared proxyAdminOwner'
    );
  }

  function test_executeHubAssetListings_noTokenization() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);

    uint256 assetCountBefore = hub1().getAssetCount();
    uint256 expectedAssetId = assetCountBefore;
    engine.executeHubAssetListings(_toAssetListingArray(listing));

    assertEq(hub1().getAssetCount(), assetCountBefore + 1);

    // the skip path must not deploy or register a TokenizationSpoke: only the fee receiver spoke exists
    assertEq(hub1().getSpokeCount(expectedAssetId), 1);

    address predictedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(newToken),
      '',
      '',
      PROXY_ADMIN_OWNER
    );
    assertFalse(hub1().isSpokeListed(expectedAssetId, predictedProxy));
    assertEq(predictedProxy.code.length, 0);
  }

  function test_executeHubAssetListings_tokenization_deterministicAddress() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Tokenized NEW',
      symbol: 'tNEW'
    });

    address predictedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(newToken),
      'Tokenized NEW',
      'tNEW',
      PROXY_ADMIN_OWNER
    );

    uint256 assetCountBefore = hub1().getAssetCount();
    engine.executeHubAssetListings(_toAssetListingArray(listing));

    IHub.SpokeConfig memory tsConfig = hub1().getSpokeConfig(assetCountBefore, predictedProxy);
    assertEq(tsConfig.addCap, 1000);
  }

  function test_executeHubAssetListings_tokenization_revertsOnEmptyName() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: '',
      symbol: 'tNEW'
    });

    vm.expectRevert(HubEngine.InvalidTokenizationSpokeConfig.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_tokenization_revertsOnEmptySymbol() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Tokenized NEW',
      symbol: ''
    });

    vm.expectRevert(HubEngine.InvalidTokenizationSpokeConfig.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_tokenization_revertsOnAddCapOnly() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1000,
      proxyAdminOwner: address(0),
      name: '',
      symbol: ''
    });

    vm.expectRevert(HubEngine.InvalidTokenizationSpokeConfig.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_tokenization_revertsOnZeroProxyAdminOwner() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1000,
      proxyAdminOwner: address(0),
      name: 'Tokenized NEW',
      symbol: 'tNEW'
    });

    vm.expectRevert(HubEngine.InvalidTokenizationSpokeConfig.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_tokenization_revertsOnProxyAdminOwnerOnly() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 0,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: '',
      symbol: ''
    });

    vm.expectRevert(HubEngine.InvalidTokenizationSpokeConfig.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_tokenization_zeroAddCap_deploysInactiveCapped() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 0,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Tokenized NEW',
      symbol: 'tNEW'
    });

    uint256 assetCountBefore = hub1().getAssetCount();
    engine.executeHubAssetListings(_toAssetListingArray(listing));

    address predictedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(newToken),
      'Tokenized NEW',
      'tNEW',
      PROXY_ADMIN_OWNER
    );

    IHub.SpokeConfig memory tsConfig = hub1().getSpokeConfig(assetCountBefore, predictedProxy);
    assertEq(tsConfig.addCap, 0);
    assertTrue(tsConfig.active);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(predictedProxy)).owner(), PROXY_ADMIN_OWNER);
  }

  function test_executeHubAssetListings_multipleHubs() public {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](2);

    listings[0] = _defaultAssetListing();
    listings[0].hub = address(hub1());
    listings[0].underlying = address(newToken);

    listings[1] = _defaultAssetListing();
    listings[1].hub = address(hub2());
    listings[1].underlying = address(newToken);
    listings[1].irStrategy = address(irStrategy2());

    uint256 hub1CountBefore = hub1().getAssetCount();
    uint256 hub2CountBefore = hub2().getAssetCount();

    engine.executeHubAssetListings(listings);

    assertEq(hub1().getAssetCount(), hub1CountBefore + 1);
    assertEq(hub2().getAssetCount(), hub2CountBefore + 1);
  }

  function test_computeImplementationAddress() public view {
    address predicted = TokenizationSpokeDeployer.computeImplementationAddress(
      address(hub1()),
      address(newToken),
      'Tokenized NEW',
      'tNEW'
    );
    assertNotEq(predicted, address(0));
  }

  function test_tokenizationSpokeDeployer_deploy_revertsOnZeroProxyAdminOwner() public {
    vm.expectRevert(TokenizationSpokeDeployer.InvalidProxyAdminOwner.selector);
    TokenizationSpokeDeployer.deploy({
      hub: address(hub1()),
      underlying: address(newToken),
      name: 'Tokenized NEW',
      symbol: 'tNEW',
      proxyAdminOwner: address(0)
    });
  }

  function test_executeHubSpokeToAssetsAdditions_revert_spokeAlreadyListed() public {
    IAaveV4ConfigEngine.SpokeAssetConfig[]
      memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](1);
    assets[0] = IAaveV4ConfigEngine.SpokeAssetConfig({
      underlying: address(weth),
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
        hubConfigurator: hubConfigurator,
        hub: address(hub1()),
        spoke: address(spoke1()),
        assets: assets
      });

    vm.expectRevert(abi.encodeWithSelector(IHub.SpokeAlreadyListed.selector));
    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  function test_executeHubSpokeConfigUpdates_multipleHubs() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](2);

    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      spoke: address(spoke1()),
      addCap: 1111,
      drawCap: EngineFlags.KEEP_CURRENT,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });

    updates[1] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub2()),
      underlying: address(weth),
      spoke: address(spoke1()),
      addCap: 2222,
      drawCap: EngineFlags.KEEP_CURRENT,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });

    engine.executeHubSpokeConfigUpdates(updates);

    IHub.SpokeConfig memory config1 = hub1().getSpokeConfig(_getAssetId(0, 0), address(spoke1()));
    assertEq(config1.addCap, 1111);

    IHub.SpokeConfig memory config2 = hub2().getSpokeConfig(_getAssetId(1, 0), address(spoke1()));
    assertEq(config2.addCap, 2222);
  }

  function test_executeHubAssetConfigUpdates_multipleAssets() public {
    uint256 assetId0 = _getAssetId(0, TOKEN_WETH);
    uint256 assetId1 = _getAssetId(0, TOKEN_USDX);

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](2);

    updates[0] = _defaultAssetConfigUpdate();
    updates[0].underlying = address(weth);
    updates[0].liquidityFee = 3_00;
    updates[0].feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    updates[0].irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    updates[0].irData = _keepCurrentIrData();
    updates[0].reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    updates[1] = _defaultAssetConfigUpdate();
    updates[1].underlying = address(usdx);
    updates[1].liquidityFee = 6_00;
    updates[1].feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    updates[1].irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    updates[1].irData = _keepCurrentIrData();
    updates[1].reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    engine.executeHubAssetConfigUpdates(updates);

    assertEq(hub1().getAssetConfig(assetId0).liquidityFee, 3_00);
    assertEq(hub1().getAssetConfig(assetId1).liquidityFee, 6_00);
  }

  function test_executeHubAssetConfigUpdates_crossHub() public {
    uint256 assetIdHub1 = _getAssetId(0, TOKEN_WETH);
    uint256 assetIdHub2 = _getAssetId(1, TOKEN_WETH);
    IHub.AssetConfig memory configHub1Before = hub1().getAssetConfig(assetIdHub1);
    IHub.AssetConfig memory configHub2Before = hub2().getAssetConfig(assetIdHub2);

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](2);

    updates[0] = _defaultAssetConfigUpdate();
    updates[0].hub = address(hub1());
    updates[0].underlying = address(weth);
    updates[0].liquidityFee = 2_00;
    updates[0].feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    updates[0].irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    updates[0].irData = _keepCurrentIrData();
    updates[0].reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    updates[1] = _defaultAssetConfigUpdate();
    updates[1].hub = address(hub2());
    updates[1].underlying = address(weth);
    updates[1].liquidityFee = 8_00;
    updates[1].feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;
    updates[1].irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    updates[1].irData = _keepCurrentIrData();
    updates[1].reinvestmentController = EngineFlags.KEEP_CURRENT_ADDRESS;

    engine.executeHubAssetConfigUpdates(updates);

    IHub.AssetConfig memory configHub1After = hub1().getAssetConfig(assetIdHub1);
    assertEq(configHub1After.liquidityFee, 2_00);
    assertEq(configHub1After.feeReceiver, configHub1Before.feeReceiver);

    IHub.AssetConfig memory configHub2After = hub2().getAssetConfig(assetIdHub2);
    assertEq(configHub2After.liquidityFee, 8_00);
    assertEq(configHub2After.feeReceiver, configHub2Before.feeReceiver);
  }

  function test_executeHubSpokeConfigUpdates_multipleUpdates() public {
    uint256 assetId0 = _getAssetId(0, TOKEN_WETH);
    uint256 assetId1 = _getAssetId(0, TOKEN_USDX);

    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](2);

    updates[0] = _defaultSpokeConfigUpdate();
    updates[0].underlying = address(weth);
    updates[0].addCap = 500;
    updates[0].drawCap = EngineFlags.KEEP_CURRENT;
    updates[0].riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    updates[0].active = EngineFlags.KEEP_CURRENT;
    updates[0].halted = EngineFlags.KEEP_CURRENT;

    updates[1] = _defaultSpokeConfigUpdate();
    updates[1].underlying = address(usdx);
    updates[1].addCap = 2000;
    updates[1].drawCap = EngineFlags.KEEP_CURRENT;
    updates[1].riskPremiumThreshold = EngineFlags.KEEP_CURRENT;
    updates[1].active = EngineFlags.KEEP_CURRENT;
    updates[1].halted = EngineFlags.KEEP_CURRENT;

    engine.executeHubSpokeConfigUpdates(updates);

    assertEq(hub1().getSpokeConfig(assetId0, address(spoke1())).addCap, 500);
    assertEq(hub1().getSpokeConfig(assetId1, address(spoke1())).addCap, 2000);
  }

  function test_executeHubAssetHalts_multipleAssets() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](2);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    halts[1] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(usdx)
    });

    engine.executeHubAssetHalts(halts);

    assertTrue(hub1().getSpokeConfig(_getAssetId(0, TOKEN_WETH), address(spoke1())).halted);
    assertTrue(hub1().getSpokeConfig(_getAssetId(0, TOKEN_USDX), address(spoke1())).halted);
  }

  function test_executeHubAssetListings_withTokenization_duplicateUnderlying_revertsBeforeCreate2()
    public
  {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.underlying = address(newToken);
    listing.tokenization = IAaveV4ConfigEngine.TokenizationSpokeConfig({
      addCap: 1000,
      proxyAdminOwner: PROXY_ADMIN_OWNER,
      name: 'Tokenized NEW',
      symbol: 'tNEW'
    });

    engine.executeHubAssetListings(_toAssetListingArray(listing));

    vm.expectRevert(abi.encodeWithSelector(IHub.UnderlyingAlreadyListed.selector));
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }
}
