// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

contract SpokeEngineTest is BaseConfigEngineTest {
  function setUp() public override {
    super.setUp();
    _seedFullEnvironment();
  }

  function _assertReserveConfig(
    uint256 reserveId,
    ISpoke.ReserveConfig memory expected
  ) internal view {
    ISpoke.ReserveConfig memory actual = spoke1().getReserveConfig(reserveId);
    assertEq(actual.collateralRisk, expected.collateralRisk);
    assertEq(actual.paused, expected.paused);
    assertEq(actual.frozen, expected.frozen);
    assertEq(actual.borrowable, expected.borrowable);
    assertEq(actual.receiveSharesEnabled, expected.receiveSharesEnabled);
  }

  function _assertLiquidationConfig(ISpoke.LiquidationConfig memory expected) internal view {
    ISpoke.LiquidationConfig memory actual = spoke1().getLiquidationConfig();
    assertEq(actual.targetHealthFactor, expected.targetHealthFactor);
    assertEq(actual.healthFactorForMaxBonus, expected.healthFactorForMaxBonus);
    assertEq(actual.liquidationBonusFactor, expected.liquidationBonusFactor);
  }

  function _assertDynamicReserveConfig(
    uint256 reserveId,
    uint32 key,
    ISpoke.DynamicReserveConfig memory expected
  ) internal view {
    ISpoke.DynamicReserveConfig memory actual = spoke1().getDynamicReserveConfig(reserveId, key);
    assertEq(actual.collateralFactor, expected.collateralFactor);
    assertEq(actual.maxLiquidationBonus, expected.maxLiquidationBonus);
    assertEq(actual.liquidationFee, expected.liquidationFee);
  }

  function test_executeSpokeReserveConfigUpdates_allSet() public {
    uint256 reserveId = _getReserveId(0, 0);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = _defaultReserveConfigUpdate();

    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));

    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(reserveId);
    assertEq(config.collateralRisk, 50_00);
    assertFalse(config.paused);
    assertFalse(config.frozen);
    assertTrue(config.borrowable);
    assertTrue(config.receiveSharesEnabled);
  }

  function test_executeSpokeReserveConfigUpdates_allKeepCurrent() public {
    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.ReserveConfig memory reserveConfigBefore = spoke1().getReserveConfig(reserveId);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
        collateralRisk: EngineFlags.KEEP_CURRENT,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));

    ISpoke.ReserveConfig memory reserveConfigAfter = spoke1().getReserveConfig(reserveId);
    assertEq(reserveConfigAfter.collateralRisk, reserveConfigBefore.collateralRisk);
    assertEq(reserveConfigAfter.paused, reserveConfigBefore.paused);
    assertEq(reserveConfigAfter.frozen, reserveConfigBefore.frozen);
    assertEq(reserveConfigAfter.borrowable, reserveConfigBefore.borrowable);
    assertEq(reserveConfigAfter.receiveSharesEnabled, reserveConfigBefore.receiveSharesEnabled);
  }

  function test_executeSpokeReserveConfigUpdates_onlyCollateralRisk() public {
    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.ReserveConfig memory reserveConfigBefore = spoke1().getReserveConfig(reserveId);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
        collateralRisk: 75_00,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(ISpokeConfigurator.updateCollateralRisk, (address(spoke1()), reserveId, 75_00))
    );
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));

    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(reserveId);
    assertEq(config.collateralRisk, 75_00);
    assertEq(config.paused, reserveConfigBefore.paused);
    assertEq(config.frozen, reserveConfigBefore.frozen);
    assertEq(config.borrowable, reserveConfigBefore.borrowable);
    assertEq(config.receiveSharesEnabled, reserveConfigBefore.receiveSharesEnabled);
  }

  function test_fuzz_executeSpokeReserveConfigUpdates_onlyCollateralRisk(
    uint256 collateralRisk
  ) public {
    collateralRisk = bound(collateralRisk, 0, 100_000);
    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.ReserveConfig memory reserveConfigBefore = spoke1().getReserveConfig(reserveId);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
        collateralRisk: collateralRisk,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));

    ISpoke.ReserveConfig memory reserveConfigAfter = spoke1().getReserveConfig(reserveId);
    assertEq(reserveConfigAfter.collateralRisk, collateralRisk);
    assertEq(reserveConfigAfter.paused, reserveConfigBefore.paused);
    assertEq(reserveConfigAfter.frozen, reserveConfigBefore.frozen);
    assertEq(reserveConfigAfter.borrowable, reserveConfigBefore.borrowable);
    assertEq(reserveConfigAfter.receiveSharesEnabled, reserveConfigBefore.receiveSharesEnabled);
  }

  function test_executeSpokeReserveConfigUpdates_onlyPriceSource() public {
    address newPriceFeed = address(new MockPriceFeed(8, 'NEW', 3000e8));

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        priceSource: newPriceFeed,
        collateralRisk: EngineFlags.KEEP_CURRENT,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    uint256 reserveId = _getReserveId(0, 0);
    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(
        ISpokeConfigurator.updateReservePriceSource,
        (address(spoke1()), reserveId, newPriceFeed)
      )
    );
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));

    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(reserveId);
    assertEq(config.collateralRisk, 15_00); // unchanged
  }

  function test_executeSpokeLiquidationConfigUpdates_allSet() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = _defaultLiquidationConfigUpdate();
    update.targetHealthFactor = 1.10e18;
    update.healthFactorForMaxBonus = 0.90e18;
    update.liquidationBonusFactor = 90_00;

    ISpoke.LiquidationConfig memory expectedConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: uint128(1.10e18),
      healthFactorForMaxBonus: uint64(0.90e18),
      liquidationBonusFactor: 90_00
    });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(
        ISpokeConfigurator.updateLiquidationConfig,
        (address(spoke1()), expectedConfig)
      )
    );

    vm.expectEmit(address(spoke1()));
    emit ISpoke.UpdateLiquidationConfig(expectedConfig);

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    _assertLiquidationConfig(expectedConfig);
  }

  function test_fuzz_executeSpokeLiquidationConfigUpdates_allSet(
    uint256 targetHealthFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor
  ) public {
    targetHealthFactor = bound(targetHealthFactor, 1e18, type(uint128).max);
    healthFactorForMaxBonus = bound(healthFactorForMaxBonus, 1, 1e18 - 1);
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, 10_000);

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: targetHealthFactor,
        healthFactorForMaxBonus: healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationBonusFactor
      });

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory liqConfigAfter = spoke1().getLiquidationConfig();
    assertEq(liqConfigAfter.targetHealthFactor, uint128(targetHealthFactor));
    assertEq(liqConfigAfter.healthFactorForMaxBonus, uint64(healthFactorForMaxBonus));
    assertEq(liqConfigAfter.liquidationBonusFactor, liquidationBonusFactor);
  }

  function test_executeSpokeLiquidationConfigUpdates_targetOnly() public {
    ISpoke.LiquidationConfig memory liqConfigBefore = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: 1.15e18,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(
        ISpokeConfigurator.updateLiquidationTargetHealthFactor,
        (address(spoke1()), 1.15e18)
      )
    );
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory liqConfigAfter = spoke1().getLiquidationConfig();
    assertEq(liqConfigAfter.targetHealthFactor, uint128(1.15e18));
    assertEq(liqConfigAfter.healthFactorForMaxBonus, liqConfigBefore.healthFactorForMaxBonus);
    assertEq(liqConfigAfter.liquidationBonusFactor, liqConfigBefore.liquidationBonusFactor);
  }

  function test_fuzz_executeSpokeLiquidationConfigUpdates_targetOnly(
    uint256 targetHealthFactor
  ) public {
    targetHealthFactor = bound(targetHealthFactor, 1e18, type(uint128).max);
    ISpoke.LiquidationConfig memory liqConfigBefore = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: targetHealthFactor,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory liqConfigAfter = spoke1().getLiquidationConfig();
    assertEq(liqConfigAfter.targetHealthFactor, uint128(targetHealthFactor));
    assertEq(liqConfigAfter.healthFactorForMaxBonus, liqConfigBefore.healthFactorForMaxBonus);
    assertEq(liqConfigAfter.liquidationBonusFactor, liqConfigBefore.liquidationBonusFactor);
  }

  function test_executeSpokeLiquidationConfigUpdates_maxBonusOnly() public {
    ISpoke.LiquidationConfig memory liqConfigBefore = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: 0.85e18,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(ISpokeConfigurator.updateHealthFactorForMaxBonus, (address(spoke1()), 0.85e18))
    );
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory liqConfigAfter = spoke1().getLiquidationConfig();
    assertEq(liqConfigAfter.targetHealthFactor, liqConfigBefore.targetHealthFactor);
    assertEq(liqConfigAfter.healthFactorForMaxBonus, uint64(0.85e18));
    assertEq(liqConfigAfter.liquidationBonusFactor, liqConfigBefore.liquidationBonusFactor);
  }

  function test_fuzz_executeSpokeLiquidationConfigUpdates_maxBonusOnly(
    uint256 healthFactorForMaxBonus
  ) public {
    healthFactorForMaxBonus = bound(healthFactorForMaxBonus, 1, 1e18 - 1);
    ISpoke.LiquidationConfig memory liqConfigBefore = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: healthFactorForMaxBonus,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory liqConfigAfter = spoke1().getLiquidationConfig();
    assertEq(liqConfigAfter.targetHealthFactor, liqConfigBefore.targetHealthFactor);
    assertEq(liqConfigAfter.healthFactorForMaxBonus, uint64(healthFactorForMaxBonus));
    assertEq(liqConfigAfter.liquidationBonusFactor, liqConfigBefore.liquidationBonusFactor);
  }

  function test_executeSpokeLiquidationConfigUpdates_bonusFactorOnly() public {
    ISpoke.LiquidationConfig memory liqConfigBefore = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: 80_00
      });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(ISpokeConfigurator.updateLiquidationBonusFactor, (address(spoke1()), 80_00))
    );
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory liqConfigAfter = spoke1().getLiquidationConfig();
    assertEq(liqConfigAfter.targetHealthFactor, liqConfigBefore.targetHealthFactor);
    assertEq(liqConfigAfter.healthFactorForMaxBonus, liqConfigBefore.healthFactorForMaxBonus);
    assertEq(liqConfigAfter.liquidationBonusFactor, 80_00);
  }

  function test_fuzz_executeSpokeLiquidationConfigUpdates_bonusFactorOnly(
    uint256 liquidationBonusFactor
  ) public {
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, 10_000);
    ISpoke.LiquidationConfig memory liqConfigBefore = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: liquidationBonusFactor
      });

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory liqConfigAfter = spoke1().getLiquidationConfig();
    assertEq(liqConfigAfter.targetHealthFactor, liqConfigBefore.targetHealthFactor);
    assertEq(liqConfigAfter.healthFactorForMaxBonus, liqConfigBefore.healthFactorForMaxBonus);
    assertEq(liqConfigAfter.liquidationBonusFactor, liquidationBonusFactor);
  }

  function test_executeSpokeLiquidationConfigUpdates_noneSet() public {
    ISpoke.LiquidationConfig memory liqConfigBefore = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    _assertExactEventCount(0);

    ISpoke.LiquidationConfig memory liqConfigAfter = spoke1().getLiquidationConfig();
    assertEq(liqConfigAfter.targetHealthFactor, liqConfigBefore.targetHealthFactor);
    assertEq(liqConfigAfter.healthFactorForMaxBonus, liqConfigBefore.healthFactorForMaxBonus);
    assertEq(liqConfigAfter.liquidationBonusFactor, liqConfigBefore.liquidationBonusFactor);
  }

  function test_executeSpokeDynamicReserveConfigUpdates_allUpdated() public {
    uint256 reserveId = _getReserveId(0, 0);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();
    update.collateralFactor = 90_00;
    update.maxLiquidationBonus = 110_00;
    update.liquidationFee = 5_00;

    ISpoke.DynamicReserveConfig memory expectedDynConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 90_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 5_00
    });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(
        ISpokeConfigurator.updateDynamicReserveConfig,
        (address(spoke1()), reserveId, uint32(DYNAMIC_CONFIG_KEY), expectedDynConfig)
      )
    );

    vm.expectEmit(address(spoke1()));
    emit ISpoke.UpdateDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY),
      expectedDynConfig
    );

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    _assertDynamicReserveConfig(reserveId, uint32(DYNAMIC_CONFIG_KEY), expectedDynConfig);
  }

  function test_executeSpokeDynamicReserveConfigUpdates_allKeepCurrent() public {
    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.DynamicReserveConfig memory dynConfigBefore = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: EngineFlags.KEEP_CURRENT,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: EngineFlags.KEEP_CURRENT
      });

    vm.recordLogs();
    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
    _assertExactEventCount(0);

    _assertDynamicReserveConfig(reserveId, uint32(DYNAMIC_CONFIG_KEY), dynConfigBefore);
  }

  function test_executeSpokeDynamicReserveConfigUpdates_partialUpdate() public {
    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.DynamicReserveConfig memory dynConfigBefore = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: 90_00,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: 5_00
      });

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    ISpoke.DynamicReserveConfig memory dynConfigAfter = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(dynConfigAfter.collateralFactor, 90_00);
    assertEq(dynConfigAfter.maxLiquidationBonus, dynConfigBefore.maxLiquidationBonus);
    assertEq(dynConfigAfter.liquidationFee, 5_00);
  }

  function test_fuzz_executeSpokeDynamicReserveConfigUpdates_liquidationFee(
    uint256 liquidationFee
  ) public {
    liquidationFee = bound(liquidationFee, 0, 10_000);
    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.DynamicReserveConfig memory dynConfigBefore = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: EngineFlags.KEEP_CURRENT,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: liquidationFee
      });

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    ISpoke.DynamicReserveConfig memory dynConfigAfter = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(dynConfigAfter.liquidationFee, liquidationFee);
    assertEq(dynConfigAfter.collateralFactor, dynConfigBefore.collateralFactor);
    assertEq(dynConfigAfter.maxLiquidationBonus, dynConfigBefore.maxLiquidationBonus);
  }

  function test_fuzz_executeSpokeDynamicReserveConfigUpdates_collateralFactor(
    uint256 collateralFactor
  ) public {
    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.DynamicReserveConfig memory dynConfigBefore = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    uint256 maxCf = (10_000 * 10_000 - 10_000) / dynConfigBefore.maxLiquidationBonus;
    collateralFactor = bound(collateralFactor, 1, maxCf);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: collateralFactor,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    ISpoke.DynamicReserveConfig memory dynConfigAfter = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(dynConfigAfter.collateralFactor, collateralFactor);
    assertEq(dynConfigAfter.maxLiquidationBonus, dynConfigBefore.maxLiquidationBonus);
    assertEq(dynConfigAfter.liquidationFee, dynConfigBefore.liquidationFee);
  }

  function test_fuzz_executeSpokeDynamicReserveConfigUpdates_maxLiquidationBonus(
    uint256 mlb
  ) public {
    uint256 reserveId = _getReserveId(0, 0);
    ISpoke.DynamicReserveConfig memory dynConfigBefore = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    uint256 maxMlb = (10_000 * 10_000 - 10_000) / dynConfigBefore.collateralFactor;
    mlb = bound(mlb, 10_000, maxMlb);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: EngineFlags.KEEP_CURRENT,
        maxLiquidationBonus: mlb,
        liquidationFee: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    ISpoke.DynamicReserveConfig memory dynConfigAfter = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(dynConfigAfter.maxLiquidationBonus, mlb);
    assertEq(dynConfigAfter.collateralFactor, dynConfigBefore.collateralFactor);
    assertEq(dynConfigAfter.liquidationFee, dynConfigBefore.liquidationFee);
  }

  function test_executeSpokeDynamicReserveConfigAdditions_revert_invalidCollateralFactorAndMaxLiquidationBonus()
    public
  {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();
    addition.dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 99_00,
      maxLiquidationBonus: 105_00,
      liquidationFee: 10_00
    });

    vm.expectRevert(
      abi.encodeWithSelector(ISpoke.InvalidCollateralFactorAndMaxLiquidationBonus.selector)
    );
    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );
  }

  function test_executeSpokeReserveListings() public {
    uint256 newAssetId = _seedAsset(hub1(), irStrategy1(), address(newToken), 18);
    _seedSpokeOnAsset(hub1(), newAssetId, spoke1());

    address newPriceFeed = address(priceFeedNew);

    uint256 reserveCountBefore = spoke1().getReserveCount();

    IAaveV4ConfigEngine.ReserveListing memory listing = IAaveV4ConfigEngine.ReserveListing({
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
        liquidationFee: 2_00
      })
    });

    engine.executeSpokeReserveListings(_toReserveListingArray(listing));

    assertEq(spoke1().getReserveCount(), reserveCountBefore + 1);
    uint256 newReserveId = reserveCountBefore;
    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(newReserveId);
    assertEq(config.collateralRisk, 50_00);
    assertTrue(config.borrowable);
  }

  function test_executeSpokeDynamicReserveConfigAdditions() public {
    uint256 reserveId = _getReserveId(0, 0);

    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();

    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );

    ISpoke.DynamicReserveConfig memory dynConfig = spoke1().getDynamicReserveConfig(
      reserveId,
      1 // second key (first is key 0 from seeding)
    );
    assertEq(dynConfig.collateralFactor, 80_00);
    assertEq(dynConfig.maxLiquidationBonus, 105_00);
    assertEq(dynConfig.liquidationFee, 10_00);
  }

  function test_executeSpokePositionManagerUpdates() public {
    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(
        ISpokeConfigurator.updatePositionManager,
        (address(spoke1()), address(positionManager), true)
      )
    );

    vm.expectEmit(address(spoke1()));
    emit ISpoke.UpdatePositionManager(address(positionManager), true);

    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));

    assertTrue(spoke1().isPositionManagerActive(address(positionManager)));
  }

  function test_executeSpokePositionManagerUpdates_deactivate() public {
    engine.executeSpokePositionManagerUpdates(
      _toPositionManagerUpdateArray(_defaultPositionManagerUpdate())
    );
    assertTrue(spoke1().isPositionManagerActive(address(positionManager)));

    IAaveV4ConfigEngine.PositionManagerUpdate memory update = IAaveV4ConfigEngine
      .PositionManagerUpdate({
        spokeConfigurator: spokeConfigurator,
        spoke: address(spoke1()),
        positionManager: address(positionManager),
        active: false
      });

    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));

    assertFalse(spoke1().isPositionManagerActive(address(positionManager)));
  }

  function test_executeSpokeReserveConfigUpdates_multipleSpokes() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](2);

    updates[0] = IAaveV4ConfigEngine.ReserveConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(weth),
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: 70_00,
      paused: EngineFlags.KEEP_CURRENT,
      frozen: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });

    updates[1] = IAaveV4ConfigEngine.ReserveConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke2()),
      hub: address(hub1()),
      underlying: address(weth),
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: 80_00,
      paused: EngineFlags.KEEP_CURRENT,
      frozen: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });

    engine.executeSpokeReserveConfigUpdates(updates);

    ISpoke.ReserveConfig memory config1 = spoke1().getReserveConfig(_getReserveId(0, 0));
    assertEq(config1.collateralRisk, 70_00);

    ISpoke.ReserveConfig memory config2 = spoke2().getReserveConfig(_getReserveId(1, 0));
    assertEq(config2.collateralRisk, 80_00);
  }

  function test_executeSpokeLiquidationConfigUpdates_multipleSpokes() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](2);

    updates[0] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      targetHealthFactor: 1.20e18,
      healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT
    });

    updates[1] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke2()),
      targetHealthFactor: 1.30e18,
      healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT
    });

    engine.executeSpokeLiquidationConfigUpdates(updates);

    ISpoke.LiquidationConfig memory config1 = spoke1().getLiquidationConfig();
    assertEq(config1.targetHealthFactor, uint128(1.20e18));

    ISpoke.LiquidationConfig memory config2 = spoke2().getLiquidationConfig();
    assertEq(config2.targetHealthFactor, uint128(1.30e18));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_multipleReserves() public {
    uint256 reserveId0 = _getReserveId(0, TOKEN_WETH);
    uint256 reserveId1 = _getReserveId(0, TOKEN_USDX);

    ISpoke.DynamicReserveConfig memory dynBefore0 = spoke1().getDynamicReserveConfig(
      reserveId0,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    ISpoke.DynamicReserveConfig memory dynBefore1 = spoke1().getDynamicReserveConfig(
      reserveId1,
      uint32(DYNAMIC_CONFIG_KEY)
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](2);

    updates[0] = IAaveV4ConfigEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(weth),
      dynamicConfigKey: DYNAMIC_CONFIG_KEY,
      collateralFactor: 90_00,
      maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
      liquidationFee: EngineFlags.KEEP_CURRENT
    });

    updates[1] = IAaveV4ConfigEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(usdx),
      dynamicConfigKey: DYNAMIC_CONFIG_KEY,
      collateralFactor: EngineFlags.KEEP_CURRENT,
      maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
      liquidationFee: 3_00
    });

    engine.executeSpokeDynamicReserveConfigUpdates(updates);

    ISpoke.DynamicReserveConfig memory dynAfter0 = spoke1().getDynamicReserveConfig(
      reserveId0,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(dynAfter0.collateralFactor, 90_00);
    assertEq(dynAfter0.maxLiquidationBonus, dynBefore0.maxLiquidationBonus);
    assertEq(dynAfter0.liquidationFee, dynBefore0.liquidationFee);

    ISpoke.DynamicReserveConfig memory dynAfter1 = spoke1().getDynamicReserveConfig(
      reserveId1,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(dynAfter1.collateralFactor, dynBefore1.collateralFactor);
    assertEq(dynAfter1.maxLiquidationBonus, dynBefore1.maxLiquidationBonus);
    assertEq(dynAfter1.liquidationFee, 3_00);
  }

  function test_executeSpokeReserveConfigUpdates_crossSpoke_differentFields() public {
    uint256 reserveIdSpoke1 = _getReserveId(0, TOKEN_WETH);
    uint256 reserveIdSpoke2 = _getReserveId(1, TOKEN_WETH);
    ISpoke.ReserveConfig memory configBefore1 = spoke1().getReserveConfig(reserveIdSpoke1);
    ISpoke.ReserveConfig memory configBefore2 = spoke2().getReserveConfig(reserveIdSpoke2);

    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](2);

    updates[0] = IAaveV4ConfigEngine.ReserveConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(weth),
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: 60_00,
      paused: EngineFlags.KEEP_CURRENT,
      frozen: EngineFlags.ENABLED,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });

    updates[1] = IAaveV4ConfigEngine.ReserveConfigUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke2()),
      hub: address(hub1()),
      underlying: address(weth),
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: EngineFlags.KEEP_CURRENT,
      paused: EngineFlags.ENABLED,
      frozen: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });

    engine.executeSpokeReserveConfigUpdates(updates);

    ISpoke.ReserveConfig memory configAfter1 = spoke1().getReserveConfig(reserveIdSpoke1);
    assertEq(configAfter1.collateralRisk, 60_00);
    assertTrue(configAfter1.frozen);
    assertEq(configAfter1.paused, configBefore1.paused);

    ISpoke.ReserveConfig memory configAfter2 = spoke2().getReserveConfig(reserveIdSpoke2);
    assertEq(configAfter2.collateralRisk, configBefore2.collateralRisk);
    assertTrue(configAfter2.paused);
    assertEq(configAfter2.frozen, configBefore2.frozen);
  }

  function test_executeSpokePositionManagerUpdates_multipleUpdates() public {
    PositionManagerBaseWrapper pm2 = new PositionManagerBaseWrapper(address(engine));

    IAaveV4ConfigEngine.PositionManagerUpdate[]
      memory updates = new IAaveV4ConfigEngine.PositionManagerUpdate[](2);

    updates[0] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      positionManager: address(positionManager),
      active: true
    });

    updates[1] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      positionManager: address(pm2),
      active: true
    });

    engine.executeSpokePositionManagerUpdates(updates);

    assertTrue(spoke1().isPositionManagerActive(address(positionManager)));
    assertTrue(spoke1().isPositionManagerActive(address(pm2)));
  }

  function test_executeSpokeReserveListings_multipleReserves() public {
    TestnetERC20 tokenA = new TestnetERC20('A', 'A', 18);
    TestnetERC20 tokenB = new TestnetERC20('B', 'B', 8);

    uint256 assetIdA = _seedAsset(hub1(), irStrategy1(), address(tokenA), 18);
    uint256 assetIdB = _seedAsset(hub1(), irStrategy1(), address(tokenB), 8);
    _seedSpokeOnAsset(hub1(), assetIdA, spoke1());
    _seedSpokeOnAsset(hub1(), assetIdB, spoke1());

    address priceFeedA = address(new MockPriceFeed(8, 'A/USD', 10e8));
    address priceFeedB = address(new MockPriceFeed(8, 'B/USD', 50e8));

    uint256 reserveCountBefore = spoke1().getReserveCount();

    IAaveV4ConfigEngine.ReserveListing[] memory listings = new IAaveV4ConfigEngine.ReserveListing[](
      2
    );

    listings[0] = IAaveV4ConfigEngine.ReserveListing({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(tokenA),
      priceSource: priceFeedA,
      config: _defaultReserveConfig(),
      dynamicConfig: _defaultDynamicReserveConfig()
    });

    listings[1] = IAaveV4ConfigEngine.ReserveListing({
      spokeConfigurator: spokeConfigurator,
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(tokenB),
      priceSource: priceFeedB,
      config: _defaultReserveConfig(),
      dynamicConfig: _defaultDynamicReserveConfig()
    });

    engine.executeSpokeReserveListings(listings);

    assertEq(spoke1().getReserveCount(), reserveCountBefore + 2);
  }
}
