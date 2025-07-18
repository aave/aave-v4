// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeDynamicConfigTest is SpokeBase {
  using SafeCast for uint256;

  function test_updateDynamicReserveConfig_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice));
    vm.prank(alice);
    spoke1.updateDynamicReserveConfig(
      _daiReserveId(spoke1), 
      DataTypes.DynamicReserveConfig({
        collateralFactor: 80_00,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
  }

  function test_updateDynamicReserveConfig_revertsWith_ReserveNotListed() public {
    uint256 invalidReserveId = spoke1.getReserveCount();
    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector, invalidReserveId));
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(
      invalidReserveId, 
      DataTypes.DynamicReserveConfig({
        collateralFactor: 80_00,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
  }

  function test_updateDynamicReserveConfig_revertsWith_InvalidCollateralFactor() public {
    uint16 collateralFactor = vm
      .randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max)
      .toUint16();

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(daiReserveId);
    config.collateralFactor = collateralFactor;

    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(daiReserveId, config);
  }

  // update each reserve's config key
  function test_updateDynamicReserveConfig_once() public {
    DynamicConfig[] memory configs = _getSpokeDynConfigKeys(spoke1);

    for (uint256 reserveId; reserveId < spoke1.getReserveCount(); ++reserveId) {
      uint16 dynamicConfigKey = _nextDynamicConfigKey(spoke1, reserveId);

      DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);
      dynConf.collateralFactor = _randomBps();
      vm.expectEmit(address(spoke1));
      emit ISpoke.DynamicReserveConfigUpdated(reserveId, dynamicConfigKey, dynConf);
      vm.prank(SPOKE_ADMIN);
      spoke1.updateDynamicReserveConfig(reserveId, dynConf);

      configs[reserveId].key = dynamicConfigKey;
      assertEq(_getSpokeDynConfigKeys(spoke1), configs);
    }
  }

  // more realistic, update config keys in a random order
  function test_fuzz_updateDynamicReserveConfig_trailing_order(bytes32) public {
    DynamicConfig[] memory configs = _getSpokeDynConfigKeys(spoke1);
    uint256 runs = vm.randomUint(1, 100); // [1,100] iterations each fuzz run

    while (--runs != 0) {
      uint256 reserveId = vm.randomUint(0, spoke1.getReserveCount() - 1);
      uint16 dynamicConfigKey = _nextDynamicConfigKey(spoke1, reserveId);

      DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);
      dynConf.collateralFactor = _randomBps();

      vm.expectEmit(address(spoke1));
      emit ISpoke.DynamicReserveConfigUpdated(reserveId, dynamicConfigKey, dynConf);
      vm.prank(SPOKE_ADMIN);
      spoke1.updateDynamicReserveConfig(reserveId, dynConf);

      configs[reserveId].key = dynamicConfigKey;
      assertEq(_getSpokeDynConfigKeys(spoke1), configs);
    }
  }

  // update duplicated config values
  function test_fuzz_updateDynamicReserveConfig_spaced_dup_updates(bytes32) public {
    DynamicConfig[] memory configs = _getSpokeDynConfigKeys(spoke1);
    uint256 runs = vm.randomUint(1, 100); // [1,100] iterations each fuzz run

    while (--runs != 0) {
      uint256 reserveId = vm.randomUint(0, spoke1.getReserveCount() - 1);
      uint16 dynamicConfigKey = _nextDynamicConfigKey(spoke1, reserveId);

      DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);
      dynConf.collateralFactor = vm.randomUint() % 2 == 0
        ? spoke1
          .getDynamicReserveConfig(reserveId, vm.randomUint(0, dynamicConfigKey - 1).toUint16())
          .collateralFactor
        : _randomBps();

      vm.expectEmit(address(spoke1));
      emit ISpoke.DynamicReserveConfigUpdated(reserveId, dynamicConfigKey, dynConf);
      vm.prank(SPOKE_ADMIN);
      spoke1.updateDynamicReserveConfig(reserveId, dynConf);

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
