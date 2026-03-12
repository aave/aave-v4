// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

import {MockSpokeConfigurator} from 'tests/mocks/config-engine/MockSpokeConfigurator.sol';

contract SpokeEngineTest is BaseConfigEngineTest {
  function test_executeSpokeReserveConfigUpdates_allSet() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = _defaultReserveConfigUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReservePriceSourceCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      PRICE_SOURCE
    );

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      5000
    );

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePausedCalled(address(mockSpokeReader), RESERVE_ID, false);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateFrozenCalled(address(mockSpokeReader), RESERVE_ID, false);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateBorrowableCalled(address(mockSpokeReader), RESERVE_ID, true);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReceiveSharesEnabledCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      true
    );

    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
  }

  function test_executeSpokeReserveConfigUpdates_allKeepCurrent() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
        collateralRisk: EngineFlags.KEEP_CURRENT,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.recordLogs();
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_executeSpokeReserveConfigUpdates_onlyCollateralRisk() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
        collateralRisk: 7500,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      7500
    );

    vm.recordLogs();
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeReserveConfigUpdates_onlyPriceSource() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        priceSource: PRICE_SOURCE,
        collateralRisk: EngineFlags.KEEP_CURRENT,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReservePriceSourceCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      PRICE_SOURCE
    );

    vm.recordLogs();
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeReserveConfigUpdates_priceSourceKeepCurrent() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
        collateralRisk: 5000,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      5000
    );

    vm.recordLogs();
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
    // Only collateralRisk is emitted, priceSource is skipped
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeReserveConfigUpdates_priceSourceRevert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateReservePriceSource.selector,
      true
    );

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        priceSource: PRICE_SOURCE,
        collateralRisk: EngineFlags.KEEP_CURRENT,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.expectRevert(MockSpokeConfigurator.UpdateReservePriceSourceReverted.selector);
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
  }

  function testFuzz_executeSpokeReserveConfigUpdates(
    address priceSource_,
    uint256 collateralRisk,
    bool paused_,
    bool frozen_,
    bool borrowable_,
    bool receiveSharesEnabled_
  ) public {
    vm.assume(priceSource_ != EngineFlags.KEEP_CURRENT_ADDRESS);
    vm.assume(collateralRisk != EngineFlags.KEEP_CURRENT);
    uint256 paused = EngineFlags.fromBool(paused_);
    uint256 frozen = EngineFlags.fromBool(frozen_);
    uint256 borrowable = EngineFlags.fromBool(borrowable_);
    uint256 receiveSharesEnabled = EngineFlags.fromBool(receiveSharesEnabled_);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        priceSource: priceSource_,
        collateralRisk: collateralRisk,
        paused: paused,
        frozen: frozen,
        borrowable: borrowable,
        receiveSharesEnabled: receiveSharesEnabled
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReservePriceSourceCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      priceSource_
    );

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      collateralRisk
    );

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePausedCalled(address(mockSpokeReader), RESERVE_ID, paused_);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateFrozenCalled(address(mockSpokeReader), RESERVE_ID, frozen_);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateBorrowableCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      borrowable_
    );

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReceiveSharesEnabledCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      receiveSharesEnabled_
    );

    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
  }

  function test_executeSpokeReserveConfigUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updateCollateralRisk.selector, true);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = _defaultReserveConfigUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateCollateralRiskReverted.selector);
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
  }

  function test_executeSpokeLiquidationConfigUpdates_allSet() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = _defaultLiquidationConfigUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationConfigCalled(
      SPOKE,
      uint128(1.05e18),
      uint64(0.95e18),
      uint16(10000)
    );

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
  }

  function test_executeSpokeLiquidationConfigUpdates_targetOnly() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationTargetHealthFactorCalled(SPOKE, 1.05e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeLiquidationConfigUpdates_maxBonusOnly() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateHealthFactorForMaxBonusCalled(SPOKE, 0.95e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeLiquidationConfigUpdates_bonusFactorOnly() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: 10000
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationBonusFactorCalled(SPOKE, 10000);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeLiquidationConfigUpdates_twoOfThree() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationTargetHealthFactorCalled(SPOKE, 1.05e18);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateHealthFactorForMaxBonusCalled(SPOKE, 0.95e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 2);
  }

  function test_executeSpokeLiquidationConfigUpdates_noneSet() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeSpokeLiquidationConfigUpdates(
    uint256 targetHealthFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor
  ) public {
    targetHealthFactor = bound(targetHealthFactor, 0, type(uint128).max);
    healthFactorForMaxBonus = bound(healthFactorForMaxBonus, 0, type(uint64).max);
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, type(uint16).max);

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: targetHealthFactor,
        healthFactorForMaxBonus: healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationBonusFactor
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationConfigCalled(
      SPOKE,
      uint128(targetHealthFactor),
      uint64(healthFactorForMaxBonus),
      uint16(liquidationBonusFactor)
    );

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
  }

  function test_executeSpokeLiquidationConfigUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateLiquidationConfig.selector,
      true
    );

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = _defaultLiquidationConfigUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateLiquidationConfigReverted.selector);
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_allUpdated() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      8000,
      10500,
      1000
    );

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_allKeepCurrent() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: EngineFlags.KEEP_CURRENT,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: EngineFlags.KEEP_CURRENT
      });

    vm.recordLogs();
    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_executeSpokeDynamicReserveConfigUpdates_partialUpdate() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: 9000,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: 500
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      9000,
      10000,
      500
    );

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_revertReader() public {
    mockSpokeReader.setShouldRevertOnRead(true);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();

    vm.expectRevert('MOCK_READ_REVERT');
    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_revertConfigurator() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateDynamicReserveConfig.selector,
      true
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateDynamicReserveConfigReverted.selector);
    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
  }

  function test_executeSpokeReserveListings_concrete() public {
    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddReserveCalled(
      SPOKE,
      address(mockHub),
      ASSET_ID,
      PRICE_SOURCE,
      5000,
      false,
      false,
      true,
      true,
      8000,
      10500,
      200
    );

    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }

  function testFuzz_executeSpokeReserveListings(
    uint24 collateralRisk,
    bool paused,
    bool frozen,
    bool borrowable,
    bool receiveSharesEnabled,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) public {
    IAaveV4ConfigEngine.ReserveListing memory listing = IAaveV4ConfigEngine.ReserveListing({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      hub: address(mockHub),
      underlying: UNDERLYING,
      priceSource: PRICE_SOURCE,
      config: ISpoke.ReserveConfig({
        collateralRisk: collateralRisk,
        paused: paused,
        frozen: frozen,
        borrowable: borrowable,
        receiveSharesEnabled: receiveSharesEnabled
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: collateralFactor,
        maxLiquidationBonus: maxLiquidationBonus,
        liquidationFee: liquidationFee
      })
    });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddReserveCalled(
      SPOKE,
      address(mockHub),
      ASSET_ID,
      PRICE_SOURCE,
      collateralRisk,
      paused,
      frozen,
      borrowable,
      receiveSharesEnabled,
      collateralFactor,
      maxLiquidationBonus,
      liquidationFee
    );

    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }

  function test_executeSpokeReserveListings_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addReserve.selector, true);

    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();

    vm.expectRevert(MockSpokeConfigurator.AddReserveReverted.selector);
    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }

  function test_executeSpokeDynamicReserveConfigAdditions_concrete() public {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      8000,
      10500,
      200
    );

    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );
  }

  function testFuzz_executeSpokeDynamicReserveConfigAdditions(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) public {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition memory addition = IAaveV4ConfigEngine
      .DynamicReserveConfigAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        hub: address(mockHub),
        underlying: UNDERLYING,
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: collateralFactor,
          maxLiquidationBonus: maxLiquidationBonus,
          liquidationFee: liquidationFee
        })
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      collateralFactor,
      maxLiquidationBonus,
      liquidationFee
    );

    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );
  }

  function test_executeSpokeDynamicReserveConfigAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.addDynamicReserveConfig.selector,
      true
    );

    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();

    vm.expectRevert(MockSpokeConfigurator.AddDynamicReserveConfigReverted.selector);
    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );
  }

  function test_executeSpokeAllReservesPauses_concrete() public {
    IAaveV4ConfigEngine.SpokePause memory pause = _defaultSpokePause();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseAllReservesCalled(SPOKE);

    engine.executeSpokesPauseAllReserves(_toSpokePauseArray(pause));
  }

  function testFuzz_executeSpokeAllReservesPauses(address spoke) public {
    IAaveV4ConfigEngine.SpokePause memory pause = IAaveV4ConfigEngine.SpokePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: spoke
    });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseAllReservesCalled(spoke);

    engine.executeSpokesPauseAllReserves(_toSpokePauseArray(pause));
  }

  function test_executeSpokeAllReservesPauses_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.pauseAllReserves.selector, true);

    IAaveV4ConfigEngine.SpokePause memory pause = _defaultSpokePause();

    vm.expectRevert(MockSpokeConfigurator.PauseAllReservesReverted.selector);
    engine.executeSpokesPauseAllReserves(_toSpokePauseArray(pause));
  }

  function test_executeSpokeAllReservesFreezes_concrete() public {
    IAaveV4ConfigEngine.SpokeFreeze memory freeze = _defaultSpokeFreeze();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeAllReservesCalled(SPOKE);

    engine.executeSpokesFreezeAllReserves(_toSpokeFreezeArray(freeze));
  }

  function testFuzz_executeSpokeAllReservesFreezes(address spoke) public {
    IAaveV4ConfigEngine.SpokeFreeze memory freeze = IAaveV4ConfigEngine.SpokeFreeze({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: spoke
    });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeAllReservesCalled(spoke);

    engine.executeSpokesFreezeAllReserves(_toSpokeFreezeArray(freeze));
  }

  function test_executeSpokeAllReservesFreezes_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.freezeAllReserves.selector, true);

    IAaveV4ConfigEngine.SpokeFreeze memory freeze = _defaultSpokeFreeze();

    vm.expectRevert(MockSpokeConfigurator.FreezeAllReservesReverted.selector);
    engine.executeSpokesFreezeAllReserves(_toSpokeFreezeArray(freeze));
  }

  function test_executeSpokePositionManagerUpdates_concrete() public {
    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePositionManagerCalled(SPOKE, POSITION_MANAGER, true);

    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));
  }

  function testFuzz_executeSpokePositionManagerUpdates(
    address positionManager,
    bool active
  ) public {
    IAaveV4ConfigEngine.PositionManagerUpdate memory update = IAaveV4ConfigEngine
      .PositionManagerUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        positionManager: positionManager,
        active: active
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePositionManagerCalled(SPOKE, positionManager, active);

    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));
  }

  function test_executeSpokePositionManagerUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updatePositionManager.selector, true);

    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdatePositionManagerReverted.selector);
    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));
  }
}
