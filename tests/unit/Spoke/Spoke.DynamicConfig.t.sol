// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeDynamicConfigTest is SpokeBase {
  using SafeCast for uint256;
  using PercentageMath for uint256;

  function test_addDynamicReserveConfig_revertsWith_InvalidLiquidationBonus() public {
    uint256 reserveId = _randomReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(reserveId);
    config.liquidationBonus = vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR - 1);

    vm.expectRevert(ISpoke.InvalidLiquidationBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addDynamicReserveConfig(reserveId, config);
  }

  function test_addDynamicReserveConfig_fuzz_revertsWith_IncompatibleCollateralFactorAndLiquidationBonus(
    uint256 collateralFactor,
    uint256 liquidationBonus
  ) public {
    // Force config such that cf * lb > 100%
    collateralFactor = bound(collateralFactor, 70_00, PercentageMath.PERCENTAGE_FACTOR);
    liquidationBonus = bound(
      liquidationBonus,
      PercentageMath.PERCENTAGE_FACTOR.percentDivUp(collateralFactor) + 1,
      MAX_LIQUIDATION_BONUS
    );

    uint256 reserveId = _randomReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(reserveId);
    config.collateralFactor = collateralFactor.toUint16();
    config.liquidationBonus = liquidationBonus;

    vm.expectRevert(ISpoke.IncompatibleCollateralFactorAndLiquidationBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addDynamicReserveConfig(reserveId, config);
  }

  function test_addDynamicReserveConfig_revertsWith_InvalidLiquidationFee() public {
    uint256 reserveId = _randomReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(reserveId);
    config.liquidationFee = vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint256).max);

    vm.expectRevert(ISpoke.InvalidLiquidationFee.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addDynamicReserveConfig(reserveId, config);
  }

  function test_addDynamicReserveConfig_revertsWith_InvalidCollateralFactor() public {
    uint16 collateralFactor = vm
      .randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
      .toUint16();

    uint256 reserveId = _randomReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(reserveId);
    config.collateralFactor = collateralFactor;

    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addDynamicReserveConfig(reserveId, config);
  }

  function test_addDynamicReserveConfig_revertsWith_ReserveNotListed() public {
    uint256 invalidReserveId = vm.randomUint(spoke1.getReserveCount(), type(uint256).max);
    DataTypes.DynamicReserveConfig memory dynConf;

    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector, invalidReserveId));
    vm.prank(SPOKE_ADMIN);
    spoke1.addDynamicReserveConfig(invalidReserveId, dynConf);
  }

  function test_addDynamicReserveConfig_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    vm.assume(caller != SPOKE_ADMIN && caller != ADMIN);
    uint256 reserveId = _randomReserveId(spoke1);
    uint16 configKey = _randomInitializedConfigKey(spoke1, reserveId);
    DataTypes.DynamicReserveConfig memory dynConf = DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    spoke1.updateDynamicReserveConfig(reserveId, configKey, dynConf);
  }

  function test_updateDynamicReserveConfig_revertsWith_InvalidLiquidationBonus() public {
    uint256 reserveId = _randomReserveId(spoke1);
    uint16 configKey = _randomInitializedConfigKey(spoke1, reserveId);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(reserveId);
    config.liquidationBonus = vm.randomUint(0, PercentageMath.PERCENTAGE_FACTOR - 1);

    vm.expectRevert(ISpoke.InvalidLiquidationBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(reserveId, configKey, config);
  }

  function test_updateDynamicReserveConfig_fuzz_revertsWith_IncompatibleCollateralFactorAndLiquidationBonus(
    uint256 collateralFactor,
    uint256 liquidationBonus
  ) public {
    // Force config such that cf * lb > 100%
    collateralFactor = bound(collateralFactor, 70_00, PercentageMath.PERCENTAGE_FACTOR);
    liquidationBonus = bound(
      liquidationBonus,
      PercentageMath.PERCENTAGE_FACTOR.percentDivUp(collateralFactor) + 1,
      MAX_LIQUIDATION_BONUS
    );

    uint256 reserveId = _randomReserveId(spoke1);
    uint16 configKey = _randomInitializedConfigKey(spoke1, reserveId);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(reserveId);
    config.collateralFactor = collateralFactor.toUint16();
    config.liquidationBonus = liquidationBonus;

    vm.expectRevert(ISpoke.IncompatibleCollateralFactorAndLiquidationBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(reserveId, configKey, config);
  }

  function test_updateDynamicReserveConfig_revertsWith_InvalidLiquidationFee() public {
    uint256 reserveId = _randomReserveId(spoke1);
    uint16 configKey = _randomInitializedConfigKey(spoke1, reserveId);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(reserveId);
    config.liquidationFee = vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint256).max);

    vm.expectRevert(ISpoke.InvalidLiquidationFee.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(reserveId, configKey, config);
  }

  function test_updateDynamicReserveConfig_revertsWith_InvalidCollateralFactor() public {
    uint16 collateralFactor = vm
      .randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
      .toUint16();

    uint256 reserveId = _randomReserveId(spoke1);
    uint16 configKey = _randomInitializedConfigKey(spoke1, reserveId);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(reserveId);
    config.collateralFactor = collateralFactor;

    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(reserveId, configKey, config);
  }

  function test_updateDynamicReserveConfig_revertsWith_ReserveNotListed() public {
    uint256 invalidReserveId = vm.randomUint(spoke1.getReserveCount(), type(uint256).max);
    DataTypes.DynamicReserveConfig memory dynConf;

    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector, invalidReserveId));
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(invalidReserveId, _randomConfigKey(), dynConf);
  }

  function test_updateDynamicReserveConfig_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    vm.assume(caller != SPOKE_ADMIN && caller != ADMIN);
    uint256 reserveId = _randomReserveId(spoke1);
    uint16 configKey = _randomInitializedConfigKey(spoke1, reserveId);
    DataTypes.DynamicReserveConfig memory dynConf = DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    spoke1.updateDynamicReserveConfig(reserveId, configKey, dynConf);
  }

  function test_updateDynamicReserveConfig_revertsWith_ConfigKeyUninitialized() public {
    uint256 reserveId = _randomReserveId(spoke1);
    uint16 configKey = _randomUninitializedConfigKey(spoke1, reserveId);
    DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);

    vm.expectRevert(ISpoke.ConfigKeyUninitialized.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(reserveId, configKey, dynConf);
  }

  function test_addDynamicReserveConfig() public {
    DataTypes.DynamicReserveConfig memory dynConf = DataTypes.DynamicReserveConfig({
      collateralFactor: 20_00,
      liquidationBonus: 130_00,
      liquidationFee: 15_00
    });
    uint256 reserveId = _randomReserveId(spoke1);
    uint16 expectedConfigKey = _nextDynamicConfigKey(spoke1, reserveId);

    vm.expectEmit(address(spoke1));
    emit ISpoke.AddDynamicReserveConfig(reserveId, expectedConfigKey, dynConf);
    vm.prank(SPOKE_ADMIN);
    spoke1.addDynamicReserveConfig(reserveId, dynConf);

    assertEq(spoke1.getDynamicReserveConfig(reserveId), dynConf);
    assertEq(spoke1.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
  }

  function test_updateDynamicReserveConfig() public {
    DataTypes.DynamicReserveConfig memory dynConf = DataTypes.DynamicReserveConfig({
      collateralFactor: 20_00,
      liquidationBonus: 130_00,
      liquidationFee: 15_00
    });
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 count = vm.randomUint(1, 50);
    for (uint256 i; i < count; ++i) {
      dynConf.liquidationFee = _randomBps();
      vm.prank(SPOKE_ADMIN);
      spoke1.addDynamicReserveConfig(reserveId, dynConf);
    }
    assertEq(spoke1.getReserve(reserveId).dynamicConfigKey, count);

    uint16 configKey = vm.randomUint(0, count).toUint16();
    dynConf.liquidationFee = _randomBps();

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateDynamicReserveConfig(reserveId, configKey, dynConf);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(reserveId, configKey, dynConf);

    assertEq(spoke1.getDynamicReserveConfig(reserveId, configKey), dynConf);
  }

  // update each reserve's config key
  function test_addDynamicReserveConfig_once() public {
    test_addDynamicReserveConfig();
    DynamicConfig[] memory configs = _getSpokeDynConfigKeys(spoke1);

    for (uint256 reserveId; reserveId < spoke1.getReserveCount(); ++reserveId) {
      uint16 dynamicConfigKey = _nextDynamicConfigKey(spoke1, reserveId);

      DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);
      dynConf.collateralFactor = _randomBps();
      vm.expectEmit(address(spoke1));
      emit ISpoke.AddDynamicReserveConfig(reserveId, dynamicConfigKey, dynConf);
      vm.prank(SPOKE_ADMIN);
      spoke1.addDynamicReserveConfig(reserveId, dynConf);

      configs[reserveId].key = dynamicConfigKey;
      assertEq(_getSpokeDynConfigKeys(spoke1), configs);
    }
  }

  // more realistic, update config keys in a random order
  function test_fuzz_addDynamicReserveConfig_trailing_order(bytes32) public {
    DynamicConfig[] memory configs = _getSpokeDynConfigKeys(spoke1);
    uint256 runs = vm.randomUint(1, 100); // [1,100] iterations each fuzz run

    while (--runs != 0) {
      uint256 reserveId = _randomReserveId(spoke1);
      uint16 dynamicConfigKey = _nextDynamicConfigKey(spoke1, reserveId);

      DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);
      dynConf.collateralFactor = _randomBps();

      vm.expectEmit(address(spoke1));
      emit ISpoke.AddDynamicReserveConfig(reserveId, dynamicConfigKey, dynConf);
      vm.prank(SPOKE_ADMIN);
      spoke1.addDynamicReserveConfig(reserveId, dynConf);

      configs[reserveId].key = dynamicConfigKey;
      assertEq(_getSpokeDynConfigKeys(spoke1), configs);
    }
  }

  // update duplicated config values
  function test_fuzz_addDynamicReserveConfig_spaced_dup_updates(bytes32) public {
    DynamicConfig[] memory configs = _getSpokeDynConfigKeys(spoke1);
    uint256 runs = vm.randomUint(1, 100); // [1,100] iterations each fuzz run

    while (--runs != 0) {
      uint256 reserveId = _randomReserveId(spoke1);
      uint16 dynamicConfigKey = _nextDynamicConfigKey(spoke1, reserveId);

      DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);
      dynConf.collateralFactor = vm.randomUint() % 2 == 0
        ? spoke1
          .getDynamicReserveConfig(reserveId, vm.randomUint(0, dynamicConfigKey - 1).toUint16())
          .collateralFactor
        : _randomBps();

      vm.expectEmit(address(spoke1));
      emit ISpoke.AddDynamicReserveConfig(reserveId, dynamicConfigKey, dynConf);
      vm.prank(SPOKE_ADMIN);
      spoke1.addDynamicReserveConfig(reserveId, dynConf);

      configs[reserveId].key = dynamicConfigKey;
      assertEq(_getSpokeDynConfigKeys(spoke1), configs);
    }
  }

  function test_offboardReserve_existing_borrows_remain_unaffected() public {
    _openSupplyPosition(spoke1, _wethReserveId(spoke1), 3e18);

    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 2600e6, alice);
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), bob, 2600e6, bob);
    Utils.borrow(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);

    // offboard usdx
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 0);

    // existing users: alice, bob
    // alice still healthy
    assertGt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    // bob cannot borrow after collateral is disabled
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    Utils.borrow(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);

    // new user: carol; cannot borrow with usdx as collateral
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), carol, 2600e6, carol);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    Utils.borrow(spoke1, _wethReserveId(spoke1), carol, 1e18, carol);

    // alice cannot borrow more with usdx as collateral
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    Utils.borrow(spoke1, _wethReserveId(spoke1), alice, 1, alice);
  }

  // todo test key overwrites stale slot, dynamically determine struct size & overwrite dynamicConfigKey or use mock spoke
}
