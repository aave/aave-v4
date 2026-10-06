// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

abstract contract SpokeConfiguratorBaseTest is Base {
  address public spokeAddr;
  ISpoke public spoke;
  address public hubAddr;
  address public underlying;
  uint256 public reserveId;
  address public unlistedUnderlying = makeAddr('UNLISTED_UNDERLYING');

  function setUp() public virtual override {
    super.setUp();
    spokeAddr = address(spoke1);
    spoke = ISpoke(spokeAddr);
    hubAddr = address(hub1);
    underlying = address(tokenList.weth);
    reserveId = _wethReserveId(spoke);
    _grantSpokeConfiguratorRole(spoke, address(spokeConfigurator));
  }

  function _expectReserveFrozenUpdated(
    ISpoke targetSpoke,
    uint256 targetReserveId,
    bool oldFrozen,
    bool newFrozen
  ) internal {
    ISpoke.Reserve memory reserve = targetSpoke.getReserve(targetReserveId);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReserveFrozenUpdated(
      address(targetSpoke),
      address(reserve.hub),
      reserve.underlying,
      targetReserveId,
      oldFrozen,
      newFrozen
    );
  }

  function _expectDynamicConfigUpdated(
    ISpoke targetSpoke,
    uint256 targetReserveId,
    uint32 oldKey,
    uint32 newKey,
    ISpoke.DynamicReserveConfig memory oldConfig,
    ISpoke.DynamicReserveConfig memory newConfig
  ) internal {
    ISpoke.Reserve memory reserve = targetSpoke.getReserve(targetReserveId);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.CollateralFactorUpdated(
      address(targetSpoke),
      address(reserve.hub),
      reserve.underlying,
      targetReserveId,
      oldKey,
      newKey,
      oldConfig.collateralFactor,
      newConfig.collateralFactor
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.MaxLiquidationBonusUpdated(
      address(targetSpoke),
      address(reserve.hub),
      reserve.underlying,
      targetReserveId,
      oldKey,
      newKey,
      oldConfig.maxLiquidationBonus,
      newConfig.maxLiquidationBonus
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.LiquidationFeeUpdated(
      address(targetSpoke),
      address(reserve.hub),
      reserve.underlying,
      targetReserveId,
      oldKey,
      newKey,
      oldConfig.liquidationFee,
      newConfig.liquidationFee
    );
  }

  function _expectSavedDynamicConfigKeyUpdated(
    ISpoke targetSpoke,
    uint256 targetReserveId,
    uint32 oldSavedKey,
    uint32 newSavedKey
  ) internal {
    ISpoke.Reserve memory reserve = targetSpoke.getReserve(targetReserveId);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.SavedDynamicConfigKeyUpdated(
      address(targetSpoke),
      address(reserve.hub),
      reserve.underlying,
      targetReserveId,
      oldSavedKey,
      newSavedKey
    );
  }

  /// @dev Number of logs emitted by the configurator since the last `vm.recordLogs`.
  function _configuratorLogCount() internal view returns (uint256 count) {
    Vm.Log[] memory logs = vm.getRecordedLogs();
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].emitter == address(spokeConfigurator)) ++count;
    }
  }

  function _savedKey(ISpoke targetSpoke, uint256 targetReserveId) internal view returns (uint32) {
    ISpoke.Reserve memory reserve = targetSpoke.getReserve(targetReserveId);
    return
      spokeConfigurator.getSavedDynamicConfigKey(
        address(targetSpoke),
        address(reserve.hub),
        reserve.underlying
      );
  }

  function _latestKey(ISpoke targetSpoke, uint256 targetReserveId) internal view returns (uint32) {
    return targetSpoke.getReserve(targetReserveId).dynamicConfigKey;
  }
}

