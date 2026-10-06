// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import 'tests/config-engine/BaseConfigEngine.t.sol';

contract AaveV4PayloadTest is BaseConfigEngineTest {
  AaveV4PayloadWrapper public payload;
  PositionManagerBaseWrapper public payloadPositionManager;

  function setUp() public override {
    super.setUp();
    payload = new AaveV4PayloadWrapper(IAaveV4ConfigEngine(address(engine)));

    // Grant same roles to payload (since delegatecall makes msg.sender = payload)
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(payload), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(payload), 0);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(payload), 0);
    vm.stopPrank();

    payloadPositionManager = new PositionManagerBaseWrapper(address(payload));

    _seedFullEnvironment();
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
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    payload.setHubAssetHalts(halts);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertTrue(spokeConfig.halted);
  }

  function test_execute_spokeAction_delegatesCorrectly() public {
    IAaveV4ConfigEngine.PositionManagerUpdate[]
      memory updates = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      positionManager: address(payloadPositionManager),
      active: true
    });
    payload.setSpokePositionManagerUpdates(updates);

    payload.execute();

    assertTrue(spoke1().isPositionManagerActive(address(payloadPositionManager)));
  }

  function test_execute_accessManagerAction_delegatesCorrectly() public {
    IAaveV4ConfigEngine.RoleMembership[]
      memory memberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    memberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: true,
      executionDelay: 100
    });
    payload.setAccessManagerRoleMemberships(memberships);

    payload.execute();

    (bool isMember, uint32 delay) = accessManager.hasRole(Roles.HUB_CONFIGURATOR_ROLE, ACCOUNT);
    assertTrue(isMember);
    assertEq(delay, 100);
  }

  function test_execute_multipleActions_allExecuted() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    payload.setHubAssetHalts(halts);

    IAaveV4ConfigEngine.PositionManagerUpdate[]
      memory pmUpdates = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    pmUpdates[0] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      positionManager: address(payloadPositionManager),
      active: true
    });
    payload.setSpokePositionManagerUpdates(pmUpdates);

    IAaveV4ConfigEngine.RoleMembership[]
      memory memberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    memberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: true,
      executionDelay: 0
    });
    payload.setAccessManagerRoleMemberships(memberships);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertTrue(spokeConfig.halted);

    assertTrue(spoke1().isPositionManagerActive(address(payloadPositionManager)));

    (bool isMember, ) = accessManager.hasRole(Roles.HUB_CONFIGURATOR_ROLE, ACCOUNT);
    assertTrue(isMember);
  }

  function test_execute_multipleActions_revertsIfOneInvalid() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    payload.setHubAssetHalts(halts);

    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = _defaultAssetListing();
    listings[0].underlying = address(weth);
    payload.setHubAssetListings(listings);

    vm.expectRevert(abi.encodeWithSelector(IHub.UnderlyingAlreadyListed.selector));
    payload.execute();
  }

  function test_execute_emptyArraysSkipped() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    payload.setHubAssetHalts(halts);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertTrue(spokeConfig.halted);
    assertTrue(payload.preExecuteCalled());
    assertTrue(payload.postExecuteCalled());
  }

  function test_execute_revertsWith_UnderlyingAlreadyListed_propagatesFromEngine() public {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = _defaultAssetListing();
    listings[0].underlying = address(weth);
    payload.setHubAssetListings(listings);

    vm.expectRevert(abi.encodeWithSelector(IHub.UnderlyingAlreadyListed.selector));
    payload.execute();
  }

  function test_configEngine_immutable() public view {
    assertEq(address(payload.CONFIG_ENGINE()), address(engine));
  }

  function test_execute_hubAssetListings() public {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = _defaultAssetListing();
    listings[0].underlying = address(newToken);
    payload.setHubAssetListings(listings);

    uint256 assetCountBefore = hub1().getAssetCount();
    uint256 expectedAssetId = assetCountBefore;
    payload.execute();

    assertEq(hub1().getAssetCount(), assetCountBefore + 1);
    IHub.AssetConfig memory config = hub1().getAssetConfig(expectedAssetId);
    assertEq(config.feeReceiver, FEE_RECEIVER);
  }

  function test_execute_hubAssetConfigUpdates_feeOnly() public {
    uint256 assetId = _getAssetId(0, 0);

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      liquidityFee: 8_00,
      feeReceiver: ACCOUNT,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    payload.setHubAssetConfigUpdates(updates);

    payload.execute();

    IHub.AssetConfig memory config = hub1().getAssetConfig(assetId);
    assertEq(config.liquidityFee, 8_00);
    assertEq(config.feeReceiver, ACCOUNT);
  }

  function test_execute_hubAssetConfigUpdates_interestRateOnly() public {
    uint256 assetId = _getAssetId(0, 0);

    IAssetInterestRateStrategy.InterestRateData memory newIrData = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 95_00,
        baseDrawnRate: 3_00,
        rateGrowthBeforeOptimal: 6_00,
        rateGrowthAfterOptimal: 80_00
      });

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      liquidityFee: EngineFlags.KEEP_CURRENT,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: newIrData,
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    payload.setHubAssetConfigUpdates(updates);

    payload.execute();

    IAssetInterestRateStrategy.InterestRateData memory storedIrData = irStrategy1()
      .getInterestRateData(assetId);
    assertEq(storedIrData.optimalUsageRatio, 95_00);
    assertEq(storedIrData.baseDrawnRate, 3_00);
  }

  function test_execute_hubAssetConfigUpdates_reinvestmentOnly() public {
    uint256 assetId = _getAssetId(0, 0);

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      liquidityFee: EngineFlags.KEEP_CURRENT,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: REINVESTMENT_CONTROLLER
    });
    payload.setHubAssetConfigUpdates(updates);

    payload.execute();

    IHub.AssetConfig memory config = hub1().getAssetConfig(assetId);
    assertEq(config.reinvestmentController, REINVESTMENT_CONTROLLER);
  }

  function test_fuzz_execute_hubAssetConfigUpdates_feeOnly(uint256 liquidityFee) public {
    liquidityFee = bound(liquidityFee, 0, 100_00);
    uint256 assetId = _getAssetId(0, 0);
    IHub.AssetConfig memory configBefore = hub1().getAssetConfig(assetId);

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      liquidityFee: liquidityFee,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    payload.setHubAssetConfigUpdates(updates);

    payload.execute();

    IHub.AssetConfig memory configAfter = hub1().getAssetConfig(assetId);
    assertEq(configAfter.liquidityFee, liquidityFee);
    assertEq(configAfter.feeReceiver, configBefore.feeReceiver);
    assertEq(configAfter.irStrategy, configBefore.irStrategy);
    assertEq(configAfter.reinvestmentController, configBefore.reinvestmentController);
  }

  function test_execute_hubAssetConfigUpdates_twoAssets_feeOnly() public {
    uint256 wethAssetId = _getAssetId(0, TOKEN_WETH);
    uint256 usdxAssetId = _getAssetId(0, TOKEN_USDX);

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](2);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      liquidityFee: 8_00,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    updates[1] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(usdx),
      liquidityFee: 10_00,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    payload.setHubAssetConfigUpdates(updates);

    payload.execute();

    IHub.AssetConfig memory wethConfig = hub1().getAssetConfig(wethAssetId);
    assertEq(wethConfig.liquidityFee, 8_00);

    IHub.AssetConfig memory usdxConfig = hub1().getAssetConfig(usdxAssetId);
    assertEq(usdxConfig.liquidityFee, 10_00);
  }

  function test_execute_hubAssetConfigUpdates_twoAssets_mixedFields() public {
    uint256 wethAssetId = _getAssetId(0, TOKEN_WETH);
    uint256 usdxAssetId = _getAssetId(0, TOKEN_USDX);

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](2);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      liquidityFee: 8_00,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    updates[1] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(usdx),
      liquidityFee: EngineFlags.KEEP_CURRENT,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: REINVESTMENT_CONTROLLER
    });
    payload.setHubAssetConfigUpdates(updates);

    payload.execute();

    IHub.AssetConfig memory wethConfig = hub1().getAssetConfig(wethAssetId);
    assertEq(wethConfig.liquidityFee, 8_00);

    IHub.AssetConfig memory usdxConfig = hub1().getAssetConfig(usdxAssetId);
    assertEq(usdxConfig.reinvestmentController, REINVESTMENT_CONTROLLER);
  }

  function test_execute_hubSpokeToAssetsAdditions() public {
    (ISpoke newSpoke, ) = _deployNewSpoke();

    IAaveV4ConfigEngine.SpokeToAssetsAddition[]
      memory additions = new IAaveV4ConfigEngine.SpokeToAssetsAddition[](1);
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
    additions[0] = IAaveV4ConfigEngine.SpokeToAssetsAddition({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      spoke: address(newSpoke),
      assets: assets
    });
    payload.setHubSpokeToAssetsAdditions(additions);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(newSpoke)
    );
    assertEq(spokeConfig.addCap, 1000);
    assertTrue(spokeConfig.active);
  }

  function test_execute_hubSpokeConfigUpdates_capsOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      spoke: address(spoke1()),
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    payload.setHubSpokeConfigUpdates(updates);

    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertEq(spokeConfig.addCap, 1000);
    assertEq(spokeConfig.drawCap, 500);
    assertEq(spokeConfig.riskPremiumThreshold, spokeConfigBefore.riskPremiumThreshold);
    assertEq(spokeConfig.active, spokeConfigBefore.active);
    assertEq(spokeConfig.halted, spokeConfigBefore.halted);
  }

  function test_execute_hubSpokeConfigUpdates_riskPremiumThresholdOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      spoke: address(spoke1()),
      addCap: EngineFlags.KEEP_CURRENT,
      drawCap: EngineFlags.KEEP_CURRENT,
      riskPremiumThreshold: 200,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    payload.setHubSpokeConfigUpdates(updates);

    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertEq(spokeConfig.riskPremiumThreshold, 200);
    assertEq(spokeConfig.addCap, spokeConfigBefore.addCap);
    assertEq(spokeConfig.drawCap, spokeConfigBefore.drawCap);
    assertEq(spokeConfig.active, spokeConfigBefore.active);
    assertEq(spokeConfig.halted, spokeConfigBefore.halted);
  }

  function test_execute_hubSpokeConfigUpdates_statusOnly() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      spoke: address(spoke1()),
      addCap: EngineFlags.KEEP_CURRENT,
      drawCap: EngineFlags.KEEP_CURRENT,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.ENABLED,
      halted: EngineFlags.DISABLED
    });
    payload.setHubSpokeConfigUpdates(updates);

    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertTrue(spokeConfig.active);
    assertFalse(spokeConfig.halted);
    assertEq(spokeConfig.addCap, spokeConfigBefore.addCap);
    assertEq(spokeConfig.drawCap, spokeConfigBefore.drawCap);
    assertEq(spokeConfig.riskPremiumThreshold, spokeConfigBefore.riskPremiumThreshold);
  }

  function test_fuzz_execute_hubSpokeConfigUpdates_capsOnly(
    uint256 addCap,
    uint256 drawCap
  ) public {
    addCap = bound(addCap, 0, type(uint40).max);
    drawCap = bound(drawCap, 0, type(uint40).max);

    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      spoke: address(spoke1()),
      addCap: addCap,
      drawCap: drawCap,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    payload.setHubSpokeConfigUpdates(updates);

    IHub.SpokeConfig memory spokeConfigBefore = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertEq(spokeConfig.addCap, addCap);
    assertEq(spokeConfig.drawCap, drawCap);
    assertEq(spokeConfig.riskPremiumThreshold, spokeConfigBefore.riskPremiumThreshold);
    assertEq(spokeConfig.active, spokeConfigBefore.active);
    assertEq(spokeConfig.halted, spokeConfigBefore.halted);
  }

  function test_execute_hubAssetHalts_multiElement() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](2);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    halts[1] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub2()),
      underlying: address(weth)
    });
    payload.setHubAssetHalts(halts);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig1 = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertTrue(spokeConfig1.halted);

    IHub.SpokeConfig memory spokeConfig2 = hub2().getSpokeConfig(
      _getAssetId(1, 0),
      address(spoke1())
    );
    assertTrue(spokeConfig2.halted);
  }

  function test_execute_hubAssetDeactivations() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    payload.setHubAssetHalts(halts);
    payload.execute();

    payload = new AaveV4PayloadWrapper(IAaveV4ConfigEngine(address(engine)));
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(payload), 0);

    IAaveV4ConfigEngine.AssetDeactivation[]
      memory deactivations = new IAaveV4ConfigEngine.AssetDeactivation[](1);
    deactivations[0] = IAaveV4ConfigEngine.AssetDeactivation({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    payload.setHubAssetDeactivations(deactivations);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertFalse(spokeConfig.active);
  }

  function test_execute_hubAssetCapsResets() public {
    IAaveV4ConfigEngine.AssetCapsReset[] memory resets = new IAaveV4ConfigEngine.AssetCapsReset[](
      1
    );
    resets[0] = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    payload.setHubAssetCapsResets(resets);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertEq(spokeConfig.addCap, 0);
    assertEq(spokeConfig.drawCap, 0);
  }

  function test_execute_spokeReserveListings() public {
    uint256 newAssetId = _seedAsset(hub1(), irStrategy1(), address(newToken), 18);
    _seedSpokeOnAsset(hub1(), newAssetId, spoke1());

    address newPriceFeed = address(priceFeedNew);

    IAaveV4ConfigEngine.ReserveListing[] memory listings = new IAaveV4ConfigEngine.ReserveListing[](
      1
    );
    listings[0] = IAaveV4ConfigEngine.ReserveListing({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(newToken),
      priceSource: newPriceFeed,
      config: ISpoke.ReserveConfig({
        collateralRisk: 50_00,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      })
    });
    payload.setSpokeReserveListings(listings);

    uint256 reserveCountBefore = spoke1().getReserveCount();
    payload.execute();

    assertEq(spoke1().getReserveCount(), reserveCountBefore + 1);
  }

  function test_execute_spokeReserveConfigUpdates() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](1);
    updates[0] = _defaultReserveConfigUpdate();
    updates[0].collateralRisk = 75_00;
    payload.setSpokeReserveConfigUpdates(updates);

    payload.execute();

    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(_getReserveId(0, 0));
    assertEq(config.collateralRisk, 75_00);
  }

  function test_fuzz_execute_spokeReserveConfigUpdates(uint256 collateralRisk) public {
    collateralRisk = bound(collateralRisk, 0, 100_000);

    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](1);
    updates[0] = _defaultReserveConfigUpdate();
    updates[0].collateralRisk = collateralRisk;
    updates[0].paused = EngineFlags.KEEP_CURRENT;
    updates[0].frozen = EngineFlags.KEEP_CURRENT;
    updates[0].borrowable = EngineFlags.KEEP_CURRENT;
    updates[0].receiveSharesEnabled = EngineFlags.KEEP_CURRENT;
    updates[0].priceSource = EngineFlags.KEEP_CURRENT_ADDRESS;
    payload.setSpokeReserveConfigUpdates(updates);

    payload.execute();

    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(_getReserveId(0, 0));
    assertEq(config.collateralRisk, collateralRisk);
  }

  function test_execute_spokeLiquidationConfigUpdates() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](1);
    updates[0] = _defaultLiquidationConfigUpdate();
    updates[0].targetHealthFactor = 1.20e18;
    payload.setSpokeLiquidationConfigUpdates(updates);

    payload.execute();

    ISpoke.LiquidationConfig memory config = spoke1().getLiquidationConfig();
    assertEq(config.targetHealthFactor, updates[0].targetHealthFactor);
  }

  function test_fuzz_execute_spokeLiquidationConfigUpdates(uint256 targetHealthFactor) public {
    targetHealthFactor = bound(targetHealthFactor, 1e18, type(uint128).max);

    IAaveV4ConfigEngine.LiquidationConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      targetHealthFactor: targetHealthFactor,
      healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT
    });
    payload.setSpokeLiquidationConfigUpdates(updates);

    payload.execute();

    ISpoke.LiquidationConfig memory config = spoke1().getLiquidationConfig();
    assertEq(config.targetHealthFactor, uint128(targetHealthFactor));
  }

  function test_execute_spokeDynamicReserveConfigAdditions() public {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[]
      memory additions = new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](1);
    additions[0] = _defaultDynamicReserveConfigAddition();
    payload.setSpokeDynamicReserveConfigAdditions(additions);

    payload.execute();

    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.DynamicReserveConfig memory dynConfig = spoke1().getDynamicReserveConfig(reserveId, 1);
    assertEq(dynConfig.collateralFactor, additions[0].dynamicConfig.collateralFactor);
    assertEq(dynConfig.maxLiquidationBonus, additions[0].dynamicConfig.maxLiquidationBonus);
    assertEq(dynConfig.liquidationFee, additions[0].dynamicConfig.liquidationFee);
  }

  function test_execute_spokeDynamicReserveConfigUpdates() public {
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](1);
    updates[0] = _defaultDynamicReserveConfigUpdate();
    updates[0].collateralFactor = 90_00;
    updates[0].maxLiquidationBonus = 110_00;
    updates[0].liquidationFee = 5_00;
    payload.setSpokeDynamicReserveConfigUpdates(updates);

    payload.execute();

    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.DynamicReserveConfig memory dynConfig = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(dynConfig.collateralFactor, 90_00);
    assertEq(dynConfig.maxLiquidationBonus, 110_00);
    assertEq(dynConfig.liquidationFee, 5_00);
  }

  function test_fuzz_execute_spokeDynamicReserveConfigUpdates(
    uint256 collateralFactor,
    uint256 maxLiquidationBonus,
    uint256 liquidationFee
  ) public {
    collateralFactor = bound(collateralFactor, 1, 9_999);
    maxLiquidationBonus = bound(
      maxLiquidationBonus,
      10_000,
      (10_000 * 10_000 - 10_000) / collateralFactor
    );
    liquidationFee = bound(liquidationFee, 0, 10_000);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](1);
    updates[0] = _defaultDynamicReserveConfigUpdate();
    updates[0].collateralFactor = collateralFactor;
    updates[0].maxLiquidationBonus = maxLiquidationBonus;
    updates[0].liquidationFee = liquidationFee;
    payload.setSpokeDynamicReserveConfigUpdates(updates);

    payload.execute();

    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.DynamicReserveConfig memory dynConfig = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(dynConfig.collateralFactor, collateralFactor);
    assertEq(dynConfig.maxLiquidationBonus, maxLiquidationBonus);
    assertEq(dynConfig.liquidationFee, liquidationFee);
  }

  function test_execute_spokePositionManagerUpdates() public {
    IAaveV4ConfigEngine.PositionManagerUpdate[]
      memory updates = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      positionManager: address(payloadPositionManager),
      active: true
    });
    payload.setSpokePositionManagerUpdates(updates);

    payload.execute();

    assertTrue(spoke1().isPositionManagerActive(address(payloadPositionManager)));
  }

  function test_execute_accessManagerRoleMemberships_revoke() public {
    IAaveV4ConfigEngine.RoleMembership[]
      memory grantMemberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    grantMemberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: true,
      executionDelay: 0
    });
    payload.setAccessManagerRoleMemberships(grantMemberships);
    payload.execute();

    (bool isMember, ) = accessManager.hasRole(Roles.HUB_CONFIGURATOR_ROLE, ACCOUNT);
    assertTrue(isMember);

    payload = new AaveV4PayloadWrapper(IAaveV4ConfigEngine(address(engine)));
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(payload), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(payload), 0);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(payload), 0);
    vm.stopPrank();

    IAaveV4ConfigEngine.RoleMembership[]
      memory revokeMemberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    revokeMemberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: false,
      executionDelay: 0
    });
    payload.setAccessManagerRoleMemberships(revokeMemberships);
    payload.execute();

    (isMember, ) = accessManager.hasRole(Roles.HUB_CONFIGURATOR_ROLE, ACCOUNT);
    assertFalse(isMember);
  }

  function test_execute_accessManagerRoleUpdates() public {
    IAaveV4ConfigEngine.RoleUpdate[] memory updates = new IAaveV4ConfigEngine.RoleUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.RoleUpdate({
      authority: address(accessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      admin: Roles.HUB_CONFIGURATOR_ROLE,
      guardian: Roles.HUB_DEFICIT_ELIMINATOR_ROLE,
      grantDelay: 3600,
      label: 'FEE_UPDATER',
      labelUpdate: false
    });
    payload.setAccessManagerRoleUpdates(updates);

    payload.execute();

    assertEq(accessManager.getRoleAdmin(Roles.HUB_CONFIGURATOR_ROLE), Roles.HUB_CONFIGURATOR_ROLE);
    assertEq(
      accessManager.getRoleGuardian(Roles.HUB_CONFIGURATOR_ROLE),
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE
    );
  }

  function test_execute_accessManagerTargetFunctionRoleUpdates() public {
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[]
      memory updates = new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](1);
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = bytes4(0xdeadbeef);
    updates[0] = IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
      authority: address(accessManager),
      target: TARGET,
      selectors: selectors,
      roleId: Roles.HUB_CONFIGURATOR_ROLE
    });
    payload.setAccessManagerTargetFunctionRoleUpdates(updates);

    payload.execute();

    assertEq(
      accessManager.getTargetFunctionRole(TARGET, selectors[0]),
      Roles.HUB_CONFIGURATOR_ROLE
    );
  }

  function test_execute_accessManagerTargetAdminDelayUpdates() public {
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[]
      memory updates = new IAaveV4ConfigEngine.TargetAdminDelayUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.TargetAdminDelayUpdate({
      authority: address(accessManager),
      target: TARGET,
      newDelay: 7200
    });
    payload.setAccessManagerTargetAdminDelayUpdates(updates);

    payload.execute();

    vm.warp(block.timestamp + 5 days);
    assertEq(accessManager.getTargetAdminDelay(TARGET), 7200);
  }

  function test_execute_hubSpokeDeactivations() public {
    IAaveV4ConfigEngine.SpokeDeactivation[]
      memory deactivations = new IAaveV4ConfigEngine.SpokeDeactivation[](1);
    deactivations[0] = IAaveV4ConfigEngine.SpokeDeactivation({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      spoke: address(spoke1())
    });
    payload.setHubSpokeDeactivations(deactivations);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertFalse(spokeConfig.active);
  }

  function test_execute_hubSpokeCapsResets() public {
    IAaveV4ConfigEngine.SpokeCapsReset[] memory resets = new IAaveV4ConfigEngine.SpokeCapsReset[](
      1
    );
    resets[0] = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      spoke: address(spoke1())
    });
    payload.setHubSpokeCapsResets(resets);

    payload.execute();

    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, 0),
      address(spoke1())
    );
    assertEq(spokeConfig.addCap, 0);
    assertEq(spokeConfig.drawCap, 0);
  }

  function test_constructor_revertsOnZeroAddress() public {
    vm.expectRevert(AaveV4Payload.InvalidConfigEngine.selector);
    new AaveV4PayloadWrapper(IAaveV4ConfigEngine(address(0)));
  }

  function test_execute_positionManagerSpokeRegistrations() public {
    IAaveV4ConfigEngine.SpokeRegistration[]
      memory regs = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    regs[0] = IAaveV4ConfigEngine.SpokeRegistration({
      positionManager: address(payloadPositionManager),
      spoke: address(spoke1()),
      registered: true
    });
    payload.setPositionManagerSpokeRegistrations(regs);

    payload.execute();

    assertTrue(payloadPositionManager.isSpokeRegistered(address(spoke1())));
  }

  function test_execute_positionManagerRoleRenouncements() public {
    PositionManagerBaseWrapper freshPm = new PositionManagerBaseWrapper(address(payload));
    IAaveV4ConfigEngine.SpokeRegistration[]
      memory regs = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    regs[0] = IAaveV4ConfigEngine.SpokeRegistration({
      positionManager: address(freshPm),
      spoke: address(spoke1()),
      registered: true
    });
    payload.setPositionManagerSpokeRegistrations(regs);

    IAaveV4ConfigEngine.PositionManagerUpdate[]
      memory pmUpdates = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    pmUpdates[0] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      positionManager: address(freshPm),
      active: true
    });
    payload.setSpokePositionManagerUpdates(pmUpdates);
    payload.execute();

    vm.prank(USER);
    spoke1().setUserPositionManager(address(freshPm), true);
    assertTrue(spoke1().isPositionManager(USER, address(freshPm)));

    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[]
      memory renouncements = new IAaveV4ConfigEngine.PositionManagerRoleRenouncement[](1);
    renouncements[0] = IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
      positionManager: address(freshPm),
      spoke: address(spoke1()),
      user: USER
    });
    payload.setPositionManagerRoleRenouncements(renouncements);

    vm.expectEmit(address(spoke1()));
    emit ISpoke.SetUserPositionManager(USER, address(freshPm), false);
    payload.execute();

    // the position manager is still active on the Spoke, so isPositionManager being false
    // proves the approval itself was cleared
    assertTrue(spoke1().isPositionManagerActive(address(freshPm)));
    assertFalse(spoke1().isPositionManager(USER, address(freshPm)));
  }

  function test_execute_positionManagerDeregistrationWithRenouncement() public {
    PositionManagerBaseWrapper freshPm = new PositionManagerBaseWrapper(address(payload));
    IAaveV4ConfigEngine.SpokeRegistration[]
      memory regs = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    regs[0] = IAaveV4ConfigEngine.SpokeRegistration({
      positionManager: address(freshPm),
      spoke: address(spoke1()),
      registered: true
    });
    payload.setPositionManagerSpokeRegistrations(regs);

    IAaveV4ConfigEngine.PositionManagerUpdate[]
      memory pmUpdates = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    pmUpdates[0] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      positionManager: address(freshPm),
      active: true
    });
    payload.setSpokePositionManagerUpdates(pmUpdates);
    payload.execute();

    vm.prank(USER);
    spoke1().setUserPositionManager(address(freshPm), true);
    assertTrue(spoke1().isPositionManager(USER, address(freshPm)));

    // single payload winding down the position manager: renounce USER's role and deregister the Spoke
    regs[0].registered = false;
    payload.setPositionManagerSpokeRegistrations(regs);
    payload.setSpokePositionManagerUpdates(new IAaveV4ConfigEngine.PositionManagerUpdate[](0));

    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[]
      memory renouncements = new IAaveV4ConfigEngine.PositionManagerRoleRenouncement[](1);
    renouncements[0] = IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
      positionManager: address(freshPm),
      spoke: address(spoke1()),
      user: USER
    });
    payload.setPositionManagerRoleRenouncements(renouncements);

    vm.expectEmit(address(spoke1()));
    emit ISpoke.SetUserPositionManager(USER, address(freshPm), false);
    payload.execute();

    // the position manager is still active on the Spoke, so isPositionManager being false
    // proves the approval itself was cleared
    assertTrue(spoke1().isPositionManagerActive(address(freshPm)));
    assertFalse(spoke1().isPositionManager(USER, address(freshPm)));
    assertFalse(freshPm.isSpokeRegistered(address(spoke1())));
  }

  function test_execute_positionManagerRegistrationWithRenouncement_reverts() public {
    PositionManagerBaseWrapper freshPm = new PositionManagerBaseWrapper(address(payload));

    // single payload bundling the Spoke registration and the role renouncement.
    // renouncements run before registrations, so the renounce executes while the
    // Spoke is not yet registered and reverts.
    IAaveV4ConfigEngine.SpokeRegistration[]
      memory regs = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    regs[0] = IAaveV4ConfigEngine.SpokeRegistration({
      positionManager: address(freshPm),
      spoke: address(spoke1()),
      registered: true
    });
    payload.setPositionManagerSpokeRegistrations(regs);

    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[]
      memory renouncements = new IAaveV4ConfigEngine.PositionManagerRoleRenouncement[](1);
    renouncements[0] = IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
      positionManager: address(freshPm),
      spoke: address(spoke1()),
      user: USER
    });
    payload.setPositionManagerRoleRenouncements(renouncements);

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    payload.execute();
  }

  // --- Unauthorized execute tests ---

  function test_execute_reverts_hubAction_withoutHubConfiguratorRole() public {
    AaveV4PayloadWrapper freshPayload = new AaveV4PayloadWrapper(
      IAaveV4ConfigEngine(address(engine))
    );

    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(freshPayload), 0);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(freshPayload), 0);
    vm.stopPrank();

    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    freshPayload.setHubAssetHalts(halts);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManaged.AccessManagedUnauthorized.selector,
        address(freshPayload)
      )
    );
    freshPayload.execute();
  }

  function test_execute_reverts_spokeAction_withoutSpokeConfiguratorRole() public {
    AaveV4PayloadWrapper freshPayload = new AaveV4PayloadWrapper(
      IAaveV4ConfigEngine(address(engine))
    );

    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_ROLE, address(freshPayload), 0);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(freshPayload), 0);
    vm.stopPrank();

    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](1);
    updates[0] = _defaultReserveConfigUpdate();
    updates[0].collateralRisk = 60_00;
    freshPayload.setSpokeReserveConfigUpdates(updates);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManaged.AccessManagedUnauthorized.selector,
        address(freshPayload)
      )
    );
    freshPayload.execute();
  }

  function test_execute_reverts_accessManagerAction_withoutDefaultAdminRole() public {
    AaveV4PayloadWrapper freshPayload = new AaveV4PayloadWrapper(
      IAaveV4ConfigEngine(address(engine))
    );

    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_ROLE, address(freshPayload), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(freshPayload), 0);
    vm.stopPrank();

    IAaveV4ConfigEngine.RoleMembership[]
      memory memberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    memberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: true,
      executionDelay: 0
    });
    freshPayload.setAccessManagerRoleMemberships(memberships);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(freshPayload),
        Roles.ACCESS_MANAGER_ADMIN_ROLE
      )
    );
    freshPayload.execute();
  }

  function test_execute_reverts_positionManagerAction_withoutOwnership() public {
    AaveV4PayloadWrapper freshPayload = new AaveV4PayloadWrapper(
      IAaveV4ConfigEngine(address(engine))
    );

    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_ROLE, address(freshPayload), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(freshPayload), 0);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(freshPayload), 0);
    vm.stopPrank();

    PositionManagerBaseWrapper deadPm = new PositionManagerBaseWrapper(address(0xdead));

    IAaveV4ConfigEngine.SpokeRegistration[]
      memory regs = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    regs[0] = IAaveV4ConfigEngine.SpokeRegistration({
      positionManager: address(deadPm),
      spoke: address(spoke1()),
      registered: true
    });
    freshPayload.setPositionManagerSpokeRegistrations(regs);

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(freshPayload))
    );
    freshPayload.execute();
  }

  // --- Cross-hub/cross-spoke consistency tests ---

  function test_execute_crossHub_assetConfigUpdates() public {
    uint256 hub1WethId = _getAssetId(0, TOKEN_WETH);
    uint256 hub2UsdxId = _getAssetId(1, TOKEN_USDX);

    IHub.AssetConfig memory hub1WethBefore = hub1().getAssetConfig(hub1WethId);
    IHub.AssetConfig memory hub2UsdxBefore = hub2().getAssetConfig(hub2UsdxId);

    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](2);
    updates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      liquidityFee: 8_00,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    updates[1] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub2()),
      underlying: address(usdx),
      liquidityFee: 12_00,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    payload.setHubAssetConfigUpdates(updates);

    payload.execute();

    IHub.AssetConfig memory hub1WethAfter = hub1().getAssetConfig(hub1WethId);
    assertEq(hub1WethAfter.liquidityFee, 8_00);

    IHub.AssetConfig memory hub2UsdxAfter = hub2().getAssetConfig(hub2UsdxId);
    assertEq(hub2UsdxAfter.liquidityFee, 12_00);

    IHub.AssetConfig memory hub1UsdxAfter = hub1().getAssetConfig(_getAssetId(0, TOKEN_USDX));
    assertEq(hub1UsdxAfter.liquidityFee, hub1WethBefore.liquidityFee);

    IHub.AssetConfig memory hub2WethAfter = hub2().getAssetConfig(_getAssetId(1, TOKEN_WETH));
    assertEq(hub2WethAfter.liquidityFee, hub2UsdxBefore.liquidityFee);
  }

  function test_execute_crossSpoke_reserveConfigUpdates() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](3);

    updates[0] = _defaultReserveConfigUpdate();
    updates[0].spoke = address(spoke1());
    updates[0].underlying = address(weth);
    updates[0].collateralRisk = 60_00;
    updates[0].paused = EngineFlags.KEEP_CURRENT;
    updates[0].frozen = EngineFlags.KEEP_CURRENT;
    updates[0].borrowable = EngineFlags.KEEP_CURRENT;
    updates[0].receiveSharesEnabled = EngineFlags.KEEP_CURRENT;
    updates[0].priceSource = EngineFlags.KEEP_CURRENT_ADDRESS;

    updates[1] = _defaultReserveConfigUpdate();
    updates[1].spoke = address(spoke2());
    updates[1].underlying = address(usdx);
    updates[1].collateralRisk = 70_00;
    updates[1].paused = EngineFlags.KEEP_CURRENT;
    updates[1].frozen = EngineFlags.KEEP_CURRENT;
    updates[1].borrowable = EngineFlags.KEEP_CURRENT;
    updates[1].receiveSharesEnabled = EngineFlags.KEEP_CURRENT;
    updates[1].priceSource = EngineFlags.KEEP_CURRENT_ADDRESS;

    updates[2] = _defaultReserveConfigUpdate();
    updates[2].spoke = address(spoke3());
    updates[2].underlying = address(dai);
    updates[2].collateralRisk = 80_00;
    updates[2].paused = EngineFlags.KEEP_CURRENT;
    updates[2].frozen = EngineFlags.KEEP_CURRENT;
    updates[2].borrowable = EngineFlags.KEEP_CURRENT;
    updates[2].receiveSharesEnabled = EngineFlags.KEEP_CURRENT;
    updates[2].priceSource = EngineFlags.KEEP_CURRENT_ADDRESS;

    payload.setSpokeReserveConfigUpdates(updates);

    payload.execute();

    assertEq(spoke1().getReserveConfig(_getReserveId(0, TOKEN_WETH)).collateralRisk, 60_00);
    assertEq(spoke2().getReserveConfig(_getReserveId(1, TOKEN_USDX)).collateralRisk, 70_00);
    assertEq(spoke3().getReserveConfig(_getReserveId(2, TOKEN_DAI)).collateralRisk, 80_00);
  }

  function test_execute_crossHubAndSpoke_mixedActions() public {
    // Hub: halt WETH on hub1
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth)
    });
    payload.setHubAssetHalts(halts);

    // Hub: update USDX liquidityFee on hub2
    IAaveV4ConfigEngine.AssetConfigUpdate[]
      memory assetUpdates = new IAaveV4ConfigEngine.AssetConfigUpdate[](1);
    assetUpdates[0] = IAaveV4ConfigEngine.AssetConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub2()),
      underlying: address(usdx),
      liquidityFee: 15_00,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: _keepCurrentIrData(),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    payload.setHubAssetConfigUpdates(assetUpdates);

    // Spoke: update collateralRisk for WETH on spoke1 + DAI on spoke2
    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory reserveUpdates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](2);
    reserveUpdates[0] = _defaultReserveConfigUpdate();
    reserveUpdates[0].spoke = address(spoke1());
    reserveUpdates[0].underlying = address(weth);
    reserveUpdates[0].collateralRisk = 55_00;
    reserveUpdates[0].paused = EngineFlags.KEEP_CURRENT;
    reserveUpdates[0].frozen = EngineFlags.KEEP_CURRENT;
    reserveUpdates[0].borrowable = EngineFlags.KEEP_CURRENT;
    reserveUpdates[0].receiveSharesEnabled = EngineFlags.KEEP_CURRENT;
    reserveUpdates[0].priceSource = EngineFlags.KEEP_CURRENT_ADDRESS;

    reserveUpdates[1] = _defaultReserveConfigUpdate();
    reserveUpdates[1].spoke = address(spoke2());
    reserveUpdates[1].underlying = address(dai);
    reserveUpdates[1].collateralRisk = 65_00;
    reserveUpdates[1].paused = EngineFlags.KEEP_CURRENT;
    reserveUpdates[1].frozen = EngineFlags.KEEP_CURRENT;
    reserveUpdates[1].borrowable = EngineFlags.KEEP_CURRENT;
    reserveUpdates[1].receiveSharesEnabled = EngineFlags.KEEP_CURRENT;
    reserveUpdates[1].priceSource = EngineFlags.KEEP_CURRENT_ADDRESS;

    payload.setSpokeReserveConfigUpdates(reserveUpdates);

    // AccessManager: grant HUB_CONFIGURATOR_ROLE to ACCOUNT
    IAaveV4ConfigEngine.RoleMembership[]
      memory memberships = new IAaveV4ConfigEngine.RoleMembership[](1);
    memberships[0] = IAaveV4ConfigEngine.RoleMembership({
      authority: address(accessManager),
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: ACCOUNT,
      granted: true,
      executionDelay: 0
    });
    payload.setAccessManagerRoleMemberships(memberships);

    // PositionManager: register spoke1 on payloadPositionManager
    IAaveV4ConfigEngine.SpokeRegistration[]
      memory regs = new IAaveV4ConfigEngine.SpokeRegistration[](1);
    regs[0] = IAaveV4ConfigEngine.SpokeRegistration({
      positionManager: address(payloadPositionManager),
      spoke: address(spoke1()),
      registered: true
    });
    payload.setPositionManagerSpokeRegistrations(regs);

    payload.execute();

    // Assert all 6 state changes
    IHub.SpokeConfig memory spokeConfig = hub1().getSpokeConfig(
      _getAssetId(0, TOKEN_WETH),
      address(spoke1())
    );
    assertTrue(spokeConfig.halted);

    IHub.AssetConfig memory hub2Usdx = hub2().getAssetConfig(_getAssetId(1, TOKEN_USDX));
    assertEq(hub2Usdx.liquidityFee, 15_00);

    assertEq(spoke1().getReserveConfig(_getReserveId(0, TOKEN_WETH)).collateralRisk, 55_00);
    assertEq(spoke2().getReserveConfig(_getReserveId(1, TOKEN_DAI)).collateralRisk, 65_00);

    (bool isMember, ) = accessManager.hasRole(Roles.HUB_CONFIGURATOR_ROLE, ACCOUNT);
    assertTrue(isMember);

    assertTrue(payloadPositionManager.isSpokeRegistered(address(spoke1())));
  }

  function test_execute_crossHub_spokeConfigUpdates() public {
    IAaveV4ConfigEngine.SpokeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](2);
    updates[0] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(weth),
      spoke: address(spoke1()),
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    updates[1] = IAaveV4ConfigEngine.SpokeConfigUpdate({
      hubConfigurator: hubConfigurator,
      hub: address(hub2()),
      underlying: address(usdx),
      spoke: address(spoke2()),
      addCap: 2000,
      drawCap: 1000,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    payload.setHubSpokeConfigUpdates(updates);

    payload.execute();

    IHub.SpokeConfig memory sc1 = hub1().getSpokeConfig(
      _getAssetId(0, TOKEN_WETH),
      address(spoke1())
    );
    assertEq(sc1.addCap, 1000);
    assertEq(sc1.drawCap, 500);

    IHub.SpokeConfig memory sc2 = hub2().getSpokeConfig(
      _getAssetId(1, TOKEN_USDX),
      address(spoke2())
    );
    assertEq(sc2.addCap, 2000);
    assertEq(sc2.drawCap, 1000);
  }
}
