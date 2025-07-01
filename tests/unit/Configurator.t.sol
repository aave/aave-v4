// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract ConfiguratorTest is LiquidityHubBase {
  Configurator internal configurator;

  address internal CONFIGURATOR_ADMIN = makeAddr('CONFIGURATOR_ADMIN');

  function setUp() public virtual override {
    super.setUp();
    configurator = new Configurator(CONFIGURATOR_ADMIN);
    IAccessManager accessManager = IAccessManager(hub.authority());
    // Grant configurator hub admin role with 0 delay
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(configurator), 0);
  }

  function test_addSpokeToAssets_fuzz_revertsWith_OwnableUnauthorizedAccount(
    address caller
  ) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    configurator.addSpokeToAssets(
      address(hub),
      vm.randomAddress(),
      new uint256[](0),
      new DataTypes.SpokeConfig[](0)
    );
  }

  function test_addSpokeToAssets_revertsWith_InvalidSpoke() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2, active: true});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4, active: true});

    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.addSpokeToAssets(address(hub), address(0), assetIds, spokeConfigs);
  }

  function test_addSpokeToAssets_revertsWith_MismatchedConfigs() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](3);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2, active: true});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4, active: true});
    spokeConfigs[2] = DataTypes.SpokeConfig({supplyCap: 5, drawCap: 6, active: true});

    vm.expectRevert(IConfigurator.MismatchedConfigs.selector);
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.addSpokeToAssets(address(hub), address(spoke1), assetIds, spokeConfigs);
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
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.addSpokeToAssets(address(hub), address(spoke1), assetIds, spokeConfigs);

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, address(spoke1));
    DataTypes.SpokeConfig memory wethSpokeData = hub.getSpokeConfig(wethAssetId, address(spoke1));

    assertEq(daiSpokeData, daiSpokeConfig);
    assertEq(wethSpokeData, wethSpokeConfig);
  }

  function test_addAsset_fuzz_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
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
    vm.assume(
      underlying != address(0) && feeReceiver != address(0) && interestRateStrategy != address(0)
    );
    decimals = uint8(bound(decimals, hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, type(uint8).max));

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector, address(hub));
    vm.prank(CONFIGURATOR_ADMIN);
    _addAsset(fetchErc20Decimals, underlying, decimals, feeReceiver, interestRateStrategy);
  }

  function test_addAsset_fuzz_revertsWith_InvalidUnderlying(
    bool fetchErc20Decimals,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    vm.expectRevert(ILiquidityHub.InvalidUnderlying.selector, address(hub));
    vm.prank(CONFIGURATOR_ADMIN);
    _addAsset(fetchErc20Decimals, address(0), decimals, feeReceiver, interestRateStrategy);
  }

  function test_addAsset_fuzz_revertsWith_InvalidIrStrategy(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver
  ) public {
    assumeUnusedAddress(underlying);
    vm.assume(feeReceiver != address(0));
    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector, address(hub));

    vm.prank(CONFIGURATOR_ADMIN);
    _addAsset(fetchErc20Decimals, underlying, decimals, feeReceiver, address(0));
  }

  function test_addAsset_fuzz(
    bool fetchErc20Decimals,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    vm.assume(
      underlying != address(0) && feeReceiver != address(0) && interestRateStrategy != address(0)
    );
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

    vm.prank(CONFIGURATOR_ADMIN);
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

  function test_updateActive_fuzz_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    configurator.updateActive(address(hub), vm.randomUint(), vm.randomBool());
  }

  function test_updateActive_fuzz(uint256 assetId, bool active) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.active = active;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateActive(address(hub), assetId, active);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updatePaused_fuzz_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    configurator.updatePaused(address(hub), vm.randomUint(), vm.randomBool());
  }

  function test_updatePaused_fuzz(uint256 assetId, bool paused) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.paused = paused;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updatePaused(address(hub), assetId, paused);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateFrozen_fuzz_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    configurator.updateFrozen(address(hub), vm.randomUint(), vm.randomBool());
  }

  function test_updateFrozen_fuzz(uint256 assetId, bool frozen) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.frozen = frozen;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateFrozen(address(hub), assetId, frozen);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateLiquidityFee_fuzz_revertsWith_OwnableUnauthorizedAccount(
    address caller
  ) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    configurator.updateLiquidityFee(address(hub), vm.randomUint(), vm.randomUint());
  }

  function test_updateLiquidityFee_fuzz_revertsWith_InvalidLiquidityFee(
    uint256 assetId,
    uint256 liquidityFee
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(
      liquidityFee,
      PercentageMathExtended.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );

    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateLiquidityFee(address(hub), assetId, liquidityFee);
  }

  function test_updateLiquidityFee_fuzz(uint256 assetId, uint256 liquidityFee) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.liquidityFee = liquidityFee;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateLiquidityFee(address(hub), assetId, liquidityFee);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateFeeReceiver_fuzz_revertsWith_OwnableUnauthorizedAccount(
    address caller
  ) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    configurator.updateFeeReceiver(address(hub), vm.randomUint(), vm.randomAddress());
  }

  function test_updateFeeReceiver_fuzz_revertsWith_InvalidSpoke(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    // reverts when adding zero as new spoke
    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateFeeReceiver(address(hub), assetId, address(0));
  }

  function test_updateFeeReceiver_revertsWith_InvalidSpoke() public {
    test_updateFeeReceiver_fuzz_revertsWith_InvalidSpoke(daiAssetId);
  }

  function test_updateFeeReceiver_fuzz(uint256 assetId, address feeReceiver) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    if (feeReceiver == address(0)) {
      vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    } else {
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
      }

      // same struct, renaming to expectedConfig
      DataTypes.AssetConfig memory expectedConfig = oldConfig;
      expectedConfig.feeReceiver = feeReceiver;

      vm.expectCall(
        address(hub),
        abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
      );

      vm.prank(CONFIGURATOR_ADMIN);
      configurator.updateFeeReceiver(address(hub), assetId, feeReceiver);

      assertEq(hub.getAssetConfig(assetId), expectedConfig);
    }
  }

  function test_updateFeeReceiver_Scenario() public {
    // set same fee receiver
    test_updateFeeReceiver_fuzz(daiAssetId, address(treasurySpoke));
    // set new fee receiver
    test_updateFeeReceiver_fuzz(daiAssetId, makeAddr('newFeeReceiver'));
    // set initial fee receiver
    test_updateFeeReceiver_fuzz(daiAssetId, address(treasurySpoke));
  }

  function test_updateFeeConfig_fuzz_revertsWith_OwnableUnauthorizedAccount(address caller) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    configurator.updateFeeConfig({
      hub: address(hub),
      assetId: vm.randomUint(),
      liquidityFee: vm.randomUint(),
      feeReceiver: vm.randomAddress()
    });
  }

  function test_updateFeeConfig_fuzz_revertsWith_InvalidLiquidityFee(
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(
      liquidityFee,
      PercentageMathExtended.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );
    vm.assume(feeReceiver != address(0));

    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateFeeConfig(address(hub), assetId, liquidityFee, feeReceiver);
  }

  function test_updateFeeConfig_fuzz_revertsWith_InvalidSpoke(
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 1, PercentageMathExtended.PERCENTAGE_FACTOR);

    // reverts when adding zero as new spoke
    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateFeeConfig(address(hub), assetId, liquidityFee, address(0));
  }

  function test_updateFeeConfig_fuzz(
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);
    vm.assume(feeReceiver != address(0) && oldConfig.feeReceiver != feeReceiver);

    test_updateFeeConfig(assetId, liquidityFee, feeReceiver);
  }

  function test_updateFeeConfig_Scenario() public {
    // set same fee receiver and change liquidity fee
    test_updateFeeConfig(daiAssetId, 18_00, address(treasurySpoke));
    // set new fee receiver and liquidity fee
    test_updateFeeConfig(daiAssetId, 4_00, makeAddr('newFeeReceiver'));
    // set non-zero fee receiver
    test_updateFeeConfig(daiAssetId, 0, makeAddr('newFeeReceiver2'));
    // set initial fee receiver and zero fee
    test_updateFeeConfig(daiAssetId, 0, address(treasurySpoke));
  }

  function test_updateFeeConfig(
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) internal {
    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);

    if (oldConfig.feeReceiver == feeReceiver) {
      return;
    }

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
    expectedConfig.liquidityFee = liquidityFee;

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateFeeConfig(address(hub), assetId, liquidityFee, feeReceiver);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateInterestRateStrategy_fuzz_revertsWith_OwnableUnauthorizedAccount(
    address caller
  ) public {
    vm.assume(caller != CONFIGURATOR_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    configurator.updateInterestRateStrategy(address(hub), vm.randomUint(), vm.randomAddress());
  }

  function test_updateInterestRateStrategy_fuzz_revertsWith_InvalidIrStrategy(
    uint256 assetId
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateInterestRateStrategy(address(hub), assetId, address(0));
  }

  function test_updateInterestRateStrategy_fuzz_revertsWith_InterestRateStrategyReverts(
    uint256 assetId,
    address interestRateStrategy
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    assumeUnusedAddress(interestRateStrategy);

    vm.expectRevert();
    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateInterestRateStrategy(address(hub), assetId, interestRateStrategy);
  }

  function test_updateInterestRateStrategy_fuzz(
    uint256 assetId,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(interestRateStrategy);

    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.irStrategy = interestRateStrategy;
    _mockInterestRate(interestRateStrategy, 5_00);

    vm.expectCall(
      address(hub),
      abi.encodeCall(ILiquidityHub.updateAssetConfig, (assetId, expectedConfig))
    );

    vm.prank(CONFIGURATOR_ADMIN);
    configurator.updateInterestRateStrategy(address(hub), assetId, interestRateStrategy);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
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
      return
        configurator.addAsset(
          address(hub),
          underlying,
          decimals,
          feeReceiver,
          interestRateStrategy
        );
    } else {
      return
        configurator.addAsset(
          address(hub),
          underlying,
          decimals,
          feeReceiver,
          interestRateStrategy
        );
    }
  }
}