contract SpokeConfiguratorTest is SpokeConfiguratorBaseTest {
  using SafeCast for uint256;

  function test_updateReservePriceSource_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateReservePriceSource(spokeAddr, hubAddr, underlying, address(0));
  }

  function test_updateReservePriceSource() public {
    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    address oldPriceSource = IAaveOracle(spoke.ORACLE()).getReserveSource(reserveId);

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReservePriceSource, (reserveId, newPriceSource))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReservePriceSource(reserveId, newPriceSource);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReservePriceSourceUpdated(
      spokeAddr,
      hubAddr,
      underlying,
      reserveId,
      oldPriceSource,
      newPriceSource
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateReservePriceSource(spokeAddr, hubAddr, underlying, newPriceSource);

    assertEq(_configuratorLogCount(), 1);
    assertEq(IAaveOracle(spoke.ORACLE()).getReserveSource(reserveId), newPriceSource);
  }

  function test_updateLiquidationTargetHealthFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateLiquidationTargetHealthFactor(spokeAddr, 0);
  }

  function test_updateLiquidationTargetHealthFactor() public {
    uint128 newTargetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2;

    ISpoke.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    uint256 oldTargetHealthFactor = expectedLiquidationConfig.targetHealthFactor;
    expectedLiquidationConfig.targetHealthFactor = newTargetHealthFactor;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateLiquidationConfig(expectedLiquidationConfig);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.LiquidationTargetHealthFactorUpdated(
      spokeAddr,
      oldTargetHealthFactor,
      newTargetHealthFactor
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationTargetHealthFactor(spokeAddr, newTargetHealthFactor);

    assertEq(_configuratorLogCount(), 1);
    assertEq(spoke.getLiquidationConfig(), expectedLiquidationConfig);
  }

  function test_updateHealthFactorForMaxBonus_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateHealthFactorForMaxBonus(spokeAddr, 0);
  }

  function test_updateHealthFactorForMaxBonus() public {
    uint64 newHealthFactorForMaxBonus = HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2;

    ISpoke.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    uint256 oldHealthFactorForMaxBonus = expectedLiquidationConfig.healthFactorForMaxBonus;
    expectedLiquidationConfig.healthFactorForMaxBonus = newHealthFactorForMaxBonus;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateLiquidationConfig(expectedLiquidationConfig);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.HealthFactorForMaxBonusUpdated(
      spokeAddr,
      oldHealthFactorForMaxBonus,
      newHealthFactorForMaxBonus
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateHealthFactorForMaxBonus(spokeAddr, newHealthFactorForMaxBonus);

    assertEq(_configuratorLogCount(), 1);
    assertEq(spoke.getLiquidationConfig().healthFactorForMaxBonus, newHealthFactorForMaxBonus);
  }

  function test_updateLiquidationBonusFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateLiquidationBonusFactor(spokeAddr, 0);
  }

  function test_updateLiquidationBonusFactor() public {
    uint16 newLiquidationBonusFactor = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 2;

    ISpoke.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    uint256 oldLiquidationBonusFactor = expectedLiquidationConfig.liquidationBonusFactor;
    expectedLiquidationConfig.liquidationBonusFactor = newLiquidationBonusFactor;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateLiquidationConfig(expectedLiquidationConfig);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.LiquidationBonusFactorUpdated(
      spokeAddr,
      oldLiquidationBonusFactor,
      newLiquidationBonusFactor
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationBonusFactor(spokeAddr, newLiquidationBonusFactor);

    assertEq(_configuratorLogCount(), 1);
    assertEq(spoke.getLiquidationConfig(), expectedLiquidationConfig);
  }

  function test_updateLiquidationConfig_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateLiquidationConfig(
      spokeAddr,
      ISpoke.LiquidationConfig({
        targetHealthFactor: 0,
        healthFactorForMaxBonus: 0,
        liquidationBonusFactor: 0
      })
    );
  }

  function test_updateLiquidationConfig() public {
    ISpoke.LiquidationConfig memory oldLiquidationConfig = spoke.getLiquidationConfig();
    ISpoke.LiquidationConfig memory newLiquidationConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2,
      healthFactorForMaxBonus: HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2,
      liquidationBonusFactor: PercentageMath.PERCENTAGE_FACTOR.toUint16() / 2
    });

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (newLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateLiquidationConfig(newLiquidationConfig);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.LiquidationTargetHealthFactorUpdated(
      spokeAddr,
      oldLiquidationConfig.targetHealthFactor,
      newLiquidationConfig.targetHealthFactor
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.HealthFactorForMaxBonusUpdated(
      spokeAddr,
      oldLiquidationConfig.healthFactorForMaxBonus,
      newLiquidationConfig.healthFactorForMaxBonus
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.LiquidationBonusFactorUpdated(
      spokeAddr,
      oldLiquidationConfig.liquidationBonusFactor,
      newLiquidationConfig.liquidationBonusFactor
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationConfig(spokeAddr, newLiquidationConfig);

    assertEq(_configuratorLogCount(), 3);
    assertEq(spoke.getLiquidationConfig(), newLiquidationConfig);
  }

  function test_addReserve_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.addReserve({
      spoke: spokeAddr,
      hub: hubAddr,
      underlying: address(tokenList.usdz),
      priceSource: address(0),
      config: _getDefaultReserveConfig(15_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    });
  }

  function test_addReserve_revertsWith_AssetNotListed() public {
    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    vm.expectRevert(IHub.AssetNotListed.selector, hubAddr);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.addReserve({
      spoke: spokeAddr,
      hub: hubAddr,
      underlying: unlistedUnderlying,
      priceSource: newPriceSource,
      config: _getDefaultReserveConfig(15_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    });
  }

  function test_addReserve() public {
    uint256 expectedReserveId = spoke.getReserveCount();
    address usdz = address(tokenList.usdz);

    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    ISpoke.ReserveConfig memory config = _getDefaultReserveConfig(15_00);
    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 100_00,
      liquidationFee: 0
    });

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.addReserve,
        (hubAddr, usdzAssetId, newPriceSource, config, dynamicConfig)
      )
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddReserve(expectedReserveId, usdzAssetId, hubAddr);
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReserveConfig(expectedReserveId, config);
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(expectedReserveId, 0, dynamicConfig);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReservePriceSourceUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      address(0),
      newPriceSource
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReservePausedUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      false,
      config.paused
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReserveFrozenUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      false,
      config.frozen
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReserveBorrowableUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      false,
      config.borrowable
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReserveReceiveSharesEnabledUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      false,
      config.receiveSharesEnabled
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReserveCollateralRiskUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      0,
      config.collateralRisk
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.CollateralFactorUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      0,
      0,
      0,
      dynamicConfig.collateralFactor
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.MaxLiquidationBonusUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      0,
      0,
      0,
      dynamicConfig.maxLiquidationBonus
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.LiquidationFeeUpdated(
      spokeAddr,
      hubAddr,
      usdz,
      expectedReserveId,
      0,
      0,
      0,
      dynamicConfig.liquidationFee
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint256 actualReserveId = spokeConfigurator.addReserve({
      spoke: spokeAddr,
      hub: hubAddr,
      underlying: usdz,
      priceSource: newPriceSource,
      config: config,
      dynamicConfig: dynamicConfig
    });

    assertEq(_configuratorLogCount(), 9);
    assertEq(actualReserveId, expectedReserveId);
    assertEq(spoke.getReserveId(hubAddr, usdzAssetId), expectedReserveId);
    assertEq(spokeConfigurator.getSavedDynamicConfigKey(spokeAddr, hubAddr, usdz), 0);
  }

  function test_updatePaused_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updatePaused(spokeAddr, hubAddr, underlying, true);
  }

  function test_updatePaused() public {
    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      bool oldPaused = expectedReserveConfig.paused;
      expectedReserveConfig.paused = (i == 0) ? false : true;

      vm.recordLogs();
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.ReservePausedUpdated(
        spokeAddr,
        hubAddr,
        underlying,
        reserveId,
        oldPaused,
        expectedReserveConfig.paused
      );
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      spokeConfigurator.updatePaused(spokeAddr, hubAddr, underlying, expectedReserveConfig.paused);

      assertEq(_configuratorLogCount(), 1);
      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateBorrowable_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateBorrowable(spokeAddr, hubAddr, underlying, true);
  }

  function test_updateBorrowable() public {
    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      bool oldBorrowable = expectedReserveConfig.borrowable;
      expectedReserveConfig.borrowable = (i == 0) ? false : true;

      vm.recordLogs();
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.ReserveBorrowableUpdated(
        spokeAddr,
        hubAddr,
        underlying,
        reserveId,
        oldBorrowable,
        expectedReserveConfig.borrowable
      );
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      spokeConfigurator.updateBorrowable(
        spokeAddr,
        hubAddr,
        underlying,
        expectedReserveConfig.borrowable
      );

      assertEq(_configuratorLogCount(), 1);
      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateReceiveSharesEnabled_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateReceiveSharesEnabled(spokeAddr, hubAddr, underlying, false);
  }

  function test_updateReceiveSharesEnabled() public {
    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      bool oldReceiveSharesEnabled = expectedReserveConfig.receiveSharesEnabled;
      expectedReserveConfig.receiveSharesEnabled = (i == 0) ? false : true;

      vm.recordLogs();
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.ReserveReceiveSharesEnabledUpdated(
        spokeAddr,
        hubAddr,
        underlying,
        reserveId,
        oldReceiveSharesEnabled,
        expectedReserveConfig.receiveSharesEnabled
      );
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      spokeConfigurator.updateReceiveSharesEnabled(
        spokeAddr,
        hubAddr,
        underlying,
        expectedReserveConfig.receiveSharesEnabled
      );

      assertEq(_configuratorLogCount(), 1);
      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateCollateralRisk_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateCollateralRisk(spokeAddr, hubAddr, underlying, 0);
  }

  function test_updateCollateralRisk() public {
    uint24 newCollateralRisk = MAX_ALLOWED_COLLATERAL_RISK / 2;

    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    uint256 oldCollateralRisk = expectedReserveConfig.collateralRisk;
    expectedReserveConfig.collateralRisk = newCollateralRisk;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReserveCollateralRiskUpdated(
      spokeAddr,
      hubAddr,
      underlying,
      reserveId,
      oldCollateralRisk,
      newCollateralRisk
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralRisk(spokeAddr, hubAddr, underlying, newCollateralRisk);

    assertEq(_configuratorLogCount(), 1);
    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_addCollateralFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.addCollateralFactor(spokeAddr, hubAddr, underlying, 0);
  }

  function test_addCollateralFactor() public {
    uint16 newCollateralFactor = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 2;

    uint32 oldConfigKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    ISpoke.DynamicReserveConfig
      memory expectedDynamicReserveConfig = _getLatestDynamicReserveConfig(spoke, reserveId);
    expectedDynamicReserveConfig.collateralFactor = newCollateralFactor;

    uint32 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, expectedDynamicReserveConfig);
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      oldConfigKey,
      expectedConfigKey,
      oldDynamicReserveConfig,
      expectedDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint32 dynamicConfigKey = spokeConfigurator.addCollateralFactor(
      spokeAddr,
      hubAddr,
      underlying,
      newCollateralFactor
    );

    assertEq(_configuratorLogCount(), 3);
    assertEq(dynamicConfigKey, expectedConfigKey);
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), expectedDynamicReserveConfig);
    assertEq(_savedKey(spoke, reserveId), 0);
  }

  function test_updateCollateralFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateCollateralFactor(spokeAddr, hubAddr, underlying, 0, 0);
  }

  function test_updateCollateralFactor() public {
    uint16 newCollateralFactor = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 4;

    uint32 dynamicConfigKey = 0;

    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    ISpoke.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    expectedDynamicReserveConfig.collateralFactor = newCollateralFactor;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.updateDynamicReserveConfig,
        (reserveId, dynamicConfigKey, expectedDynamicReserveConfig)
      )
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateDynamicReserveConfig(
      reserveId,
      dynamicConfigKey,
      expectedDynamicReserveConfig
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.CollateralFactorUpdated(
      spokeAddr,
      hubAddr,
      underlying,
      reserveId,
      dynamicConfigKey,
      dynamicConfigKey,
      oldDynamicReserveConfig.collateralFactor,
      newCollateralFactor
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralFactor(
      spokeAddr,
      hubAddr,
      underlying,
      dynamicConfigKey,
      newCollateralFactor
    );

    assertEq(_configuratorLogCount(), 1);
    assertEq(
      spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey),
      expectedDynamicReserveConfig
    );
  }

  function test_addLiquidationBonus_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.addMaxLiquidationBonus(spokeAddr, hubAddr, underlying, 0);
  }

  function test_addMaxLiquidationBonus() public {
    uint32 newLiquidationBonus = PercentageMath.PERCENTAGE_FACTOR.toUint32() + 1;

    uint32 oldConfigKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    ISpoke.DynamicReserveConfig
      memory expectedDynamicReserveConfig = _getLatestDynamicReserveConfig(spoke, reserveId);
    expectedDynamicReserveConfig.maxLiquidationBonus = newLiquidationBonus;

    uint32 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, expectedDynamicReserveConfig);
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      oldConfigKey,
      expectedConfigKey,
      oldDynamicReserveConfig,
      expectedDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint32 dynamicConfigKey = spokeConfigurator.addMaxLiquidationBonus(
      spokeAddr,
      hubAddr,
      underlying,
      newLiquidationBonus
    );

    assertEq(_configuratorLogCount(), 3);
    assertEq(dynamicConfigKey, expectedConfigKey);
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), expectedDynamicReserveConfig);
  }

  function test_updateMaxLiquidationBonus_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateMaxLiquidationBonus(spokeAddr, hubAddr, underlying, 0, 0);
  }

  function test_updateMaxLiquidationBonus() public {
    uint32 newLiquidationBonus = PercentageMath.PERCENTAGE_FACTOR.toUint32() + 123;

    uint32 dynamicConfigKey = 0;

    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    ISpoke.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    expectedDynamicReserveConfig.maxLiquidationBonus = newLiquidationBonus;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.updateDynamicReserveConfig,
        (reserveId, dynamicConfigKey, expectedDynamicReserveConfig)
      )
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateDynamicReserveConfig(
      reserveId,
      dynamicConfigKey,
      expectedDynamicReserveConfig
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.MaxLiquidationBonusUpdated(
      spokeAddr,
      hubAddr,
      underlying,
      reserveId,
      dynamicConfigKey,
      dynamicConfigKey,
      oldDynamicReserveConfig.maxLiquidationBonus,
      newLiquidationBonus
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateMaxLiquidationBonus(
      spokeAddr,
      hubAddr,
      underlying,
      dynamicConfigKey,
      newLiquidationBonus
    );

    assertEq(_configuratorLogCount(), 1);
    assertEq(
      spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey),
      expectedDynamicReserveConfig
    );
  }

  function test_addLiquidationFee_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.addLiquidationFee(spokeAddr, hubAddr, underlying, 0);
  }

  function test_addLiquidationFee() public {
    uint16 newLiquidationFee = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 2;

    uint32 oldConfigKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    ISpoke.DynamicReserveConfig
      memory expectedDynamicReserveConfig = _getLatestDynamicReserveConfig(spoke, reserveId);
    expectedDynamicReserveConfig.liquidationFee = newLiquidationFee;

    uint32 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, expectedDynamicReserveConfig);
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      oldConfigKey,
      expectedConfigKey,
      oldDynamicReserveConfig,
      expectedDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint32 dynamicConfigKey = spokeConfigurator.addLiquidationFee(
      spokeAddr,
      hubAddr,
      underlying,
      newLiquidationFee
    );

    assertEq(_configuratorLogCount(), 3);
    assertEq(dynamicConfigKey, expectedConfigKey);
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), expectedDynamicReserveConfig);
  }

  function test_updateLiquidationFee_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateLiquidationFee(spokeAddr, hubAddr, underlying, 0, 0);
  }

  function test_updateLiquidationFee() public {
    uint16 newLiquidationFee = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 4;

    uint32 dynamicConfigKey = 0;

    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    ISpoke.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    expectedDynamicReserveConfig.liquidationFee = newLiquidationFee;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.updateDynamicReserveConfig,
        (reserveId, dynamicConfigKey, expectedDynamicReserveConfig)
      )
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateDynamicReserveConfig(
      reserveId,
      dynamicConfigKey,
      expectedDynamicReserveConfig
    );
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.LiquidationFeeUpdated(
      spokeAddr,
      hubAddr,
      underlying,
      reserveId,
      dynamicConfigKey,
      dynamicConfigKey,
      oldDynamicReserveConfig.liquidationFee,
      newLiquidationFee
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationFee(
      spokeAddr,
      hubAddr,
      underlying,
      dynamicConfigKey,
      newLiquidationFee
    );

    assertEq(_configuratorLogCount(), 1);
    assertEq(
      spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey),
      expectedDynamicReserveConfig
    );
  }

  function test_addDynamicReserveConfig_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.addDynamicReserveConfig(
      spokeAddr,
      hubAddr,
      underlying,
      ISpoke.DynamicReserveConfig({
        collateralFactor: 20_00,
        maxLiquidationBonus: 130_00,
        liquidationFee: 15_00
      })
    );
  }

  function test_addDynamicReserveConfig() public {
    ISpoke.DynamicReserveConfig memory newDynamicReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 20_00,
      maxLiquidationBonus: 130_00,
      liquidationFee: 15_00
    });

    uint32 oldConfigKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    uint32 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, newDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, newDynamicReserveConfig);
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      oldConfigKey,
      expectedConfigKey,
      oldDynamicReserveConfig,
      newDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint32 actualConfigKey = spokeConfigurator.addDynamicReserveConfig(
      spokeAddr,
      hubAddr,
      underlying,
      newDynamicReserveConfig
    );

    assertEq(_configuratorLogCount(), 3);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), newDynamicReserveConfig);
    assertEq(actualConfigKey, expectedConfigKey);
  }

  function test_updateDynamicReserveConfig_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateDynamicReserveConfig(
      spokeAddr,
      hubAddr,
      underlying,
      0,
      ISpoke.DynamicReserveConfig({
        collateralFactor: 10_00,
        maxLiquidationBonus: 150_00,
        liquidationFee: 12_00
      })
    );
  }

  function test_updateDynamicReserveConfig() public {
    uint256 count = vm.randomUint(1, 50);
    for (uint256 i; i < count; ++i) test_addDynamicReserveConfig();
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, count);

    ISpoke.DynamicReserveConfig memory newDynamicReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 10_00,
      maxLiquidationBonus: 150_00,
      liquidationFee: 12_00
    });
    uint16 configKeyToUpdate = vm.randomUint(0, count).toUint16();
    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      configKeyToUpdate
    );

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.updateDynamicReserveConfig,
        (reserveId, configKeyToUpdate, newDynamicReserveConfig)
      )
    );

    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateDynamicReserveConfig(reserveId, configKeyToUpdate, newDynamicReserveConfig);
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      configKeyToUpdate,
      configKeyToUpdate,
      oldDynamicReserveConfig,
      newDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateDynamicReserveConfig(
      spokeAddr,
      hubAddr,
      underlying,
      configKeyToUpdate,
      newDynamicReserveConfig
    );

    assertEq(_configuratorLogCount(), 3);
    assertEq(spoke.getDynamicReserveConfig(reserveId, configKeyToUpdate), newDynamicReserveConfig);
  }

  function test_pauseAllReserves_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.pauseAllReserves(spokeAddr);
  }

  function test_pauseAllReserves() public {
    uint256 reserveCount = spoke.getReserveCount();
    vm.recordLogs();
    for (uint256 reserveIdx = 0; reserveIdx < reserveCount; ++reserveIdx) {
      ISpoke.Reserve memory reserve = spoke.getReserve(reserveIdx);
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(reserveIdx);
      bool oldPaused = reserveConfig.paused;
      reserveConfig.paused = true;
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveIdx, reserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveIdx, reserveConfig);
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.ReservePausedUpdated(
        spokeAddr,
        address(reserve.hub),
        reserve.underlying,
        reserveIdx,
        oldPaused,
        true
      );
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.pauseAllReserves(spokeAddr);

    assertEq(_configuratorLogCount(), reserveCount);
    for (uint256 reserveIdx; reserveIdx < reserveCount; ++reserveIdx) {
      assertEq(spoke.getReserveConfig(reserveIdx).paused, true);
    }
  }

  function test_pauseReserve_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.pauseReserve(spokeAddr, hubAddr, underlying);
  }

  function test_pauseReserve() public {
    ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(reserveId);
    bool oldPaused = reserveConfig.paused;
    reserveConfig.paused = true;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, reserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReserveConfig(reserveId, reserveConfig);
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.ReservePausedUpdated(
      spokeAddr,
      hubAddr,
      underlying,
      reserveId,
      oldPaused,
      true
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.pauseReserve(spokeAddr, hubAddr, underlying);

    assertEq(_configuratorLogCount(), 1);
    assertTrue(spoke.getReserveConfig(reserveId).paused);
  }

  function test_freezeReserve_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, underlying);
  }

  function test_freezeReserve() public {
    ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(reserveId);
    reserveConfig.frozen = true;
    uint32 oldConfigKey = _latestKey(spoke, reserveId);
    uint32 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory oldDynamicReserveConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    ISpoke.DynamicReserveConfig
      memory expectedDynamicReserveConfig = _getLatestDynamicReserveConfig(spoke, reserveId);
    expectedDynamicReserveConfig.collateralFactor = 0;

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, reserveConfig))
    );
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReserveConfig(reserveId, reserveConfig);
    _expectReserveFrozenUpdated(spoke, reserveId, false, true);
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, expectedDynamicReserveConfig);
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      oldConfigKey,
      expectedConfigKey,
      oldDynamicReserveConfig,
      expectedDynamicReserveConfig
    );
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, 0, oldConfigKey);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, underlying);

    assertEq(_configuratorLogCount(), 5);
    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_latestKey(spoke, reserveId), expectedConfigKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), expectedDynamicReserveConfig);
    assertEq(_savedKey(spoke, reserveId), oldConfigKey);
  }

  function test_unfreezeReserve_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.unfreezeReserve(spokeAddr, hubAddr, underlying);
  }

  function test_unfreezeReserve() public {
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, underlying);

    ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(reserveId);
    reserveConfig.frozen = false;
    uint32 latestKey = _latestKey(spoke, reserveId);
    uint32 savedKey = _savedKey(spoke, reserveId);

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, reserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReserveConfig(reserveId, reserveConfig);
    _expectReserveFrozenUpdated(spoke, reserveId, true, false);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.unfreezeReserve(spokeAddr, hubAddr, underlying);

    assertEq(_configuratorLogCount(), 1);
    assertEq(spoke.getReserveConfig(reserveId), reserveConfig);
    assertEq(_latestKey(spoke, reserveId), latestKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor, 0);
    assertEq(_savedKey(spoke, reserveId), savedKey);
  }

  function test_freezeSpoke_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.freezeSpoke(spokeAddr);
  }

  function test_freezeSpoke() public {
    uint256 reserveCount = spoke.getReserveCount();
    ISpoke.DynamicReserveConfig[] memory oldConfigs = new ISpoke.DynamicReserveConfig[](
      reserveCount
    );
    uint32[] memory oldKeys = new uint32[](reserveCount);

    vm.recordLogs();
    for (uint256 id; id < reserveCount; ++id) {
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(id);
      reserveConfig.frozen = true;
      oldKeys[id] = _latestKey(spoke, id);
      oldConfigs[id] = _getLatestDynamicReserveConfig(spoke, id);
      ISpoke.DynamicReserveConfig memory newConfig = _getLatestDynamicReserveConfig(spoke, id);
      newConfig.collateralFactor = 0;

      vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig)));
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(id, reserveConfig);
      _expectReserveFrozenUpdated(spoke, id, false, true);
      _expectDynamicConfigUpdated(
        spoke,
        id,
        oldKeys[id],
        oldKeys[id] + 1,
        oldConfigs[id],
        newConfig
      );
      _expectSavedDynamicConfigKeyUpdated(spoke, id, 0, oldKeys[id]);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeSpoke(spokeAddr);

    assertEq(_configuratorLogCount(), reserveCount * 5);
    for (uint256 id; id < reserveCount; ++id) {
      assertEq(spoke.getReserveConfig(id).frozen, true);
      assertEq(_latestKey(spoke, id), oldKeys[id] + 1);
      ISpoke.DynamicReserveConfig memory expectedConfig = oldConfigs[id];
      expectedConfig.collateralFactor = 0;
      assertEq(_getLatestDynamicReserveConfig(spoke, id), expectedConfig);
      assertEq(_savedKey(spoke, id), oldKeys[id]);
    }
  }

  function test_unfreezeSpoke_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.unfreezeSpoke(spokeAddr);
  }

  function test_unfreezeSpoke() public {
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeSpoke(spokeAddr);

    uint256 reserveCount = spoke.getReserveCount();
    vm.recordLogs();
    for (uint256 id; id < reserveCount; ++id) {
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(id);
      reserveConfig.frozen = false;
      vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig)));
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(id, reserveConfig);
      _expectReserveFrozenUpdated(spoke, id, true, false);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.unfreezeSpoke(spokeAddr);

    assertEq(_configuratorLogCount(), reserveCount);
    for (uint256 id; id < reserveCount; ++id) {
      assertEq(spoke.getReserveConfig(id).frozen, false);
      assertEq(_getLatestDynamicReserveConfig(spoke, id).collateralFactor, 0);
    }
  }

  function test_zeroCollateralFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.zeroCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_restoreCollateralFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_updatePositionManager_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updatePositionManager(spokeAddr, address(0), true);
  }

  function test_updatePositionManager() public {
    address newPositionManager = makeAddr('NEW_POSITION_MANAGER');
    for (uint256 i = 0; i < 2; i += 1) {
      bool active = (i == 0) ? true : false;
      bool oldActive = spoke.isPositionManagerActive(newPositionManager);
      vm.recordLogs();
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updatePositionManager, (newPositionManager, active))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdatePositionManager(newPositionManager, active);
      vm.expectEmit(address(spokeConfigurator));
      emit ISpokeConfigurator.PositionManagerUpdated(
        spokeAddr,
        newPositionManager,
        oldActive,
        active
      );
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      spokeConfigurator.updatePositionManager(spokeAddr, newPositionManager, active);
      assertEq(_configuratorLogCount(), 1);
      assertEq(spoke.isPositionManagerActive(newPositionManager), active);
    }
  }

  function test_reserveFunctions_revertsWith_AssetNotListed() public {
    bytes[] memory calls = _reserveCalldata(unlistedUnderlying);
    for (uint256 i; i < calls.length; ++i) {
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(calls[i]);
      assertFalse(ok);
      assertEq(ret, abi.encodeWithSelector(IHub.AssetNotListed.selector));
    }

    vm.expectRevert(IHub.AssetNotListed.selector, hubAddr);
    spokeConfigurator.getSavedDynamicConfigKey(spokeAddr, hubAddr, unlistedUnderlying);
  }

  function test_reserveFunctions_revertsWith_ReserveNotListed() public {
    // usdz is listed on hub1 but has no reserve on spoke1
    address usdz = address(tokenList.usdz);
    assertEq(hub1.getAssetId(usdz), usdzAssetId);

    bytes[] memory calls = _reserveCalldata(usdz);
    for (uint256 i; i < calls.length; ++i) {
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(calls[i]);
      assertFalse(ok);
      assertEq(ret, abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    }

    vm.expectRevert(ISpoke.ReserveNotListed.selector, spokeAddr);
    spokeConfigurator.getSavedDynamicConfigKey(spokeAddr, hubAddr, usdz);
  }

  function test_getSavedDynamicConfigKey_defaultsToZero() public view {
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      assertEq(_savedKey(spoke, id), 0);
    }
  }

  function _reserveCalldata(address targetUnderlying) internal returns (bytes[] memory calls) {
    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 5_00
    });

    calls = new bytes[](18);
    calls[0] = abi.encodeCall(
      ISpokeConfigurator.updateReservePriceSource,
      (spokeAddr, hubAddr, targetUnderlying, newPriceSource)
    );
    calls[1] = abi.encodeCall(
      ISpokeConfigurator.updatePaused,
      (spokeAddr, hubAddr, targetUnderlying, true)
    );
    calls[2] = abi.encodeCall(
      ISpokeConfigurator.updateBorrowable,
      (spokeAddr, hubAddr, targetUnderlying, false)
    );
    calls[3] = abi.encodeCall(
      ISpokeConfigurator.updateReceiveSharesEnabled,
      (spokeAddr, hubAddr, targetUnderlying, false)
    );
    calls[4] = abi.encodeCall(
      ISpokeConfigurator.updateCollateralRisk,
      (spokeAddr, hubAddr, targetUnderlying, 50_00)
    );
    calls[5] = abi.encodeCall(
      ISpokeConfigurator.addCollateralFactor,
      (spokeAddr, hubAddr, targetUnderlying, 75_00)
    );
    calls[6] = abi.encodeCall(
      ISpokeConfigurator.updateCollateralFactor,
      (spokeAddr, hubAddr, targetUnderlying, 0, 70_00)
    );
    calls[7] = abi.encodeCall(
      ISpokeConfigurator.addMaxLiquidationBonus,
      (spokeAddr, hubAddr, targetUnderlying, 115_00)
    );
    calls[8] = abi.encodeCall(
      ISpokeConfigurator.updateMaxLiquidationBonus,
      (spokeAddr, hubAddr, targetUnderlying, 0, 112_00)
    );
    calls[9] = abi.encodeCall(
      ISpokeConfigurator.addLiquidationFee,
      (spokeAddr, hubAddr, targetUnderlying, 8_00)
    );
    calls[10] = abi.encodeCall(
      ISpokeConfigurator.updateLiquidationFee,
      (spokeAddr, hubAddr, targetUnderlying, 0, 6_00)
    );
    calls[11] = abi.encodeCall(
      ISpokeConfigurator.addDynamicReserveConfig,
      (spokeAddr, hubAddr, targetUnderlying, dynamicConfig)
    );
    calls[12] = abi.encodeCall(
      ISpokeConfigurator.updateDynamicReserveConfig,
      (spokeAddr, hubAddr, targetUnderlying, 0, dynamicConfig)
    );
    calls[13] = abi.encodeCall(
      ISpokeConfigurator.pauseReserve,
      (spokeAddr, hubAddr, targetUnderlying)
    );
    calls[14] = abi.encodeCall(
      ISpokeConfigurator.freezeReserve,
      (spokeAddr, hubAddr, targetUnderlying)
    );
    calls[15] = abi.encodeCall(
      ISpokeConfigurator.unfreezeReserve,
      (spokeAddr, hubAddr, targetUnderlying)
    );
    calls[16] = abi.encodeCall(
      ISpokeConfigurator.zeroCollateralFactor,
      (spokeAddr, hubAddr, targetUnderlying)
    );
    calls[17] = abi.encodeCall(
      ISpokeConfigurator.restoreCollateralFactor,
      (spokeAddr, hubAddr, targetUnderlying)
    );
  }
}
