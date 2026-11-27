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
    _assertSavedCollateralFactor(spoke, reserveId, prevKey, false, false, true);
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
    _assertSavedCollateralFactor(spoke, reserveId, prevKey, false, false, true);
  }

  function test_zeroCollateralFactor_overwritesSavedKey() public {
    uint32 firstSavedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    assertEq(_savedKey(spoke, reserveId), firstSavedKey);

    uint32 liftedKey = _addCollateralFactor(reserveId, 50_00);
    ISpoke.DynamicReserveConfig memory lifted = _getLatestDynamicReserveConfig(spoke, reserveId);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);

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
    _zeroCollateralFactor(reserveId);

    assertEq(_configuratorLogCount(), 4);
    _assertSavedCollateralFactor(spoke, reserveId, liftedKey, false, false, true);
  }

  function test_zeroCollateralFactor_revertsWith_CollateralFactorAlreadyZero() public {
    _zeroCollateralFactor(reserveId);

    vm.expectRevert(ISpokeConfigurator.CollateralFactorAlreadyZero.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.zeroCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_addCollateralFactor_zero_clearsSavedCollateralFactor() public {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    uint32 prevKey = _addCollateralFactor(reserveId, 50_00);
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
    uint32 newKey = _addCollateralFactor(reserveId, 0);

    assertEq(_configuratorLogCount(), 3);
    assertEq(newKey, prevKey + 1);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
    assertFalse(spoke.getReserveConfig(reserveId).frozen);

    vm.expectRevert(ISpokeConfigurator.InvalidSavedCollateralFactor.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_addCollateralFactor_zero_afterZeroCollateralFactor_clearsSavedCollateralFactor()
    public
  {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    _addCollateralFactor(reserveId, 0);

    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
    vm.expectRevert(ISpokeConfigurator.InvalidSavedCollateralFactor.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_addDynamicReserveConfig_zeroCollateralFactor_clearsSavedCollateralFactor() public {
    test_fuzz_addDynamicReserveConfig_zeroCollateralFactor_clearsSavedCollateralFactor(
      115_00,
      7_00
    );
  }

  function test_fuzz_addDynamicReserveConfig_zeroCollateralFactor_clearsSavedCollateralFactor(
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) public {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    uint32 prevKey = _addCollateralFactor(reserveId, 50_00);
    ISpoke.DynamicReserveConfig memory prev = _getLatestDynamicReserveConfig(spoke, reserveId);
    ISpoke.DynamicReserveConfig memory zeroConfig = _config(
      0,
      bound(maxLiquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS).toUint32(),
      bound(liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR).toUint16()
    );

    vm.recordLogs();
    _expectDynamicConfigUpdated(spoke, reserveId, prevKey, prevKey + 1, prev, zeroConfig);
    uint32 newKey = _addDynamicConfig(reserveId, zeroConfig);

    assertEq(_configuratorLogCount(), 3);
    assertEq(newKey, prevKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), zeroConfig);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
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

  function test_addCollateralFactor_nonZeroWhileFrozen_clearsSavedCollateralFactor() public {
    test_fuzz_addCollateralFactor_nonZeroWhileFrozen_clearsSavedCollateralFactor(50_00);
  }

  function test_fuzz_addCollateralFactor_nonZeroWhileFrozen_clearsSavedCollateralFactor(
    uint16 collateralFactor
  ) public {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
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
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
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
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
  }

  function test_restoreCollateralFactor_afterZeroCollateralFactor() public {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
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
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
  }

  function test_restoreCollateralFactor_revertsWith_CannotRestoreFrozenReserve() public {
    _freezeReserve(reserveId);

    vm.expectRevert(ISpokeConfigurator.CannotRestoreFrozenReserve.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_restoreCollateralFactor_revertsWith_CannotRestorePausedReserve() public {
    _zeroCollateralFactor(reserveId);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.pauseReserve(spokeAddr, hubAddr, underlying);

    vm.expectRevert(ISpokeConfigurator.CannotRestorePausedReserve.selector);
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

  function test_restoreCollateralFactor_revertsWith_InvalidSavedCollateralFactor_afterDirectSpokeZero()
    public
  {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    _addCollateralFactor(reserveId, 40_00);
    ISpoke.DynamicReserveConfig memory latest = _getLatestDynamicReserveConfig(spoke, reserveId);

    // a SPOKE_CONFIGURATOR_ROLE holder zeroes the collateral factor directly on the Spoke
    vm.prank(SPOKE_ADMIN);
    spoke.addDynamicReserveConfig(reserveId, _withCollateralFactor(latest, 0));
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);

    vm.expectRevert(ISpokeConfigurator.InvalidSavedCollateralFactor.selector);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.restoreCollateralFactor(spokeAddr, hubAddr, underlying);
  }

  function test_updateCollateralFactor_onZeroedKeyWhileFrozen_liftsCollateralFactor() public {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _freezeReserve(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);
    (address hub, address asset) = _reserveAddresses(reserveId);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralFactor(spokeAddr, hub, asset, zeroKey, 30_00);

    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor, 30_00);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);

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

  function test_updateDynamicReserveConfig_onLatestKey_clearsSavedCollateralFactor() public {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateDynamicReserveConfig(
      spokeAddr,
      hubAddr,
      underlying,
      zeroKey,
      _config(40_00, 110_00, 5_00)
    );

    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
  }

  function test_updateDynamicReserveConfig_onSavedKey_keepsSavedCollateralFactor() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateDynamicReserveConfig(
      spokeAddr,
      hubAddr,
      underlying,
      savedKey,
      _config(40_00, 110_00, 5_00)
    );

    _assertSavedCollateralFactor(spoke, reserveId, savedKey, false, false, true);
    _restoreCollateralFactor(reserveId);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), _config(40_00, 110_00, 5_00));
  }

  function test_updateFrozen_holdsCollateralFactorHeldByBulkLever() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateFrozen(spokeAddr, hubAddr, underlying, true);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, true, false, true);

    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, false, false, true);
  }

  function test_updateFrozen_doesNotHoldUnheldCollateralFactor() public {
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateFrozen(spokeAddr, hubAddr, underlying, true);

    assertGt(_getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor, 0);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
  }

  function test_updateFrozen_unfreeze_keepsCollateralFactorHold() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _freezeReserve(reserveId);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateFrozen(spokeAddr, hubAddr, underlying, false);

    _assertSavedCollateralFactor(spoke, reserveId, savedKey, false, false, true);
  }

  function test_holdZeroCollateralFactor() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    ISpoke.DynamicReserveConfig memory savedConfig = _getLatestDynamicReserveConfig(
      spoke,
      reserveId
    );

    vm.recordLogs();
    _expectDynamicConfigUpdated(
      spoke,
      reserveId,
      savedKey,
      savedKey + 1,
      savedConfig,
      _withCollateralFactor(savedConfig, 0)
    );
    _expectSavedDynamicConfigKeyUpdated(spoke, reserveId, 0, savedKey);
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);

    assertEq(_configuratorLogCount(), 4);
    assertEq(_latestKey(spoke, reserveId), savedKey + 1);
    assertFalse(spoke.getReserveConfig(reserveId).frozen);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, true, false, false);
  }

  function test_holdZeroCollateralFactor_alreadyZero_doesNotRecord() public {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    uint32 zeroKey = _addCollateralFactor(reserveId, 0);

    vm.recordLogs();
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);

    assertEq(_configuratorLogCount(), 0);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
  }

  function test_holdZeroCollateralFactor_alreadyHeld_joinsHold() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.SPOKE_MASK);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    vm.recordLogs();
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);

    assertEq(_configuratorLogCount(), 0);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, true, true, false);
  }

  function test_holdFrozen_holdsCollateralFactor() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _holdFrozen(reserveId, BulkLeversMap.ASSET_MASK);

    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor, 0);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, true, false, false);
  }

  function test_releaseZeroCollateralFactor() public {
    ISpoke.DynamicReserveConfig memory savedConfig = _config(70_00, 110_00, 5_00);
    _addDynamicConfig(reserveId, savedConfig);
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
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
    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);

    assertEq(_configuratorLogCount(), 3);
    assertEq(_latestKey(spoke, reserveId), zeroKey + 1);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
  }

  function test_releaseZeroCollateralFactor_keepsZeroWhileAnotherLeverHolds() public {
    ISpoke.DynamicReserveConfig memory savedConfig = _config(70_00, 110_00, 5_00);
    uint32 savedKey = _addDynamicConfig(reserveId, savedConfig);
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.SPOKE_MASK);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, false, true, false);

    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.SPOKE_MASK);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
  }

  function test_releaseZeroCollateralFactor_notHeld_isNoOp() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.SPOKE_MASK);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    vm.recordLogs();
    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);

    assertEq(_configuratorLogCount(), 0);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, false, true, false);
  }

  function test_releaseZeroCollateralFactor_heldBySingleReserveLever_keepsZero() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _zeroCollateralFactor(reserveId);
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);

    assertEq(_latestKey(spoke, reserveId), zeroKey);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, false, false, true);
  }

  function test_releaseZeroCollateralFactor_skipsPausedReserve() public {
    ISpoke.DynamicReserveConfig memory savedConfig = _config(70_00, 110_00, 5_00);
    uint32 savedKey = _addDynamicConfig(reserveId, savedConfig);
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    uint32 zeroKey = _latestKey(spoke, reserveId);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.pauseReserve(spokeAddr, hubAddr, underlying);

    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, true, false, false);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updatePaused(spokeAddr, hubAddr, underlying, false);
    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
  }

  function test_releaseZeroCollateralFactor_skipsReserveFrozenByBulkLever() public {
    ISpoke.DynamicReserveConfig memory savedConfig = _config(70_00, 110_00, 5_00);
    uint32 savedKey = _addDynamicConfig(reserveId, savedConfig);
    _holdFrozen(reserveId, BulkLeversMap.ASSET_MASK);
    uint32 zeroKey = _latestKey(spoke, reserveId);

    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    assertEq(_latestKey(spoke, reserveId), zeroKey);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, true, false, false);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.releaseFrozen(spokeAddr, hubAddr, underlying, BulkLeversMap.ASSET_MASK);
    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    assertFalse(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
  }

  function test_releaseZeroCollateralFactor_restoresOnReserveFrozenThroughUpdateFrozen() public {
    ISpoke.DynamicReserveConfig memory savedConfig = _config(70_00, 110_00, 5_00);
    _addDynamicConfig(reserveId, savedConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateFrozen(spokeAddr, hubAddr, underlying, true);
    _holdFrozen(reserveId, BulkLeversMap.ASSET_MASK);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor, 0);

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.releaseFrozen(spokeAddr, hubAddr, underlying, BulkLeversMap.ASSET_MASK);
    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);

    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
  }

  function test_releaseZeroCollateralFactor_collateralFactorChangedOnSpoke_clearsRecordOnly()
    public
  {
    _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    // a SPOKE_CONFIGURATOR_ROLE holder lifts the collateral factor directly on the Spoke
    vm.prank(SPOKE_ADMIN);
    uint32 liftedKey = spoke.addDynamicReserveConfig(reserveId, _config(40_00, 110_00, 5_00));

    vm.recordLogs();
    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);

    assertEq(_configuratorLogCount(), 0);
    assertEq(_latestKey(spoke, reserveId), liftedKey);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
  }

  function test_restoreCollateralFactor_clearsBulkLeverHolds() public {
    ISpoke.DynamicReserveConfig memory savedConfig = _config(70_00, 110_00, 5_00);
    _addDynamicConfig(reserveId, savedConfig);
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    _holdZeroCollateralFactor(reserveId, BulkLeversMap.SPOKE_MASK);

    uint32 restoredKey = _restoreCollateralFactor(reserveId);

    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId), savedConfig);
    _assertSavedCollateralFactor(spoke, reserveId, 0, false, false, false);
    _releaseZeroCollateralFactor(reserveId, BulkLeversMap.ASSET_MASK);
    assertEq(_latestKey(spoke, reserveId), restoredKey);
  }

  function test_upgrade_preservesSavedCollateralFactor() public {
    uint32 savedKey = _addDynamicConfig(reserveId, _config(70_00, 110_00, 5_00));
    _freezeReserve(reserveId);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, false, false, true);

    address proxyAdmin = _getProxyAdminAddress(address(spokeConfigurator));
    address newImplementation = deployCode(
      'src/spoke/instances/SpokeConfiguratorInstance.sol:SpokeConfiguratorInstance'
    );
    vm.prank(Ownable(proxyAdmin).owner());
    ProxyAdmin(proxyAdmin).upgradeAndCall(
      ITransparentUpgradeableProxy(address(spokeConfigurator)),
      newImplementation,
      ''
    );

    assertEq(_getImplementationAddress(address(spokeConfigurator)), newImplementation);
    _assertSavedCollateralFactor(spoke, reserveId, savedKey, false, false, true);
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

  function _holdZeroCollateralFactor(uint256 id, uint8 mask) internal {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.holdZeroCollateralFactor(spokeAddr, hub, asset, mask);
  }

  function _releaseZeroCollateralFactor(uint256 id, uint8 mask) internal {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.releaseZeroCollateralFactor(spokeAddr, hub, asset, mask);
  }

  function _holdFrozen(uint256 id, uint8 mask) internal {
    (address hub, address asset) = _reserveAddresses(id);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.holdFrozen(spokeAddr, hub, asset, mask);
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
