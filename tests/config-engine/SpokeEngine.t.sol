// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {Roles} from 'src/libraries/types/Roles.sol';

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
    uint256 reserveId = reserveIds[0][0];

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = _defaultReserveConfigUpdate();

    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));

    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(reserveId);
    assertEq(config.collateralRisk, 5000);
    assertFalse(config.paused);
    assertFalse(config.frozen);
    assertTrue(config.borrowable);
    assertTrue(config.receiveSharesEnabled);
  }

  function test_executeSpokeReserveConfigUpdates_allKeepCurrent() public {
    uint256 reserveId = reserveIds[0][0];
    ISpoke.ReserveConfig memory before_ = spoke1().getReserveConfig(reserveId);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
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

    ISpoke.ReserveConfig memory after_ = spoke1().getReserveConfig(reserveId);
    assertEq(after_.collateralRisk, before_.collateralRisk);
    assertEq(after_.paused, before_.paused);
    assertEq(after_.frozen, before_.frozen);
    assertEq(after_.borrowable, before_.borrowable);
    assertEq(after_.receiveSharesEnabled, before_.receiveSharesEnabled);
  }

  function test_executeSpokeReserveConfigUpdates_onlyCollateralRisk() public {
    uint256 reserveId = reserveIds[0][0];
    ISpoke.ReserveConfig memory before_ = spoke1().getReserveConfig(reserveId);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
        collateralRisk: 7500,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(ISpokeConfigurator.updateCollateralRisk, (address(spoke1()), reserveId, 7500))
    );
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));

    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(reserveId);
    assertEq(config.collateralRisk, 7500);
    assertEq(config.paused, before_.paused);
    assertEq(config.frozen, before_.frozen);
    assertEq(config.borrowable, before_.borrowable);
    assertEq(config.receiveSharesEnabled, before_.receiveSharesEnabled);
  }

  function test_fuzz_executeSpokeReserveConfigUpdates_onlyCollateralRisk(
    uint256 collateralRisk
  ) public {
    collateralRisk = bound(collateralRisk, 0, 100_000);
    uint256 reserveId = reserveIds[0][0];
    ISpoke.ReserveConfig memory before_ = spoke1().getReserveConfig(reserveId);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
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

    ISpoke.ReserveConfig memory after_ = spoke1().getReserveConfig(reserveId);
    assertEq(after_.collateralRisk, collateralRisk);
    assertEq(after_.paused, before_.paused);
    assertEq(after_.frozen, before_.frozen);
    assertEq(after_.borrowable, before_.borrowable);
    assertEq(after_.receiveSharesEnabled, before_.receiveSharesEnabled);
  }

  function test_executeSpokeReserveConfigUpdates_onlyPriceSource() public {
    address newPriceFeed = address(new MockPriceFeed(8, 'NEW', 3000e8));

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
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

    uint256 reserveId = reserveIds[0][0];
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
    update.liquidationBonusFactor = 9000;

    ISpoke.LiquidationConfig memory expectedConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: uint128(1.10e18),
      healthFactorForMaxBonus: uint64(0.90e18),
      liquidationBonusFactor: 9000
    });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(
        ISpokeConfigurator.updateLiquidationConfig,
        (address(spoke1()), expectedConfig)
      )
    );

    vm.expectEmit(false, false, false, true, address(spoke1()));
    emit ISpoke.UpdateLiquidationConfig(expectedConfig);

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    _assertLiquidationConfig(expectedConfig);
  }

  function test_fuzz_executeSpokeLiquidationConfigUpdates_allSet(
    uint256 thf,
    uint256 hfmb,
    uint256 lbf
  ) public {
    thf = bound(thf, 1e18, type(uint128).max);
    hfmb = bound(hfmb, 1, 1e18 - 1);
    lbf = bound(lbf, 0, 10_000);

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        targetHealthFactor: thf,
        healthFactorForMaxBonus: hfmb,
        liquidationBonusFactor: lbf
      });

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory after_ = spoke1().getLiquidationConfig();
    assertEq(after_.targetHealthFactor, uint128(thf));
    assertEq(after_.healthFactorForMaxBonus, uint64(hfmb));
    assertEq(after_.liquidationBonusFactor, lbf);
  }

  function test_executeSpokeLiquidationConfigUpdates_targetOnly() public {
    ISpoke.LiquidationConfig memory before_ = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
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

    ISpoke.LiquidationConfig memory after_ = spoke1().getLiquidationConfig();
    assertEq(after_.targetHealthFactor, uint128(1.15e18));
    assertEq(after_.healthFactorForMaxBonus, before_.healthFactorForMaxBonus);
    assertEq(after_.liquidationBonusFactor, before_.liquidationBonusFactor);
  }

  function test_fuzz_executeSpokeLiquidationConfigUpdates_targetOnly(uint256 thf) public {
    thf = bound(thf, 1e18, type(uint128).max);
    ISpoke.LiquidationConfig memory before_ = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        targetHealthFactor: thf,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory after_ = spoke1().getLiquidationConfig();
    assertEq(after_.targetHealthFactor, uint128(thf));
    assertEq(after_.healthFactorForMaxBonus, before_.healthFactorForMaxBonus);
    assertEq(after_.liquidationBonusFactor, before_.liquidationBonusFactor);
  }

  function test_executeSpokeLiquidationConfigUpdates_maxBonusOnly() public {
    ISpoke.LiquidationConfig memory before_ = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
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

    ISpoke.LiquidationConfig memory after_ = spoke1().getLiquidationConfig();
    assertEq(after_.targetHealthFactor, before_.targetHealthFactor);
    assertEq(after_.healthFactorForMaxBonus, uint64(0.85e18));
    assertEq(after_.liquidationBonusFactor, before_.liquidationBonusFactor);
  }

  function test_fuzz_executeSpokeLiquidationConfigUpdates_maxBonusOnly(uint256 hfmb) public {
    hfmb = bound(hfmb, 1, 1e18 - 1);
    ISpoke.LiquidationConfig memory before_ = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: hfmb,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory after_ = spoke1().getLiquidationConfig();
    assertEq(after_.targetHealthFactor, before_.targetHealthFactor);
    assertEq(after_.healthFactorForMaxBonus, uint64(hfmb));
    assertEq(after_.liquidationBonusFactor, before_.liquidationBonusFactor);
  }

  function test_executeSpokeLiquidationConfigUpdates_bonusFactorOnly() public {
    ISpoke.LiquidationConfig memory before_ = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: 8000
      });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(ISpokeConfigurator.updateLiquidationBonusFactor, (address(spoke1()), 8000))
    );
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory after_ = spoke1().getLiquidationConfig();
    assertEq(after_.targetHealthFactor, before_.targetHealthFactor);
    assertEq(after_.healthFactorForMaxBonus, before_.healthFactorForMaxBonus);
    assertEq(after_.liquidationBonusFactor, 8000);
  }

  function test_fuzz_executeSpokeLiquidationConfigUpdates_bonusFactorOnly(uint256 lbf) public {
    lbf = bound(lbf, 0, 10_000);
    ISpoke.LiquidationConfig memory before_ = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: lbf
      });

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));

    ISpoke.LiquidationConfig memory after_ = spoke1().getLiquidationConfig();
    assertEq(after_.targetHealthFactor, before_.targetHealthFactor);
    assertEq(after_.healthFactorForMaxBonus, before_.healthFactorForMaxBonus);
    assertEq(after_.liquidationBonusFactor, lbf);
  }

  function test_executeSpokeLiquidationConfigUpdates_noneSet() public {
    ISpoke.LiquidationConfig memory before_ = spoke1().getLiquidationConfig();

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    _assertExactEventCount(0);

    ISpoke.LiquidationConfig memory after_ = spoke1().getLiquidationConfig();
    assertEq(after_.targetHealthFactor, before_.targetHealthFactor);
    assertEq(after_.healthFactorForMaxBonus, before_.healthFactorForMaxBonus);
    assertEq(after_.liquidationBonusFactor, before_.liquidationBonusFactor);
  }

  function test_executeSpokeDynamicReserveConfigUpdates_allUpdated() public {
    uint256 reserveId = reserveIds[0][0];

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();
    update.collateralFactor = 9000;
    update.maxLiquidationBonus = 11000;
    update.liquidationFee = 500;

    ISpoke.DynamicReserveConfig memory expectedDynConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 9000,
      maxLiquidationBonus: 11000,
      liquidationFee: 500
    });

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(
        ISpokeConfigurator.updateDynamicReserveConfig,
        (address(spoke1()), reserveId, uint32(DYNAMIC_CONFIG_KEY), expectedDynConfig)
      )
    );

    vm.expectEmit(true, true, false, true, address(spoke1()));
    emit ISpoke.UpdateDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY),
      expectedDynConfig
    );

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    _assertDynamicReserveConfig(reserveId, uint32(DYNAMIC_CONFIG_KEY), expectedDynConfig);
  }

  function test_executeSpokeDynamicReserveConfigUpdates_allKeepCurrent() public {
    uint256 reserveId = reserveIds[0][0];
    ISpoke.DynamicReserveConfig memory before_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
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

    _assertDynamicReserveConfig(reserveId, uint32(DYNAMIC_CONFIG_KEY), before_);
  }

  function test_executeSpokeDynamicReserveConfigUpdates_partialUpdate() public {
    uint256 reserveId = reserveIds[0][0];
    ISpoke.DynamicReserveConfig memory before_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: 9000,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: 500
      });

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    ISpoke.DynamicReserveConfig memory after_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(after_.collateralFactor, 9000);
    assertEq(after_.maxLiquidationBonus, before_.maxLiquidationBonus);
    assertEq(after_.liquidationFee, 500);
  }

  function test_fuzz_executeSpokeDynamicReserveConfigUpdates_liquidationFee(
    uint256 liquidationFee
  ) public {
    liquidationFee = bound(liquidationFee, 0, 10_000);
    uint256 reserveId = reserveIds[0][0];
    ISpoke.DynamicReserveConfig memory before_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: EngineFlags.KEEP_CURRENT,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: liquidationFee
      });

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    ISpoke.DynamicReserveConfig memory after_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(after_.liquidationFee, liquidationFee);
    assertEq(after_.collateralFactor, before_.collateralFactor);
    assertEq(after_.maxLiquidationBonus, before_.maxLiquidationBonus);
  }

  function test_fuzz_executeSpokeDynamicReserveConfigUpdates_collateralFactor(
    uint256 collateralFactor
  ) public {
    uint256 reserveId = reserveIds[0][0];
    ISpoke.DynamicReserveConfig memory before_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    uint256 maxCf = (10_000 * 10_000 - 10_000) / before_.maxLiquidationBonus;
    collateralFactor = bound(collateralFactor, 1, maxCf);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: collateralFactor,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    ISpoke.DynamicReserveConfig memory after_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(after_.collateralFactor, collateralFactor);
    assertEq(after_.maxLiquidationBonus, before_.maxLiquidationBonus);
    assertEq(after_.liquidationFee, before_.liquidationFee);
  }

  function test_fuzz_executeSpokeDynamicReserveConfigUpdates_maxLiquidationBonus(
    uint256 mlb
  ) public {
    uint256 reserveId = reserveIds[0][0];
    ISpoke.DynamicReserveConfig memory before_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    uint256 maxMlb = (10_000 * 10_000 - 10_000) / before_.collateralFactor;
    mlb = bound(mlb, 10_000, maxMlb);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
        spoke: address(spoke1()),
        hub: address(hub1()),
        underlying: address(weth),
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: EngineFlags.KEEP_CURRENT,
        maxLiquidationBonus: mlb,
        liquidationFee: EngineFlags.KEEP_CURRENT
      });

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));

    ISpoke.DynamicReserveConfig memory after_ = spoke1().getDynamicReserveConfig(
      reserveId,
      uint32(DYNAMIC_CONFIG_KEY)
    );
    assertEq(after_.maxLiquidationBonus, mlb);
    assertEq(after_.collateralFactor, before_.collateralFactor);
    assertEq(after_.liquidationFee, before_.liquidationFee);
  }

  function test_executeSpokeReserveListings_concrete() public {
    uint256 newAssetId = _seedAsset(hub1(), irStrategy1(), address(newToken), 18);
    _seedSpokeOnAsset(hub1(), newAssetId, spoke1());

    address newPriceFeed = address(priceFeedNew);

    uint256 reserveCountBefore = spoke1().getReserveCount();

    IAaveV4ConfigEngine.ReserveListing memory listing = IAaveV4ConfigEngine.ReserveListing({
      spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(newToken),
      priceSource: newPriceFeed,
      config: ISpoke.ReserveConfig({
        collateralRisk: 5000,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 8000,
        maxLiquidationBonus: 10500,
        liquidationFee: 200
      })
    });

    engine.executeSpokeReserveListings(_toReserveListingArray(listing));

    assertEq(spoke1().getReserveCount(), reserveCountBefore + 1);
    uint256 newReserveId = reserveCountBefore;
    ISpoke.ReserveConfig memory config = spoke1().getReserveConfig(newReserveId);
    assertEq(config.collateralRisk, 5000);
    assertTrue(config.borrowable);
  }

  function test_executeSpokeDynamicReserveConfigAdditions_concrete() public {
    uint256 reserveId = reserveIds[0][0];

    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();

    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );

    ISpoke.DynamicReserveConfig memory dynConfig = spoke1().getDynamicReserveConfig(
      reserveId,
      1 // second key (first is key 0 from seeding)
    );
    assertEq(dynConfig.collateralFactor, 8000);
    assertEq(dynConfig.maxLiquidationBonus, 10500);
    assertEq(dynConfig.liquidationFee, 200);
  }

  function test_executeSpokePositionManagerUpdates_concrete() public {
    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();

    vm.expectCall(
      address(spokeConfigurator),
      abi.encodeCall(
        ISpokeConfigurator.updatePositionManager,
        (address(spoke1()), address(positionManager), true)
      )
    );

    vm.expectEmit(true, false, false, true, address(spoke1()));
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
        spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
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
      spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
      spoke: address(spoke1()),
      hub: address(hub1()),
      underlying: address(weth),
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: 7000,
      paused: EngineFlags.KEEP_CURRENT,
      frozen: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });

    updates[1] = IAaveV4ConfigEngine.ReserveConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
      spoke: address(spoke2()),
      hub: address(hub1()),
      underlying: address(weth),
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: 8000,
      paused: EngineFlags.KEEP_CURRENT,
      frozen: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });

    engine.executeSpokeReserveConfigUpdates(updates);

    ISpoke.ReserveConfig memory config1 = spoke1().getReserveConfig(reserveIds[0][0]);
    assertEq(config1.collateralRisk, 7000);

    ISpoke.ReserveConfig memory config2 = spoke2().getReserveConfig(reserveIds[1][0]);
    assertEq(config2.collateralRisk, 8000);
  }

  function test_executeSpokeLiquidationConfigUpdates_multipleSpokes() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](2);

    updates[0] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
      spoke: address(spoke1()),
      targetHealthFactor: 1.20e18,
      healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT
    });

    updates[1] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(address(spokeConfigurator)),
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
}
