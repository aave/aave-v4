// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract HubConfiguratorTest is LiquidityHubBase {
  HubConfigurator public hubConfigurator;

  address public HUB_CONFIGURATOR_ADMIN = makeAddr('HUB_CONFIGURATOR_ADMIN');

  uint256 public assetId;

  function setUp() public virtual override {
    super.setUp();
    hubConfigurator = new HubConfigurator(HUB_CONFIGURATOR_ADMIN);
    IAccessManager accessManager = IAccessManager(hub.authority());
    // Grant hubConfigurator hub admin role with 0 delay
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(hubConfigurator), 0);
    assetId = daiAssetId;
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
    hubConfigurator.addSpokeToAssets(address(hub), address(spoke1), assetIds, spokeConfigs);
  }

  function test_addSpokeToAssets() public {
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
    emit ILiquidityHub.SpokeAdded(daiAssetId, address(spoke1));
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(wethAssetId, address(spoke1));
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.addSpokeToAssets(address(hub), address(spoke1), assetIds, spokeConfigs);

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, address(spoke1));
    DataTypes.SpokeConfig memory wethSpokeData = hub.getSpokeConfig(wethAssetId, address(spoke1));

    assertEq(daiSpokeData, daiSpokeConfig);
    assertEq(wethSpokeData, wethSpokeConfig);
  }

  function test_addAsset_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    _addAsset({
      fetchErc20Decimals: vm.randomBool(),
      underlying: vm.randomAddress(),
      decimals: uint8(vm.randomUint()),
      feeReceiver: vm.randomAddress(),
      interestRateStrategy: vm.randomAddress()
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
    _addAsset(fetchErc20Decimals, underlying, decimals, feeReceiver, interestRateStrategy);
  }

  function test_addAsset_fuzz(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    uint256 expectedAssetId = hub.getAssetCount();
    DataTypes.AssetConfig memory expectedConfig = DataTypes.AssetConfig({
      active: true,
      paused: false,
      frozen: false,
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
        (underlying, decimals, feeReceiver, interestRateStrategy)
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
      interestRateStrategy
    );

    assertEq(assetId, expectedAssetId, 'asset id');
    assertEq(hub.getAssetCount(), assetId + 1, 'asset count');
    assertEq(hub.getAsset(assetId).decimals, decimals, 'asset decimals');
    assertEq(hub.getAssetConfig(assetId), expectedConfig);
    assertEq(hub.getSpokeConfig(assetId, feeReceiver), expectedSpokeConfig);
  }

  function test_updateActive_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateActive(address(hub), vm.randomUint(), vm.randomBool());
  }

  function test_updateActive() public {
    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.active = !expectedConfig.active;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateActive(address(hub), assetId, expectedConfig.active);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updatePaused_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updatePaused(address(hub), vm.randomUint(), vm.randomBool());
  }

  function test_updatePaused() public {
    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.paused = !expectedConfig.paused;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updatePaused(address(hub), assetId, expectedConfig.paused);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateFrozen_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateFrozen(address(hub), vm.randomUint(), vm.randomBool());
  }

  function test_updateFrozen() public {
    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.frozen = !expectedConfig.frozen;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.updateFrozen(address(hub), assetId, expectedConfig.frozen);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateLiquidityFee_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    hubConfigurator.updateLiquidityFee(address(hub), vm.randomUint(), vm.randomUint());
  }

  function test_updateLiquidityFee() public {
    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.liquidityFee = PercentageMathExtended.PERCENTAGE_FACTOR - 1;

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
            DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0, active: false})
          )
        )
      );

      if (hub.getSpoke(assetId, feeReceiver).lastUpdateTimestamp == 0) {
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
                active: true
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
    liquidityFee = bound(liquidityFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
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
            DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0, active: false})
          )
        )
      );

      if (hub.getSpoke(assetId, feeReceiver).lastUpdateTimestamp == 0) {
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
                active: true
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
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 0,
        feeReceiver: vm.randomAddress(),
        irStrategy: vm.randomAddress()
      })
    );
  }

  function test_updateAssetConfig() public {
    DataTypes.AssetConfig memory newAssetConfig = DataTypes.AssetConfig({
      active: true,
      paused: false,
      frozen: false,
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
          DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0, active: false})
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

  function _addAsset(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) internal returns (uint256) {
    if (fetchErc20Decimals) {
      _mockDecimals(underlying, decimals);
      return hubConfigurator.addAsset(address(hub), underlying, feeReceiver, interestRateStrategy);
    } else {
      return
        hubConfigurator.addAsset(
          address(hub),
          underlying,
          decimals,
          feeReceiver,
          interestRateStrategy
        );
    }
  }
}
