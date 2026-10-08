// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/configurator/SpokeConfigurator.t.sol';

contract SpokeConfiguratorFreezeTest is SpokeConfiguratorBaseTest {
  using SafeCast for uint256;
  using WadRayMath for uint256;

  function test_freezeReserve_activeCollateralReserve() public {
    test_fuzz_freezeReserve_activeCollateralReserve(70_00, 110_00, 5_00);
  }

  function test_fuzz_freezeReserve_activeCollateralReserve(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) public {
    ISpoke.DynamicReserveConfig memory config = _boundConfig(
      collateralFactor,
      maxLiquidationBonus,
      liquidationFee
    );
    uint32 prevKey = _addDynamicConfig(reserveId, config);
    ISpoke.DynamicReserveConfig memory zeroed = _withCollateralFactor(config, 0);

    vm.recordLogs();
    _expectReserveFrozenUpdated(spoke, reserveId, false, true);
    _expectDynamicConfigUpdated(spoke, reserveId, prevKey, prevKey + 1, config, zeroed);
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, 0, prevKey);
    _freezeReserve(reserveId);

    assertEq(_configuratorLogCount(), 5);
    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_latestKey(spoke, reserveId), prevKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), zeroed);
    assertEq(spoke.getDynamicReserveConfig(reserveId, prevKey), config);
    assertEq(_savedKey(spoke, reserveId), prevKey);
  }

  function test_freezeReserve_frozenWithNonZeroCollateralFactor_zeroesCollateralFactorOnly()
    public
  {
    _freezeReserve(reserveId);
    uint32 liftedKey = _addCollateralFactor(reserveId, 60_00);
    ISpoke.DynamicReserveConfig memory lifted = _getLatestDynamicReserveConfig(spoke, reserveId);
    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_savedKey(spoke, reserveId), 0);

    vm.recordLogs();
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      liftedKey,
      liftedKey + 1,
      lifted,
      _withCollateralFactor(lifted, 0)
    );
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, 0, liftedKey);
    _freezeReserve(reserveId);

    assertEq(_configuratorLogCount(), 4);
    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_latestKey(spoke, reserveId), liftedKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), _withCollateralFactor(lifted, 0));
    assertEq(_savedKey(spoke, reserveId), liftedKey);
  }

  function test_freezeReserve_unfrozenWithZeroCollateralFactor_setsFlagOnly() public {
    uint32 prevKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    uint32 latestKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory latest = _getLatestDynamicReserveConfig(spoke, reserveId);
    assertEq(latest.collateralFactor, 0);
    assertEq(_savedKey(spoke, reserveId), prevKey);

    vm.recordLogs();
    _expectReserveFrozenUpdated(spoke, reserveId, false, true);
    _freezeReserve(reserveId);

    assertEq(_configuratorLogCount(), 1);
    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_latestKey(spoke, reserveId), latestKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), latest);
    assertEq(_savedKey(spoke, reserveId), prevKey);
  }

  function test_freezeReserve_revertsWith_ReserveAlreadyFrozen() public {
    _freezeReserve(reserveId);

    vm.expectRevert(ISpokeConfigurator.ReserveAlreadyFrozen.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, underlying);
  }

  function test_unfreezeReserve_clearsFlagOnly() public {
    uint32 prevKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _freezeReserve(reserveId);
    uint32 latestKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory latest = _getLatestDynamicReserveConfig(spoke, reserveId);

    vm.recordLogs();
    _expectReserveFrozenUpdated(spoke, reserveId, true, false);
    _unfreezeReserve(reserveId);

    assertEq(_configuratorLogCount(), 1);
    assertFalse(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_latestKey(spoke, reserveId), latestKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), latest);
    assertEq(latest.collateralFactor, 0);
    assertEq(_savedKey(spoke, reserveId), prevKey);
  }

  function test_unfreezeReserve_revertsWith_ReserveNotFrozen() public {
    vm.expectRevert(ISpokeConfigurator.ReserveNotFrozen.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.unfreezeReserve(spokeAddr, hubAddr, underlying);
  }

  function test_freezeSpoke_mixedReserveStates() public {
    uint256 wethId = _wethReserveId(spoke);
    uint256 wbtcId = _wbtcReserveId(spoke);
    uint256 daiId = _daiReserveId(spoke);
    uint256 usdxId = _usdxReserveId(spoke);
    uint256 usdyId = _usdyReserveId(spoke);

    // wbtc: frozen with a non-zero collateral factor
    _freezeReserve(wbtcId);
    uint32 wbtcLiftedKey = _addCollateralFactor(wbtcId, 60_00);
    // dai: not frozen with a zero collateral factor
    _zeroCollateralFactor(daiId);
    // usdx: frozen with a zero collateral factor
    _freezeReserve(usdxId);
    // weth, usdy: active collateral reserves

    uint256 reserveCount = spoke.getReserveCount();
    ISpoke.DynamicReserveConfig[] memory before = new ISpoke.DynamicReserveConfig[](reserveCount);
    uint32[] memory beforeKeys = new uint32[](reserveCount);
    uint32[] memory beforeSaved = new uint32[](reserveCount);
    for (uint256 id; id < reserveCount; ++id) {
      before[id] = _getLatestDynamicReserveConfig(spoke, id);
      beforeKeys[id] = _latestKey(spoke, id);
      beforeSaved[id] = _savedKey(spoke, id);
    }

    vm.recordLogs();
    uint256 expectedLogs;
    for (uint256 id; id < reserveCount; ++id) {
      if (id == wethId || id == usdyId) {
        _expectReserveFrozenUpdated(spoke, id, false, true);
        _expectDynamicConfigUpdated(
          spoke,
          id,
          beforeKeys[id],
          beforeKeys[id] + 1,
          before[id],
          _withCollateralFactor(before[id], 0)
        );
        _expectSavedDynamicConfigKeyUpdated(spoke, id, beforeSaved[id], beforeKeys[id]);
        expectedLogs += 5;
      } else if (id == wbtcId) {
        _expectDynamicConfigUpdated(
          spoke,
          id,
          wbtcLiftedKey,
          wbtcLiftedKey + 1,
          before[id],
          _withCollateralFactor(before[id], 0)
        );
        _expectSavedDynamicConfigKeyUpdated(spoke, id, beforeSaved[id], wbtcLiftedKey);
        expectedLogs += 4;
      } else if (id == daiId) {
        _expectReserveFrozenUpdated(spoke, id, false, true);
        expectedLogs += 1;
      }
    }
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeSpoke(spokeAddr);

    assertEq(expectedLogs, 15);
    assertEq(_configuratorLogCount(), expectedLogs);

    for (uint256 id; id < reserveCount; ++id) {
      assertTrue(spoke.getReserveConfig(id).frozen);
      assertEq(_getLatestDynamicReserveConfig(spoke, id).collateralFactor, 0);
    }
    // weth, usdy: frozen and zeroed, saved key is the pre-freeze key
    assertEq(_latestKey(spoke, wethId), beforeKeys[wethId] + 1);
    assertEq(_savedKey(spoke, wethId), beforeKeys[wethId]);
    assertEq(_latestKey(spoke, usdyId), beforeKeys[usdyId] + 1);
    assertEq(_savedKey(spoke, usdyId), beforeKeys[usdyId]);
    // wbtc: zeroed only, saved key is the lifted key
    assertEq(_latestKey(spoke, wbtcId), wbtcLiftedKey + 1);
    assertEq(_savedKey(spoke, wbtcId), wbtcLiftedKey);
    assertEq(
      _getLatestDynamicReserveConfig(spoke, wbtcId),
      _withCollateralFactor(before[wbtcId], 0)
    );
    // dai: flag only
    assertEq(_latestKey(spoke, daiId), beforeKeys[daiId]);
    assertEq(_savedKey(spoke, daiId), beforeSaved[daiId]);
    // usdx: untouched
    assertEq(_latestKey(spoke, usdxId), beforeKeys[usdxId]);
    assertEq(_savedKey(spoke, usdxId), beforeSaved[usdxId]);

    // a second call is a no-op on every reserve and does not revert
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeSpoke(spokeAddr);
    assertEq(_configuratorLogCount(), 0);
  }

  function test_unfreezeSpoke_mixedReserveStates() public {
    uint256 wethId = _wethReserveId(spoke);
    uint256 wbtcId = _wbtcReserveId(spoke);
    uint256 daiId = _daiReserveId(spoke);

    // weth: frozen with a zero collateral factor
    _freezeReserve(wethId);
    // dai: frozen with a non-zero collateral factor
    _freezeReserve(daiId);
    _addCollateralFactor(daiId, 60_00);
    // wbtc: not frozen with a zero collateral factor
    _zeroCollateralFactor(wbtcId);
    // usdx, usdy: active collateral reserves

    uint256 reserveCount = spoke.getReserveCount();
    ISpoke.DynamicReserveConfig[] memory before = new ISpoke.DynamicReserveConfig[](reserveCount);
    uint32[] memory beforeKeys = new uint32[](reserveCount);
    uint32[] memory beforeSaved = new uint32[](reserveCount);
    for (uint256 id; id < reserveCount; ++id) {
      before[id] = _getLatestDynamicReserveConfig(spoke, id);
      beforeKeys[id] = _latestKey(spoke, id);
      beforeSaved[id] = _savedKey(spoke, id);
    }

    vm.recordLogs();
    for (uint256 id; id < reserveCount; ++id) {
      if (id == wethId || id == daiId) {
        _expectReserveFrozenUpdated(spoke, id, true, false);
      }
    }
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.unfreezeSpoke(spokeAddr);

    assertEq(_configuratorLogCount(), 2);
    for (uint256 id; id < reserveCount; ++id) {
      assertFalse(spoke.getReserveConfig(id).frozen);
      assertEq(_latestKey(spoke, id), beforeKeys[id]);
      assertEq(_getLatestDynamicReserveConfig(spoke, id), before[id]);
      assertEq(_savedKey(spoke, id), beforeSaved[id]);
    }
    assertEq(before[wethId].collateralFactor, 0);
    assertEq(before[daiId].collateralFactor, 60_00);
    assertEq(before[wbtcId].collateralFactor, 0);

    // a second call is a no-op on every reserve and does not revert
    vm.recordLogs();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.unfreezeSpoke(spokeAddr);
    assertEq(_configuratorLogCount(), 0);
  }

  function test_zeroCollateralFactor_unfrozen() public {
    test_fuzz_zeroCollateralFactor_unfrozen(70_00, 110_00, 5_00);
  }

  function test_fuzz_zeroCollateralFactor_unfrozen(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) public {
    ISpoke.DynamicReserveConfig memory config = _boundConfig(
      collateralFactor,
      maxLiquidationBonus,
      liquidationFee
    );
    uint32 prevKey = _addDynamicConfig(reserveId, config);

    vm.recordLogs();
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      prevKey,
      prevKey + 1,
      config,
      _withCollateralFactor(config, 0)
    );
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, 0, prevKey);
    _zeroCollateralFactor(reserveId);

    assertEq(_configuratorLogCount(), 4);
    assertFalse(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_latestKey(spoke, reserveId), prevKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), _withCollateralFactor(config, 0));
    assertEq(_savedKey(spoke, reserveId), prevKey);
  }

  function test_zeroCollateralFactor_overwritesSavedKey() public {
    uint32 firstSavedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    assertEq(_savedKey(spoke, reserveId), firstSavedKey);

    uint32 liftedKey = _addCollateralFactor(reserveId, 50_00);
    ISpoke.DynamicReserveConfig memory lifted = _getLatestDynamicReserveConfig(spoke, reserveId);
    assertEq(_savedKey(spoke, reserveId), firstSavedKey);

    vm.recordLogs();
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      liftedKey,
      liftedKey + 1,
      lifted,
      _withCollateralFactor(lifted, 0)
    );
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, firstSavedKey, liftedKey);
    _zeroCollateralFactor(reserveId);

    assertEq(_configuratorLogCount(), 4);
    assertEq(_savedKey(spoke, reserveId), liftedKey);
  }

  function test_zeroCollateralFactor_revertsWith_CollateralFactorAlreadyZero() public {
    _zeroCollateralFactor(reserveId);

    vm.expectRevert(ISpokeConfigurator.CollateralFactorAlreadyZero.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.zeroCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_addCollateralFactor_zero_savesPreviousKey() public {
    uint32 prevKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    ISpoke.DynamicReserveConfig memory prev = _getLatestDynamicReserveConfig(spoke, reserveId);

    vm.recordLogs();
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      prevKey,
      prevKey + 1,
      prev,
      _withCollateralFactor(prev, 0)
    );
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, 0, prevKey);
    uint32 newKey = _addCollateralFactor(reserveId, 0);

    assertEq(_configuratorLogCount(), 4);
    assertEq(newKey, prevKey + 1);
    assertEq(_savedKey(spoke, reserveId), prevKey);
    assertFalse(spoke.getReserveConfig(reserveId).frozen);
  }

  function test_addDynamicReserveConfig_zeroCollateralFactor_savesPreviousKey() public {
    test_fuzz_addDynamicReserveConfig_zeroCollateralFactor_savesPreviousKey(115_00, 7_00);
  }

  function test_fuzz_addDynamicReserveConfig_zeroCollateralFactor_savesPreviousKey(
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) public {
    uint32 prevKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    ISpoke.DynamicReserveConfig memory prev = _getLatestDynamicReserveConfig(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory zeroConfig = _config(
      0,
      bound(maxLiquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS).toUint32(),
      bound(liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR).toUint16()
    );

    vm.recordLogs();
    _expectDynamicConfigUpdated(spoke, reserveId, prevKey, prevKey + 1, prev, zeroConfig);
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, 0, prevKey);
    uint32 newKey = _addDynamicConfig(reserveId, zeroConfig);

    assertEq(_configuratorLogCount(), 4);
    assertEq(newKey, prevKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), zeroConfig);
    assertEq(_savedKey(spoke, reserveId), prevKey);
  }

  function test_addMaxLiquidationBonus_onZeroCollateralFactor_keepsSavedKey() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory zeroConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    ISpoke.DynamicReserveConfig memory newConfig = _config(0, 120_00, zeroConfig.liquidationFee);

    vm.recordLogs();
    _expectDynamicConfigUpdated(spoke, reserveId, zeroKey, zeroKey + 1, zeroConfig, newConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint32 newKey = spokeConfigurator.addMaxLiquidationBonus(
      spokeAddr,
      hubAddr,
      underlying,
      120_00
    );

    assertEq(_configuratorLogCount(), 3);
    assertEq(newKey, zeroKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), newConfig);
    assertEq(_savedKey(spoke, reserveId), savedKey);
  }

  function test_addLiquidationFee_onZeroCollateralFactor_keepsSavedKey() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory zeroConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    ISpoke.DynamicReserveConfig memory newConfig = _config(0, zeroConfig.maxLiquidationBonus, 9_00);

    vm.recordLogs();
    _expectDynamicConfigUpdated(spoke, reserveId, zeroKey, zeroKey + 1, zeroConfig, newConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint32 newKey = spokeConfigurator.addLiquidationFee(spokeAddr, hubAddr, underlying, 9_00);

    assertEq(_configuratorLogCount(), 3);
    assertEq(newKey, zeroKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), newConfig);
    assertEq(_savedKey(spoke, reserveId), savedKey);
  }

  function test_addCollateralFactor_nonZeroWhileFrozen_keepsSavedKey() public {
    test_fuzz_addCollateralFactor_nonZeroWhileFrozen_keepsSavedKey(50_00);
  }

  function test_fuzz_addCollateralFactor_nonZeroWhileFrozen_keepsSavedKey(
    uint16 collateralFactor
  ) public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _freezeReserve(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory zeroConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    collateralFactor = bound(
      collateralFactor,
      1,
      _collateralFactorUpperBound(zeroConfig.maxLiquidationBonus)
    ).toUint16();
    ISpoke.DynamicReserveConfig memory lifted = _withCollateralFactor(zeroConfig, collateralFactor);

    vm.recordLogs();
    _expectDynamicConfigUpdated(spoke, reserveId, zeroKey, zeroKey + 1, zeroConfig, lifted);
    uint32 newKey = _addCollateralFactor(reserveId, collateralFactor);

    assertEq(_configuratorLogCount(), 3);
    assertEq(newKey, zeroKey + 1);
    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), lifted);
    assertEq(_savedKey(spoke, reserveId), savedKey);
  }

  function test_restoreCollateralFactor_readdsFullSavedConfig() public {
    test_fuzz_restoreCollateralFactor_readdsFullSavedConfig(70_00, 110_00, 5_00, 120_00, 7_00);
  }

  function test_fuzz_restoreCollateralFactor_readdsFullSavedConfig(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee,
    uint32 laterMaxLiquidationBonus,
    uint16 laterLiquidationFee
  ) public {
    ISpoke.DynamicReserveConfig memory savedConfig = _boundConfig(
      collateralFactor,
      maxLiquidationBonus,
      liquidationFee
    );
    laterMaxLiquidationBonus = bound(
      laterMaxLiquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    ).toUint32();
    laterLiquidationFee = bound(laterLiquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();
    // the later key must differ from the saved key for the restore to prove which one is re-added
    if (laterMaxLiquidationBonus == savedConfig.maxLiquidationBonus) {
      laterMaxLiquidationBonus = laterMaxLiquidationBonus == MAX_LIQUIDATION_BONUS
        ? laterMaxLiquidationBonus - 1
        : laterMaxLiquidationBonus + 1;
    }

    uint32 savedKey = _addDynamicConfig(reserveId, savedConfig);
    _freezeReserve(reserveId);
    _addMaxLiquidationBonus(reserveId, laterMaxLiquidationBonus);
    _addLiquidationFee(reserveId, laterLiquidationFee);
    _unfreezeReserve(reserveId);

    uint32 latestKey = _latestKey(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory latest = _getLatestDynamicReserveConfig(spoke, reserveId);
    assertEq(latest, _config(0, laterMaxLiquidationBonus, laterLiquidationFee));
    assertEq(_savedKey(spoke, reserveId), savedKey);

    vm.recordLogs();
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, savedConfig))
    );
    _expectDynamicConfigUpdated(spoke, reserveId, latestKey, latestKey + 1, latest, savedConfig);
    uint32 restoredKey = _restoreCollateralFactor(reserveId);

    assertEq(_configuratorLogCount(), 3);
    assertEq(restoredKey, latestKey + 1);
    assertEq(_latestKey(spoke, reserveId), restoredKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
    assertEq(
      _getLatestDynamicReserveConfig(spoke, reserveId).maxLiquidationBonus,
      savedConfig.maxLiquidationBonus
    );
    assertEq(_savedKey(spoke, reserveId), savedKey);
  }

  function test_restoreCollateralFactor_afterZeroCollateralFactor() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    ISpoke.DynamicReserveConfig memory savedConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );
    _zeroCollateralFactor(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    vm.recordLogs();
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      zeroKey,
      zeroKey + 1,
      _withCollateralFactor(savedConfig, 0),
      savedConfig
    );
    uint32 restoredKey = _restoreCollateralFactor(reserveId);

    assertEq(_configuratorLogCount(), 3);
    assertEq(restoredKey, zeroKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
    assertEq(_savedKey(spoke, reserveId), savedKey);
  }

  function test_restoreCollateralFactor_revertsWith_CannotRestoreFrozenReserve() public {
    _freezeReserve(reserveId);

    vm.expectRevert(
      ISpokeConfigurator.CannotRestoreFrozenReserve.selector,
      address(spokeConfigurator)
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_restoreCollateralFactor_revertsWith_CollateralFactorNotZero() public {
    vm.expectRevert(ISpokeConfigurator.CollateralFactorNotZero.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_restoreCollateralFactor_revertsWith_CollateralFactorNotZero_afterRestore() public {
    _freezeReserve(reserveId);
    _unfreezeReserve(reserveId);
    _restoreCollateralFactor(reserveId);

    vm.expectRevert(ISpokeConfigurator.CollateralFactorNotZero.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_restoreCollateralFactor_revertsWith_InvalidSavedCollateralFactor() public {
    // usdz listed with a zero collateral factor at key 0 and never saved
    address usdz = address(tokenList.usdz);
    address priceSource = _deployMockPriceFeed(spoke, 1e8);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint256 usdzId = spokeConfigurator.addReserve(
      spokeAddr,
      hubAddr,
      usdz,
      priceSource,
      _getDefaultReserveConfig(10_00),
      _config(0, 100_00, 0)
    );
    assertEq(_latestKey(spoke, usdzId), 0);
    assertEq(_savedKey(spoke, usdzId), 0);

    vm.expectRevert(ISpokeConfigurator.InvalidSavedCollateralFactor.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, usdz);
  }

  function test_restoreCollateralFactor_frozenAtKeyZero() public {
    assertEq(_latestKey(spoke, reserveId), 0);
    ISpoke.DynamicReserveConfig memory listingConfig = spoke.getDynamicReserveConfig(reserveId, 0);
    assertGt(listingConfig.collateralFactor, 0);

    vm.recordLogs();
    _expectReserveFrozenUpdated(spoke, reserveId, false, true);
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      0,
      1,
      listingConfig,
      _withCollateralFactor(listingConfig, 0)
    );
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, 0, 0);
    _freezeReserve(reserveId);
    assertEq(_configuratorLogCount(), 5);
    assertEq(_savedKey(spoke, reserveId), 0);

    _unfreezeReserve(reserveId);

    vm.recordLogs();
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      1,
      2,
      _withCollateralFactor(listingConfig, 0),
      listingConfig
    );
    uint32 restoredKey = _restoreCollateralFactor(reserveId);

    assertEq(_configuratorLogCount(), 3);
    assertEq(restoredKey, 2);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), listingConfig);
  }

  function test_restoreCollateralFactor_usesUpdatedSavedConfig() public {
    test_fuzz_restoreCollateralFactor_usesUpdatedSavedConfig(40_00);
  }

  function test_fuzz_restoreCollateralFactor_usesUpdatedSavedConfig(
    uint16 updatedCollateralFactor
  ) public {
    ISpoke.DynamicReserveConfig memory savedConfig = _config(70_00, 110_00, 5_00);
    uint32 savedKey = _addDynamicConfig(reserveId, savedConfig);
    _zeroCollateralFactor(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    updatedCollateralFactor = bound(
      updatedCollateralFactor,
      1,
      _collateralFactorUpperBound(savedConfig.maxLiquidationBonus)
    ).toUint16();
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralFactor(
      spokeAddr,
      hubAddr,
      underlying,
      savedKey,
      updatedCollateralFactor
    );
    ISpoke.DynamicReserveConfig memory expected = _withCollateralFactor(
      savedConfig,
      updatedCollateralFactor
    );
    assertEq(spoke.getDynamicReserveConfig(reserveId, savedKey), expected);

    vm.recordLogs();
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      zeroKey,
      zeroKey + 1,
      _withCollateralFactor(savedConfig, 0),
      expected
    );
    uint32 restoredKey = _restoreCollateralFactor(reserveId);

    assertEq(_configuratorLogCount(), 3);
    assertEq(restoredKey, zeroKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), expected);
  }

  function test_freezeReserve_existingPosition_keepsCollateralFactorUntilRefresh() public {
    (uint256 wethId, uint256 usdxId) = _openCollateralizedBorrow(alice);
    uint32 userKeyBefore = spoke.getUserPosition(wethId, alice).dynamicConfigKey;
    ISpoke.UserAccountData memory dataBefore = spoke.getUserAccountData(alice);
    assertEq(dataBefore.activeCollateralCount, 2);
    assertEq(
      dataBefore.totalCollateralValue,
      _collateralValue(wethId, alice) + _collateralValue(usdxId, alice)
    );

    _freezeReserve(wethId);
    uint32 frozenKey = _latestKey(spoke, wethId);
    assertEq(frozenKey, userKeyBefore + 1);

    // existing position keeps its dynamic config key and collateral factor
    uint16 collateralFactorBefore = spoke
      .getDynamicReserveConfig(wethId, userKeyBefore)
      .collateralFactor;
    assertGt(collateralFactorBefore, 0);
    assertEq(spoke.getUserPosition(wethId, alice).dynamicConfigKey, userKeyBefore);
    assertEq(_getCollateralFactor(spoke, wethId, alice), collateralFactorBefore);
    assertEq(spoke.getUserAccountData(alice), dataBefore);

    // refresh applies the zero collateral factor
    vm.expectEmit(spokeAddr);
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);

    assertEq(spoke.getUserPosition(wethId, alice).dynamicConfigKey, frozenKey);
    assertEq(_getCollateralFactor(spoke, wethId, alice), 0);
    _assertOnlyUsdxCollateral(alice, usdxId, dataBefore.totalDebtValueRay);
  }

  function test_freezeReserve_existingPosition_borrowRefreshesCollateralFactor() public {
    (uint256 wethId, uint256 usdxId) = _openCollateralizedBorrow(alice);
    uint256 daiId = _daiReserveId(spoke);

    _freezeReserve(wethId);
    uint32 frozenKey = _latestKey(spoke, wethId);

    SpokeActions.borrow({
      spoke: spoke,
      reserveId: daiId,
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });

    assertEq(spoke.getUserPosition(wethId, alice).dynamicConfigKey, frozenKey);
    assertEq(_getCollateralFactor(spoke, wethId, alice), 0);
    ISpoke.UserAccountData memory data = spoke.getUserAccountData(alice);
    _assertOnlyUsdxCollateral(alice, usdxId, data.totalDebtValueRay);
  }

  function test_freezeReserve_existingPosition_refreshRevertsWhenUndercollateralized() public {
    uint256 wethId = _wethReserveId(spoke);
    uint256 daiId = _daiReserveId(spoke);
    _openSupplyPosition(spoke, daiId, 100_000e18);
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: wethId,
      caller: bob,
      amount: 10e18,
      onBehalfOf: bob
    });
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: daiId,
      caller: bob,
      amount: 5_000e18,
      onBehalfOf: bob
    });
    uint256 healthFactorBefore = _getUserHealthFactor(spoke, bob);

    _freezeReserve(wethId);
    assertEq(_getUserHealthFactor(spoke, bob), healthFactorBefore);

    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    vm.prank(bob);
    spoke.updateUserDynamicConfig(bob);
  }

  function test_restoreCollateralFactor_staleSavedKeyAfterDirectSpokeZero() public {
    ISpoke.DynamicReserveConfig memory savedConfig = _config(70_00, 110_00, 5_00);
    uint32 savedKey = _addDynamicConfig(reserveId, savedConfig);
    _zeroCollateralFactor(reserveId);
    _addCollateralFactor(reserveId, 40_00);
    ISpoke.DynamicReserveConfig memory latest = _getLatestDynamicReserveConfig(spoke, reserveId);

    // a SPOKE_CONFIGURATOR_ROLE holder zeroes the collateral factor directly on the Spoke
    vm.prank(SPOKE_ADMIN);
    spoke.addDynamicReserveConfig(reserveId, _withCollateralFactor(latest, 0));
    assertEq(_savedKey(spoke, reserveId), savedKey);

    _restoreCollateralFactor(reserveId);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
  }

  function test_updateCollateralFactor_onZeroedKeyWhileFrozen_liftsCollateralFactor() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _freezeReserve(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);
    (address hub, address asset) = _reserveAddresses(reserveId);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralFactor(spokeAddr, hub, asset, zeroKey, 30_00);

    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor, 30_00);
    assertEq(_savedKey(spoke, reserveId), savedKey);

    _unfreezeReserve(reserveId);
    vm.expectRevert(ISpokeConfigurator.CollateralFactorNotZero.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hub, asset);
  }

  function test_updateMaxLiquidationBonus_onZeroedKey_revertsWith_InvalidCollateralFactor() public {
    _freezeReserve(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);
    (address hub, address asset) = _reserveAddresses(reserveId);

    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateMaxLiquidationBonus(spokeAddr, hub, asset, zeroKey, 105_00);
  }

  function test_upgrade_preservesSavedDynamicConfigKey() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _freezeReserve(reserveId);
    assertEq(_savedKey(spoke, reserveId), savedKey);

    address proxyAdmin = _getProxyAdminAddress(address(spokeConfigurator));
    address newImplementation = address(new SpokeConfiguratorInstance());
    vm.prank(Ownable(proxyAdmin).owner());
    ProxyAdmin(proxyAdmin).upgradeAndCall(
      ITransparentUpgradeableProxy(address(spokeConfigurator)),
      newImplementation,
      ''
    );

    assertEq(_getImplementationAddress(address(spokeConfigurator)), newImplementation);
    assertEq(_savedKey(spoke, reserveId), savedKey);
    assertEq(IAccessManaged(address(spokeConfigurator)).authority(), spoke.authority());

    _unfreezeReserve(reserveId);
    _restoreCollateralFactor(reserveId);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), _config(70_00, 110_00, 5_00));
  }

  function _openCollateralizedBorrow(address user) internal returns (uint256, uint256) {
    uint256 wethId = _wethReserveId(spoke);
    uint256 usdxId = _usdxReserveId(spoke);
    uint256 daiId = _daiReserveId(spoke);
    _openSupplyPosition(spoke, daiId, 100_000e18);
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: wethId,
      caller: user,
      amount: 10e18,
      onBehalfOf: user
    });
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: usdxId,
      caller: user,
      amount: 10_000e6,
      onBehalfOf: user
    });
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: daiId,
      caller: user,
      amount: 5_000e18,
      onBehalfOf: user
    });
    return (wethId, usdxId);
  }

  /// @dev Asserts the account data of `user` counts only the usdx collateral.
  function _assertOnlyUsdxCollateral(
    address user,
    uint256 usdxId,
    uint256 totalDebtValueRay
  ) internal view {
    ISpoke.UserAccountData memory data = spoke.getUserAccountData(user);
    uint256 usdxValue = _collateralValue(usdxId, user);
    uint256 usdxCollateralFactor = _getCollateralFactor(spoke, usdxId, user);
    assertEq(data.activeCollateralCount, 1);
    assertEq(data.totalCollateralValue, usdxValue);
    assertEq(data.avgCollateralFactor, usdxCollateralFactor.bpsToWad());
    assertEq(data.totalDebtValueRay, totalDebtValueRay);
    assertEq(
      data.healthFactor,
      Math.mulDiv(
        (usdxCollateralFactor * usdxValue).bpsToWad(),
        WadRayMath.RAY,
        totalDebtValueRay,
        Math.Rounding.Floor
      )
    );
    assertEq(data.riskPremium, spoke.getReserveConfig(usdxId).collateralRisk);
  }

  function _collateralValue(uint256 id, address user) internal view returns (uint256) {
    return
      SpokeUtils.toValue({
        amount: spoke.getUserSuppliedAssets(id, user),
        decimals: spoke.getReserve(id).decimals,
        price: IAaveOracle(spoke.ORACLE()).getReservePrice(id)
      });
  }

  function _boundConfig(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) internal pure returns (ISpoke.DynamicReserveConfig memory) {
    maxLiquidationBonus = bound(maxLiquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS)
      .toUint32();
    return
      _config(
        bound(collateralFactor, 1, _collateralFactorUpperBound(maxLiquidationBonus)).toUint16(),
        maxLiquidationBonus,
        bound(liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR).toUint16()
      );
  }

  function _config(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) internal pure returns (ISpoke.DynamicReserveConfig memory) {
    return
      ISpoke.DynamicReserveConfig({
        collateralFactor: collateralFactor,
        maxLiquidationBonus: maxLiquidationBonus,
        liquidationFee: liquidationFee
      });
  }

  function _withCollateralFactor(
    ISpoke.DynamicReserveConfig memory config,
    uint16 collateralFactor
  ) internal pure returns (ISpoke.DynamicReserveConfig memory) {
    return _config(collateralFactor, config.maxLiquidationBonus, config.liquidationFee);
  }

  function _reserveAddresses(uint256 id) internal view returns (address, address) {
    ISpoke.Reserve memory reserve = spoke.getReserve(id);
    return (address(reserve.hub), reserve.underlying);
  }

  function _freezeReserve(uint256 id) internal {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeReserve(spokeAddr, hub, asset);
  }

  function _unfreezeReserve(uint256 id) internal {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.unfreezeReserve(spokeAddr, hub, asset);
  }

  function _zeroCollateralFactor(uint256 id) internal {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.zeroCollateralFactor(spokeAddr, hub, asset);
  }

  function _restoreCollateralFactor(uint256 id) internal returns (uint32) {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    return spokeConfigurator.restoreCollateralFactor(spokeAddr, hub, asset);
  }

  function _addCollateralFactor(uint256 id, uint16 collateralFactor) internal returns (uint32) {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    return spokeConfigurator.addCollateralFactor(spokeAddr, hub, asset, collateralFactor);
  }

  function _addMaxLiquidationBonus(uint256 id, uint32 maxLiquidationBonus) internal {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.addMaxLiquidationBonus(spokeAddr, hub, asset, maxLiquidationBonus);
  }

  function _addLiquidationFee(uint256 id, uint16 liquidationFee) internal {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.addLiquidationFee(spokeAddr, hub, asset, liquidationFee);
  }

  function _addDynamicConfig(
    uint256 id,
    ISpoke.DynamicReserveConfig memory config
  ) internal returns (uint32) {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    return spokeConfigurator.addDynamicReserveConfig(spokeAddr, hub, asset, config);
  }
}
