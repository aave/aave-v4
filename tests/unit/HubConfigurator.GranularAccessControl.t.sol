// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubConfiguratorGranularAccessControlTest is HubBase {
  using SafeCast for uint256;

  // Granular role constants
  uint64 constant ASSET_MANAGER_ROLE = 100;
  uint64 constant SPOKE_MANAGER_ROLE = 101;

  // Role holders
  address ASSET_MANAGER = makeAddr('ASSET_MANAGER');
  address SPOKE_MANAGER = makeAddr('SPOKE_MANAGER');

  HubConfigurator hubConfigurator;
  IAccessManager manager;

  uint256 assetId;
  address spokeAddr;
  bytes encodedIrData;

  // Arrays storing calldata for each role's functions
  bytes[] internal assetManagerCalldata;
  bytes[] internal spokeManagerCalldata;

  function setUp() public virtual override {
    super.setUp();

    manager = IAccessManager(hub1.authority());
    hubConfigurator = new HubConfigurator(address(manager));

    // Grant HUB_ADMIN_ROLE to hubConfigurator so it can call hub functions
    vm.startPrank(ADMIN);
    manager.grantRole(Roles.HUB_ADMIN_ROLE, address(hubConfigurator), 0);

    // Grant granular roles to role holders
    manager.grantRole(ASSET_MANAGER_ROLE, ASSET_MANAGER, 0);
    manager.grantRole(SPOKE_MANAGER_ROLE, SPOKE_MANAGER, 0);

    // Set up ASSET_MANAGER_ROLE permissions (11 functions)
    bytes4[] memory assetSelectors = new bytes4[](11);
    assetSelectors[0] = IHubConfigurator.addAsset.selector;
    assetSelectors[1] = IHubConfigurator.addAssetWithDecimals.selector;
    assetSelectors[2] = IHubConfigurator.updateLiquidityFee.selector;
    assetSelectors[3] = IHubConfigurator.updateFeeReceiver.selector;
    assetSelectors[4] = IHubConfigurator.updateFeeConfig.selector;
    assetSelectors[5] = IHubConfigurator.updateInterestRateStrategy.selector;
    assetSelectors[6] = IHubConfigurator.updateReinvestmentController.selector;
    assetSelectors[7] = IHubConfigurator.updateInterestRateData.selector;
    assetSelectors[8] = IHubConfigurator.resetAssetCaps.selector;
    assetSelectors[9] = IHubConfigurator.deactivateAsset.selector;
    assetSelectors[10] = IHubConfigurator.haltAsset.selector;
    manager.setTargetFunctionRole(address(hubConfigurator), assetSelectors, ASSET_MANAGER_ROLE);

    // Set up SPOKE_MANAGER_ROLE permissions (11 functions)
    bytes4[] memory spokeSelectors = new bytes4[](11);
    spokeSelectors[0] = IHubConfigurator.addSpoke.selector;
    spokeSelectors[1] = IHubConfigurator.addSpokeToAssets.selector;
    spokeSelectors[2] = IHubConfigurator.updateSpokeActive.selector;
    spokeSelectors[3] = IHubConfigurator.updateSpokeHalted.selector;
    spokeSelectors[4] = IHubConfigurator.updateSpokeSupplyCap.selector;
    spokeSelectors[5] = IHubConfigurator.updateSpokeDrawCap.selector;
    spokeSelectors[6] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    spokeSelectors[7] = IHubConfigurator.updateSpokeCaps.selector;
    spokeSelectors[8] = IHubConfigurator.deactivateSpoke.selector;
    spokeSelectors[9] = IHubConfigurator.haltSpoke.selector;
    spokeSelectors[10] = IHubConfigurator.resetSpokeCaps.selector;
    manager.setTargetFunctionRole(address(hubConfigurator), spokeSelectors, SPOKE_MANAGER_ROLE);

    vm.stopPrank();

    // Set up test data
    assetId = daiAssetId;
    spokeAddr = address(spoke1);
    encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseVariableBorrowRate: 5_00,
        variableRateSlope1: 5_00,
        variableRateSlope2: 5_00
      })
    );

    // Build calldata arrays for testing
    _buildAssetManagerCalldata();
    _buildSpokeManagerCalldata();
  }

  function _buildAssetManagerCalldata() internal {
    address newFeeReceiver = makeAddr('NEW_FEE_RECEIVER');
    address newIrStrategy = address(new AssetInterestRateStrategy(address(hub1)));
    address newController = makeAddr('NEW_REINVESTMENT_CONTROLLER');

    // Note: Skipping addAsset overloads as they require more complex setup
    assetManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.updateLiquidityFee, (address(hub1), assetId, 10_00))
    );
    assetManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.updateFeeReceiver, (address(hub1), assetId, newFeeReceiver))
    );
    assetManagerCalldata.push(
      abi.encodeCall(
        IHubConfigurator.updateFeeConfig,
        (address(hub1), assetId, 5_00, newFeeReceiver)
      )
    );
    assetManagerCalldata.push(
      abi.encodeCall(
        IHubConfigurator.updateInterestRateStrategy,
        (address(hub1), assetId, newIrStrategy, encodedIrData)
      )
    );
    assetManagerCalldata.push(
      abi.encodeCall(
        IHubConfigurator.updateReinvestmentController,
        (address(hub1), assetId, newController)
      )
    );
    assetManagerCalldata.push(
      abi.encodeCall(
        IHubConfigurator.updateInterestRateData,
        (address(hub1), assetId, encodedIrData)
      )
    );
    assetManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.resetAssetCaps, (address(hub1), assetId))
    );
    assetManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.deactivateAsset, (address(hub1), assetId))
    );
    assetManagerCalldata.push(abi.encodeCall(IHubConfigurator.haltAsset, (address(hub1), assetId)));
  }

  function _buildSpokeManagerCalldata() internal {
    address newSpoke = makeAddr('NEW_SPOKE');
    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: 0
    });

    uint256[] memory assetIds = new uint256[](1);
    assetIds[0] = assetId;
    IHub.SpokeConfig[] memory configs = new IHub.SpokeConfig[](1);
    configs[0] = config;

    spokeManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.addSpoke, (address(hub1), newSpoke, assetId, config))
    );
    spokeManagerCalldata.push(
      abi.encodeCall(
        IHubConfigurator.addSpokeToAssets,
        (address(hub1), makeAddr('NEW_SPOKE_2'), assetIds, configs)
      )
    );
    spokeManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.updateSpokeActive, (address(hub1), assetId, spokeAddr, false))
    );
    spokeManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.updateSpokeHalted, (address(hub1), assetId, spokeAddr, true))
    );
    spokeManagerCalldata.push(
      abi.encodeCall(
        IHubConfigurator.updateSpokeSupplyCap,
        (address(hub1), assetId, spokeAddr, 5000)
      )
    );
    spokeManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.updateSpokeDrawCap, (address(hub1), assetId, spokeAddr, 2500))
    );
    spokeManagerCalldata.push(
      abi.encodeCall(
        IHubConfigurator.updateSpokeRiskPremiumThreshold,
        (address(hub1), assetId, spokeAddr, 500)
      )
    );
    spokeManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.updateSpokeCaps, (address(hub1), assetId, spokeAddr, 100, 50))
    );
    spokeManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.deactivateSpoke, (address(hub1), spokeAddr))
    );
    spokeManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.haltSpoke, (address(hub1), spokeAddr))
    );
    spokeManagerCalldata.push(
      abi.encodeCall(IHubConfigurator.resetSpokeCaps, (address(hub1), spokeAddr))
    );
  }

  function test_fuzz_unauthorized_cannotCall_assetManagerMethods(address caller) public {
    vm.assume(caller != ASSET_MANAGER);
    vm.assume(caller != address(0));

    for (uint256 i = 0; i < assetManagerCalldata.length; ++i) {
      vm.prank(caller);
      (bool ok, bytes memory ret) = address(hubConfigurator).call(assetManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    }
  }

  function test_fuzz_unauthorized_cannotCall_spokeManagerMethods(address caller) public {
    vm.assume(caller != SPOKE_MANAGER);
    vm.assume(caller != address(0));

    for (uint256 i = 0; i < spokeManagerCalldata.length; ++i) {
      vm.prank(caller);
      (bool ok, bytes memory ret) = address(hubConfigurator).call(spokeManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    }
  }

  function test_assetManager_cannotCall_anySpokeManagerMethod() public {
    for (uint256 i = 0; i < spokeManagerCalldata.length; ++i) {
      vm.prank(ASSET_MANAGER);
      (bool ok, bytes memory ret) = address(hubConfigurator).call(spokeManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, ASSET_MANAGER)
      );
    }
  }

  function test_spokeManager_cannotCall_anyAssetManagerMethod() public {
    for (uint256 i = 0; i < assetManagerCalldata.length; ++i) {
      vm.prank(SPOKE_MANAGER);
      (bool ok, bytes memory ret) = address(hubConfigurator).call(assetManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, SPOKE_MANAGER)
      );
    }
  }

  function test_assetManager_canCall_updateLiquidityFee() public {
    vm.prank(ASSET_MANAGER);
    hubConfigurator.updateLiquidityFee(address(hub1), assetId, 10_00);

    assertEq(hub1.getAssetConfig(assetId).liquidityFee, 10_00);
  }

  function test_assetManager_canCall_resetAssetCaps() public {
    vm.prank(ASSET_MANAGER);
    hubConfigurator.resetAssetCaps(address(hub1), assetId);

    IHub.SpokeConfig memory config = hub1.getSpokeConfig(assetId, spokeAddr);
    assertEq(config.addCap, 0);
    assertEq(config.drawCap, 0);
  }

  function test_assetManager_canCall_deactivateAsset() public {
    vm.prank(ASSET_MANAGER);
    hubConfigurator.deactivateAsset(address(hub1), assetId);

    IHub.SpokeConfig memory config = hub1.getSpokeConfig(assetId, spokeAddr);
    assertFalse(config.active);
  }

  function test_assetManager_canCall_haltAsset() public {
    vm.prank(ASSET_MANAGER);
    hubConfigurator.haltAsset(address(hub1), assetId);

    IHub.SpokeConfig memory config = hub1.getSpokeConfig(assetId, spokeAddr);
    assertTrue(config.halted);
  }

  function test_spokeManager_canCall_addSpoke() public {
    address newSpoke = makeAddr('NEW_SPOKE_TEST');
    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: 0
    });

    vm.prank(SPOKE_MANAGER);
    hubConfigurator.addSpoke(address(hub1), newSpoke, assetId, config);

    assertTrue(hub1.isSpokeListed(assetId, newSpoke));
  }

  function test_spokeManager_canCall_updateSpokeActive() public {
    vm.prank(SPOKE_MANAGER);
    hubConfigurator.updateSpokeActive(address(hub1), assetId, spokeAddr, false);

    assertFalse(hub1.getSpokeConfig(assetId, spokeAddr).active);
  }

  function test_spokeManager_canCall_updateSpokeHalted() public {
    vm.prank(SPOKE_MANAGER);
    hubConfigurator.updateSpokeHalted(address(hub1), assetId, spokeAddr, true);

    assertTrue(hub1.getSpokeConfig(assetId, spokeAddr).halted);
  }

  function test_spokeManager_canCall_updateSpokeCaps() public {
    vm.prank(SPOKE_MANAGER);
    hubConfigurator.updateSpokeCaps(address(hub1), assetId, spokeAddr, 100, 50);

    IHub.SpokeConfig memory config = hub1.getSpokeConfig(assetId, spokeAddr);
    assertEq(config.addCap, 100);
    assertEq(config.drawCap, 50);
  }

  function test_spokeManager_canCall_resetSpokeCaps() public {
    vm.prank(SPOKE_MANAGER);
    hubConfigurator.resetSpokeCaps(address(hub1), spokeAddr);

    for (uint256 i = 0; i < hub1.getAssetCount(); ++i) {
      if (hub1.isSpokeListed(i, spokeAddr)) {
        IHub.SpokeConfig memory config = hub1.getSpokeConfig(i, spokeAddr);
        assertEq(config.addCap, 0);
        assertEq(config.drawCap, 0);
      }
    }
  }
}
