// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfiguratorTest is SpokeBase {
  using SafeCast for uint256;

  SpokeConfigurator public spokeConfigurator;

  address public spokeAddr;
  ISpoke public spoke;
  uint256 public reserveId;
  uint256 public invalidReserveId;

  function setUp() public virtual override {
    super.setUp();

    spokeConfigurator = new SpokeConfigurator(spoke1.authority());
    setUpSpokeConfiguratorRoles(address(spokeConfigurator), spoke1.authority());

    spokeAddr = address(spoke1);
    spoke = ISpoke(spokeAddr);
    reserveId = 0;
    invalidReserveId = spoke.getReserveCount();
  }

  function test_updateReservePriceSource_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateReservePriceSource(spokeAddr, reserveId, address(0));
  }

  function test_updateReservePriceSource() public {
    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReservePriceSource, (reserveId, newPriceSource))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReservePriceSource(reserveId, newPriceSource);
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateReservePriceSource(spokeAddr, reserveId, newPriceSource);
  }

  function test_updateLiquidationTargetHealthFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateLiquidationTargetHealthFactor(spokeAddr, 0);
  }

  function test_updateLiquidationTargetHealthFactor() public {
    uint128 newTargetHealthFactor = Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2;

    ISpoke.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    expectedLiquidationConfig.targetHealthFactor = newTargetHealthFactor;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateLiquidationConfig(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateLiquidationTargetHealthFactor(spokeAddr, newTargetHealthFactor);

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
    uint64 newHealthFactorForMaxBonus = Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2;

    ISpoke.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    expectedLiquidationConfig.healthFactorForMaxBonus = newHealthFactorForMaxBonus;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateLiquidationConfig(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateHealthFactorForMaxBonus(spokeAddr, newHealthFactorForMaxBonus);

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
    expectedLiquidationConfig.liquidationBonusFactor = newLiquidationBonusFactor;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateLiquidationConfig(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateLiquidationBonusFactor(spokeAddr, newLiquidationBonusFactor);

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
    ISpoke.LiquidationConfig memory newLiquidationConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2,
      healthFactorForMaxBonus: Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2,
      liquidationBonusFactor: PercentageMath.PERCENTAGE_FACTOR.toUint16() / 2
    });

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (newLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateLiquidationConfig(newLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateLiquidationConfig(spokeAddr, newLiquidationConfig);

    assertEq(spoke.getLiquidationConfig(), newLiquidationConfig);
  }

  function test_updateMaxReserves_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateMaxReserves(spokeAddr, 0);
  }

  function test_updateMaxReserves() public {
    uint256 newMaxReserves = vm.randomUint();
    vm.expectEmit(address(spokeConfigurator));
    emit ISpokeConfigurator.UpdateMaxReserves(spokeAddr, newMaxReserves);
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateMaxReserves(spokeAddr, newMaxReserves);

    assertEq(spokeConfigurator.getMaxReserves(spokeAddr), newMaxReserves);
  }

  function test_addReserve_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.addReserve({
      spoke: spokeAddr,
      hub: address(hub1),
      assetId: 0,
      priceSource: address(0),
      config: _getDefaultReserveConfig(15_00),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    });
  }

  function test_addReserve_revertsWith_MaximumReservesReached() public {
    uint256 maxReserves = vm.randomUint(0, spoke.getReserveCount());
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateMaxReserves(spokeAddr, maxReserves);

    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    vm.expectRevert(
      abi.encodeWithSelector(
        ISpokeConfigurator.MaximumReservesReached.selector,
        spokeAddr,
        maxReserves
      )
    );
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.addReserve({
      spoke: spokeAddr,
      hub: address(hub1),
      assetId: usdzAssetId,
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

    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateMaxReserves(spokeAddr, expectedReserveId + 1);

    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    ISpoke.ReserveConfig memory config = _getDefaultReserveConfig(15_00);
    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 100_00,
      liquidationFee: 0
    });

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.addReserve,
        (address(hub1), usdzAssetId, newPriceSource, config, dynamicConfig)
      )
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddReserve(expectedReserveId, usdzAssetId, address(hub1));
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReserveConfig(expectedReserveId, config);
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(expectedReserveId, 0, dynamicConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    uint256 actualReserveId = spokeConfigurator.addReserve({
      spoke: spokeAddr,
      hub: address(hub1),
      assetId: usdzAssetId,
      priceSource: newPriceSource,
      config: config,
      dynamicConfig: dynamicConfig
    });

    assertEq(actualReserveId, expectedReserveId);
  }

  function test_updatePaused_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updatePaused(spokeAddr, reserveId, true);
  }

  function test_updatePaused() public {
    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      expectedReserveConfig.paused = (i == 0) ? false : true;

      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
      vm.prank(SPOKE_CONFIGURATOR);
      spokeConfigurator.updatePaused(spokeAddr, reserveId, expectedReserveConfig.paused);

      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateFrozen_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateFrozen(spokeAddr, reserveId, true);
  }

  function test_updateFrozen() public {
    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      expectedReserveConfig.frozen = (i == 0) ? false : true;

      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
      vm.prank(SPOKE_CONFIGURATOR);
      spokeConfigurator.updateFrozen(spokeAddr, reserveId, expectedReserveConfig.frozen);

      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateBorrowable_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateBorrowable(spokeAddr, reserveId, true);
  }

  function test_updateBorrowable() public {
    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      expectedReserveConfig.borrowable = (i == 0) ? false : true;

      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
      vm.prank(SPOKE_CONFIGURATOR);
      spokeConfigurator.updateBorrowable(spokeAddr, reserveId, expectedReserveConfig.borrowable);

      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateLiquidatable_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateLiquidatable(spokeAddr, reserveId, true);
  }

  function test_updateLiquidatable() public {
    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      expectedReserveConfig.liquidatable = (i == 0) ? false : true;

      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
      vm.prank(SPOKE_CONFIGURATOR);
      spokeConfigurator.updateLiquidatable(
        spokeAddr,
        reserveId,
        expectedReserveConfig.liquidatable
      );

      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateReceiveSharesEnabled_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateReceiveSharesEnabled(spokeAddr, reserveId, false);
  }

  function test_updateReceiveSharesEnabled() public {
    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      expectedReserveConfig.receiveSharesEnabled = (i == 0) ? false : true;

      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
      vm.prank(SPOKE_CONFIGURATOR);
      spokeConfigurator.updateReceiveSharesEnabled(
        spokeAddr,
        reserveId,
        expectedReserveConfig.receiveSharesEnabled
      );

      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateCollateralRisk_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateCollateralRisk(spokeAddr, reserveId, 0);
  }

  function test_updateCollateralRisk() public {
    uint24 newCollateralRisk = Constants.MAX_ALLOWED_COLLATERAL_RISK / 2;

    ISpoke.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.collateralRisk = newCollateralRisk;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateReserveConfig(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateCollateralRisk(spokeAddr, reserveId, newCollateralRisk);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_addCollateralFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.addCollateralFactor(spokeAddr, reserveId, 0);
  }

  function test_addCollateralFactor() public {
    uint16 newCollateralFactor = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 2;

    ISpoke.DynamicReserveConfig
      memory expectedDynamicReserveConfig = _getLatestDynamicReserveConfig(spoke, reserveId);
    expectedDynamicReserveConfig.collateralFactor = newCollateralFactor;

    uint24 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, expectedDynamicReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    uint24 dynamicConfigKey = spokeConfigurator.addCollateralFactor(
      spokeAddr,
      reserveId,
      newCollateralFactor
    );

    assertEq(dynamicConfigKey, expectedConfigKey);
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), expectedDynamicReserveConfig);
  }

  function test_updateCollateralFactor_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateCollateralFactor(spokeAddr, reserveId, 0, 0);
  }

  function test_updateCollateralFactor() public {
    uint16 newCollateralFactor = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 4;

    uint24 dynamicConfigKey = 0;

    ISpoke.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    expectedDynamicReserveConfig.collateralFactor = newCollateralFactor;

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
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateCollateralFactor(
      spokeAddr,
      reserveId,
      dynamicConfigKey,
      newCollateralFactor
    );

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
    spokeConfigurator.addMaxLiquidationBonus(spokeAddr, reserveId, 0);
  }

  function test_addMaxLiquidationBonus() public {
    uint32 newLiquidationBonus = PercentageMath.PERCENTAGE_FACTOR.toUint32() + 1;

    ISpoke.DynamicReserveConfig
      memory expectedDynamicReserveConfig = _getLatestDynamicReserveConfig(spoke, reserveId);
    expectedDynamicReserveConfig.maxLiquidationBonus = newLiquidationBonus;

    uint24 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, expectedDynamicReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    uint24 dynamicConfigKey = spokeConfigurator.addMaxLiquidationBonus(
      spokeAddr,
      reserveId,
      newLiquidationBonus
    );

    assertEq(dynamicConfigKey, expectedConfigKey);
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), expectedDynamicReserveConfig);
  }

  function test_updateMaxLiquidationBonus_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateMaxLiquidationBonus(spokeAddr, reserveId, 0, 0);
  }

  function test_updateMaxLiquidationBonus() public {
    uint32 newLiquidationBonus = PercentageMath.PERCENTAGE_FACTOR.toUint32() + 123;

    uint24 dynamicConfigKey = 0;

    ISpoke.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    expectedDynamicReserveConfig.maxLiquidationBonus = newLiquidationBonus;

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
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateMaxLiquidationBonus(
      spokeAddr,
      reserveId,
      dynamicConfigKey,
      newLiquidationBonus
    );

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
    spokeConfigurator.addLiquidationFee(spokeAddr, reserveId, 0);
  }

  function test_addLiquidationFee() public {
    uint16 newLiquidationFee = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 2;

    ISpoke.DynamicReserveConfig
      memory expectedDynamicReserveConfig = _getLatestDynamicReserveConfig(spoke, reserveId);
    expectedDynamicReserveConfig.liquidationFee = newLiquidationFee;

    uint24 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, expectedDynamicReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    uint24 dynamicConfigKey = spokeConfigurator.addLiquidationFee(
      spokeAddr,
      reserveId,
      newLiquidationFee
    );

    assertEq(dynamicConfigKey, expectedConfigKey);
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), expectedDynamicReserveConfig);
  }

  function test_updateLiquidationFee_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.updateLiquidationFee(spokeAddr, reserveId, 0, 0);
  }

  function test_updateLiquidationFee() public {
    uint16 newLiquidationFee = PercentageMath.PERCENTAGE_FACTOR.toUint16() / 4;

    uint24 dynamicConfigKey = 0;

    ISpoke.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke.getDynamicReserveConfig(
      reserveId,
      dynamicConfigKey
    );
    expectedDynamicReserveConfig.liquidationFee = newLiquidationFee;

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
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateLiquidationFee(
      spokeAddr,
      reserveId,
      dynamicConfigKey,
      newLiquidationFee
    );

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
      reserveId,
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

    uint24 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, newDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, newDynamicReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    uint24 actualConfigKey = spokeConfigurator.addDynamicReserveConfig(
      spokeAddr,
      reserveId,
      newDynamicReserveConfig
    );

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
      reserveId,
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

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.updateDynamicReserveConfig,
        (reserveId, configKeyToUpdate, newDynamicReserveConfig)
      )
    );

    vm.expectEmit(address(spoke));
    emit ISpoke.UpdateDynamicReserveConfig(reserveId, configKeyToUpdate, newDynamicReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.updateDynamicReserveConfig(
      spokeAddr,
      reserveId,
      configKeyToUpdate,
      newDynamicReserveConfig
    );

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
    for (uint256 reserveIdx = 0; reserveIdx < spoke.getReserveCount(); ++reserveIdx) {
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(reserveIdx);
      reserveConfig.paused = true;
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveIdx, reserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(reserveIdx, reserveConfig);
    }

    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.pauseAllReserves(spokeAddr);

    for (uint256 reserveIdx; reserveIdx < spoke.getReserveCount(); ++reserveIdx) {
      assertEq(spoke.getReserveConfig(reserveIdx).paused, true);
    }
  }

  function test_freezeAllReserves_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spokeConfigurator.freezeAllReserves(spokeAddr);
  }

  function test_freezeAllReserves() public {
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      ISpoke.ReserveConfig memory reserveConfig = spoke.getReserveConfig(id);
      reserveConfig.frozen = true;
      vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig)));
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdateReserveConfig(id, reserveConfig);
    }

    vm.prank(SPOKE_CONFIGURATOR);
    spokeConfigurator.freezeAllReserves(spokeAddr);

    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      assertEq(spoke.getReserveConfig(id).frozen, true);
    }
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
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updatePositionManager, (newPositionManager, active))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.UpdatePositionManager(newPositionManager, active);
      vm.prank(SPOKE_CONFIGURATOR);
      spokeConfigurator.updatePositionManager(spokeAddr, newPositionManager, active);
      assertEq(spoke.isPositionManagerActive(newPositionManager), active);
    }
  }
}
