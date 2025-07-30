// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract HubConfiguratorTest is LiquidityHubBase {
  HubConfigurator public hubConfigurator;

  address public HUB_CONFIGURATOR_ADMIN = makeAddr('HUB_CONFIGURATOR_ADMIN');
  uint256 public assetId;
  bytes public encodedIrData;

  address[4] public spokeAddresses;
  address spoke;

  function setUp() public virtual override {
    super.setUp();
    hubConfigurator = new HubConfigurator(HUB_CONFIGURATOR_ADMIN);
    IAccessManager accessManager = IAccessManager(hub.authority());
    // Grant hubConfigurator hub admin role with 0 delay
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(hubConfigurator), 0);
    assetId = daiAssetId;
    encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    spokeAddresses = [address(spoke1), address(spoke2), address(spoke3), address(treasurySpoke)];
    spoke = address(spoke1);
  }

  function test_addAsset_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: uint8(vm.randomUint()),
      feeReceiver: vm.randomAddress(),
      interestRateStrategy: vm.randomAddress(),
      encodedIrData: encodedIrData
    });
  }

  function test_addAsset_reverts_invalidIrData() public {
    vm.expectRevert();
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: uint8(10),
      feeReceiver: vm.randomAddress(),
      interestRateStrategy: vm.randomAddress(),
      encodedIrData: abi.encode('invalid')
    });
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = uint8(bound(decimals, hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, type(uint8).max));

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector, address(hub));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    _addAsset(
      fetchErc20Decimals,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint16 optimalUsageRatio,
    uint32 baseVariableBorrowRate,
    uint32 variableRateSlope1,
    uint32 variableRateSlope2
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);

    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));
    optimalUsageRatio = uint16(bound(optimalUsageRatio, MIN_OPTIMAL_RATIO, MAX_OPTIMAL_RATIO));

    baseVariableBorrowRate = uint32(bound(baseVariableBorrowRate, 0, MAX_BORROW_RATE / 3));
    uint32 remainingAfterBase = uint32(MAX_BORROW_RATE - baseVariableBorrowRate);
    variableRateSlope1 = uint32(bound(variableRateSlope1, 0, remainingAfterBase / 2));
    variableRateSlope2 = uint32(
      bound(
        variableRateSlope2,
        variableRateSlope1,
        MAX_BORROW_RATE - baseVariableBorrowRate - variableRateSlope1
      )
    );

    uint256 expectedAssetId = hub.getAssetCount();
    address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub)));

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: optimalUsageRatio,
        baseVariableBorrowRate: baseVariableBorrowRate,
        variableRateSlope1: variableRateSlope1,
        variableRateSlope2: variableRateSlope2
      })
    );

    DataTypes.AssetConfig memory expectedConfig = DataTypes.AssetConfig({
      liquidityFee: 0,
      feeReceiver: feeReceiver,
      irStrategy: interestRateStrategy
    });
    DataTypes.SpokeConfig memory expectedSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max,
      active: true
    });

    vm.expectCall(
      address(hub),
      abi.encodeCall(
        ILiquidityHub.addAsset,
        (underlying, decimals, feeReceiver, interestRateStrategy, encodedIrData)
      )
    );

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.addSpoke, (expectedAssetId, feeReceiver, expectedSpokeConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    uint256 assetId = _addAsset(
      fetchErc20Decimals,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );

    assertEq(assetId, expectedAssetId, 'asset id');
    assertEq(hub.getAssetCount(), assetId + 1, 'asset count');
    assertEq(hub.getAsset(assetId).decimals, decimals, 'asset decimals');
    assertEq(hub.getAssetConfig(assetId), expectedConfig);
    assertEq(hub.getSpokeConfig(assetId, feeReceiver), expectedSpokeConfig);
  }

  function test_updateLiquidityFee_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateLiquidityFee(address(hub), vm.randomUint(), vm.randomUint());
  }

  function test_updateLiquidityFee() public {
    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.liquidityFee = PercentageMath.PERCENTAGE_FACTOR - 1;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateLiquidityFee(address(hub), assetId, expectedConfig.liquidityFee);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateFeeReceiver_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateFeeReceiver(address(hub), vm.randomUint(), vm.randomAddress());
  }

  function test_updateFeeReceiver_fuzz(address feeReceiver) public {
    assumeNotZeroAddress(feeReceiver);

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);

    if (feeReceiver != oldConfig.feeReceiver) {
      vm.expectCall(
        address(hub),
        abi.encodeCall(
          ILiquidityHub.updateSpokeConfig,
          (
            assetId,
            oldConfig.feeReceiver,
            DataTypes.SpokeConfig({
              supplyCap: 0,
              drawCap: 0,
              active: hub.getSpokeConfig(assetId, oldConfig.feeReceiver).active
            })
          )
        )
      );

      if (!hub.isSpokeListed(assetId, feeReceiver)) {
        vm.expectCall(
          address(hub),
          abi.encodeCall(
            ILiquidityHub.addSpoke,
            (
              assetId,
              feeReceiver,
              DataTypes.SpokeConfig({
                supplyCap: type(uint256).max,
                drawCap: type(uint256).max,
                active: true
              })
            )
          )
        );
      } else {
        vm.expectCall(
          address(hub),
          abi.encodeCall(
            ILiquidityHub.updateSpokeConfig,
            (
              assetId,
              feeReceiver,
              DataTypes.SpokeConfig({
                supplyCap: type(uint256).max,
                drawCap: type(uint256).max,
                active: hub.getSpokeConfig(assetId, feeReceiver).active
              })
            )
          )
        );
      }

      // same struct, renaming to expectedConfig
      DataTypes.AssetConfig memory expectedConfig = oldConfig;
      expectedConfig.feeReceiver = feeReceiver;

      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
      );

      vm.prank(HUB_CONFIGURATOR_ADMIN);
      hubConfigurator.updateFeeReceiver(address(hub), assetId, feeReceiver);

      assertEq(hub.getAssetConfig(assetId), expectedConfig);
    }
  }

  function test_updateFeeReceiver_Scenario() public {
    // set same fee receiver
    test_updateFeeReceiver_fuzz(address(treasurySpoke));
    // set new fee receiver
    test_updateFeeReceiver_fuzz(makeAddr('newFeeReceiver'));
    // set initial fee receiver
    test_updateFeeReceiver_fuzz(address(treasurySpoke));
  }

  function test_updateFeeConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateFeeConfig({
      hub: address(hub),
      assetId: vm.randomUint(),
      liquidityFee: vm.randomUint(),
      feeReceiver: vm.randomAddress()
    });
  }

  function test_updateFeeConfig_fuzz(uint256 liquidityFee, address feeReceiver) public {
    liquidityFee = bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    assumeNotZeroAddress(feeReceiver);

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);

    if (oldConfig.feeReceiver != feeReceiver) {
      vm.expectCall(
        address(hub),
        abi.encodeCall(
          ILiquidityHub.updateSpokeConfig,
          (
            assetId,
            oldConfig.feeReceiver,
            DataTypes.SpokeConfig({
              supplyCap: 0,
              drawCap: 0,
              active: hub.getSpokeConfig(assetId, oldConfig.feeReceiver).active
            })
          )
        )
      );

      if (!hub.isSpokeListed(assetId, feeReceiver)) {
        vm.expectCall(
          address(hub),
          abi.encodeCall(
            ILiquidityHub.addSpoke,
            (
              assetId,
              feeReceiver,
              DataTypes.SpokeConfig({
                supplyCap: type(uint256).max,
                drawCap: type(uint256).max,
                active: true
              })
            )
          )
        );
      } else {
        vm.expectCall(
          address(hub),
          abi.encodeCall(
            ILiquidityHub.updateSpokeConfig,
            (
              assetId,
              feeReceiver,
              DataTypes.SpokeConfig({
                supplyCap: type(uint256).max,
                drawCap: type(uint256).max,
                active: hub.getSpokeConfig(assetId, feeReceiver).active
              })
            )
          )
        );
      }
    }

    // same struct, renaming to expectedConfig
    DataTypes.AssetConfig memory expectedConfig = oldConfig;
    expectedConfig.feeReceiver = feeReceiver;
    expectedConfig.liquidityFee = liquidityFee;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFeeConfig(address(hub), assetId, liquidityFee, feeReceiver);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateFeeConfig_Scenario() public {
    // set same fee receiver and change liquidity fee
    test_updateFeeConfig_fuzz(18_00, address(treasurySpoke));
    // set new fee receiver and liquidity fee
    test_updateFeeConfig_fuzz(4_00, makeAddr('newFeeReceiver'));
    // set non-zero fee receiver
    test_updateFeeConfig_fuzz(0, makeAddr('newFeeReceiver2'));
    // set initial fee receiver and zero fee
    test_updateFeeConfig_fuzz(0, address(treasurySpoke));
  }

  function test_updateInterestRateStrategy_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateInterestRateStrategy(address(hub), vm.randomUint(), vm.randomAddress());
  }

  function test_updateInterestRateStrategy() public {
    address interestRateStrategy = makeAddr('newInterestRateStrategy');

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.irStrategy = interestRateStrategy;
    _mockInterestRateBps(interestRateStrategy, 5_00);

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateInterestRateStrategy(address(hub), assetId, interestRateStrategy);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateAssetConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateAssetConfig(
      address(hub),
      vm.randomUint(),
      DataTypes.AssetConfig({
        liquidityFee: 0,
        feeReceiver: vm.randomAddress(),
        irStrategy: vm.randomAddress()
      })
    );
  }

  function test_updateAssetConfig() public {
    DataTypes.AssetConfig memory newAssetConfig = DataTypes.AssetConfig({
      liquidityFee: 0,
      feeReceiver: makeAddr('newFeeReceiver'),
      irStrategy: makeAddr('newInterestRateStrategy')
    });
    _mockInterestRateBps(newAssetConfig.irStrategy, 5_00);

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);

    vm.expectCall(
      address(hub),
      abi.encodeCall(
        ILiquidityHub.updateSpokeConfig,
        (
          assetId,
          oldConfig.feeReceiver,
          DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0, active: true})
        )
      )
    );
    vm.expectCall(
      address(hub),
      abi.encodeCall(
        ILiquidityHub.addSpoke,
        (
          assetId,
          newAssetConfig.feeReceiver,
          DataTypes.SpokeConfig({
            supplyCap: type(uint256).max,
            drawCap: type(uint256).max,
            active: true
          })
        )
      )
    );
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, newAssetConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateAssetConfig(address(hub), assetId, newAssetConfig);

    assertEq(hub.getAssetConfig(assetId), newAssetConfig);
  }

  function test_freezeAsset_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.freezeAsset(address(hub), assetId);
  }

  function test_freezeAsset() public {
    for (uint256 i; i < spokeAddresses.length; i++) {
      DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spokeAddresses[i]);
      spokeConfig.supplyCap = 0;
      spokeConfig.drawCap = 0;
      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spokeAddresses[i], spokeConfig))
      );
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.freezeAsset(address(hub), assetId);

    for (uint256 i; i < spokeAddresses.length; i++) {
      DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spokeAddresses[i]);
      assertEq(spokeConfig.supplyCap, 0);
      assertEq(spokeConfig.drawCap, 0);
    }
  }

  function test_pauseAsset_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.pauseAsset(address(hub), assetId);
  }

  function test_pauseAsset() public {
    for (uint256 i; i < spokeAddresses.length; i++) {
      DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spokeAddresses[i]);
      spokeConfig.active = false;
      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spokeAddresses[i], spokeConfig))
      );
    }

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.pauseAsset(address(hub), assetId);

    for (uint256 i; i < spokeAddresses.length; i++) {
      DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spokeAddresses[i]);
      assertEq(spokeConfig.active, false);
    }
  }

  function test_addSpoke_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    DataTypes.SpokeConfig memory spokeConfig;
    hubConfigurator.addSpoke(address(hub), vm.randomAddress(), 0, spokeConfig);
  }

  function test_addSpoke() public {
    address newSpoke = makeAddr('newSpoke');

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 1,
      drawCap: 2,
      active: true
    });

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(daiAssetId, newSpoke);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpoke(address(hub), newSpoke, daiAssetId, daiSpokeConfig);

    assertEq(hub.getSpokeConfig(daiAssetId, newSpoke), daiSpokeConfig);
  }

  function test_addSpokeToAssets_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.addSpokeToAssets(
      address(hub),
      vm.randomAddress(),
      new uint256[](0),
      new DataTypes.SpokeConfig[](0)
    );
  }

  function test_addSpokeToAssets_revertsWith_MismatchedConfigs() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](3);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2, active: true});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4, active: true});
    spokeConfigs[2] = DataTypes.SpokeConfig({supplyCap: 5, drawCap: 6, active: true});

    vm.expectRevert(IHubConfigurator.MismatchedConfigs.selector);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpokeToAssets(address(hub), spoke, assetIds, spokeConfigs);
  }

  function test_addSpokeToAssets() public {
    address newSpoke = makeAddr('newSpoke');

    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 1,
      drawCap: 2,
      active: true
    });
    DataTypes.SpokeConfig memory wethSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 3,
      drawCap: 4,
      active: true
    });

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = daiSpokeConfig;
    spokeConfigs[1] = wethSpokeConfig;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(daiAssetId, newSpoke);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(wethAssetId, newSpoke);
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpokeToAssets(address(hub), newSpoke, assetIds, spokeConfigs);

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, newSpoke);
    DataTypes.SpokeConfig memory wethSpokeData = hub.getSpokeConfig(wethAssetId, newSpoke);

    assertEq(daiSpokeData, daiSpokeConfig);
    assertEq(wethSpokeData, wethSpokeConfig);
  }

  function test_updateSpokeActive_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeActive(address(hub), assetId, spokeAddresses[0], true);
  }

  function test_updateSpokeActive() public {
    DataTypes.SpokeConfig memory expectedSpokeConfig = hub.getSpokeConfig(assetId, spoke);
    for (uint256 i = 0; i < 2; ++i) {
      bool active = (i == 0) ? false : true;
      expectedSpokeConfig.active = active;
      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, expectedSpokeConfig))
      );
      vm.prank(HUB_CONFIGURATOR_ADMIN);
      hubConfigurator.updateSpokeActive(address(hub), assetId, spoke, active);
      assertEq(hub.getSpokeConfig(assetId, spoke), expectedSpokeConfig);
    }
  }

  function test_updateSpokeSupplyCap_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeSupplyCap(address(hub), assetId, spokeAddresses[0], 100);
  }

  function test_updateSpokeSupplyCap() public {
    uint256 newSupplyCap = 100;
    DataTypes.SpokeConfig memory expectedSpokeConfig = hub.getSpokeConfig(assetId, spoke);
    expectedSpokeConfig.supplyCap = newSupplyCap;
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeSupplyCap(address(hub), assetId, spoke, newSupplyCap);
    assertEq(hub.getSpokeConfig(assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeDrawCap_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeDrawCap(address(hub), assetId, spokeAddresses[0], 100);
  }

  function test_updateSpokeDrawCap() public {
    uint256 newDrawCap = 100;
    DataTypes.SpokeConfig memory expectedSpokeConfig = hub.getSpokeConfig(assetId, spoke);
    expectedSpokeConfig.drawCap = newDrawCap;
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeDrawCap(address(hub), assetId, spoke, newDrawCap);
    assertEq(hub.getSpokeConfig(assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeCaps_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeCaps(address(hub), assetId, spokeAddresses[0], 100, 100);
  }

  function test_updateSpokeCaps() public {
    uint256 newSupplyCap = 100;
    uint256 newDrawCap = 200;
    DataTypes.SpokeConfig memory expectedSpokeConfig = hub.getSpokeConfig(assetId, spoke);
    expectedSpokeConfig.supplyCap = newSupplyCap;
    expectedSpokeConfig.drawCap = newDrawCap;
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, expectedSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeCaps(address(hub), assetId, spoke, newSupplyCap, newDrawCap);
    assertEq(hub.getSpokeConfig(assetId, spoke), expectedSpokeConfig);
  }

  function test_updateSpokeConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateSpokeConfig(
      address(hub),
      assetId,
      spokeAddresses[0],
      DataTypes.SpokeConfig({supplyCap: 100, drawCap: 100, active: true})
    );
  }

  function test_updateSpokeConfig() public {
    DataTypes.SpokeConfig memory newSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 100,
      drawCap: 200,
      active: false
    });
    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateSpokeConfig, (assetId, spoke, newSpokeConfig))
    );
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateSpokeConfig(address(hub), assetId, spoke, newSpokeConfig);
    assertEq(hub.getSpokeConfig(assetId, spoke), newSpokeConfig);
  }

  function _addAsset(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy,
    bytes memory encodedIrData
  ) internal returns (uint256) {
    if (fetchErc20Decimals) {
      _mockDecimals(underlying, decimals);
      return
        hubConfigurator.addAsset(
          address(hub),
          underlying,
          feeReceiver,
          interestRateStrategy,
          encodedIrData
        );
    } else {
      return
        hubConfigurator.addAsset(
          address(hub),
          underlying,
          decimals,
          feeReceiver,
          interestRateStrategy,
          encodedIrData
        );
    }
  }
}
