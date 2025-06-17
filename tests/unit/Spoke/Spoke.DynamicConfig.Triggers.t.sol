// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeDynamicConfigTriggersTest is SpokeBase {
  using SafeCast for uint256;

  function test_supply_does_not_trigger_dynamicConfigUpdate() public {
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);

    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), _randomBps());

    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 500e18);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);
    configs = _getUserDynConfigKeys(spoke1, alice);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), _randomBps());

    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);

    Utils.supply(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);

    // user config should not change
    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertNotEq(_getSpokeDynConfigKeys(spoke1), configs);
  }

  function test_repay_does_not_trigger_dynamicConfigUpdate() public {
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 500e18);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);

    configs = _getUserDynConfigKeys(spoke1, alice);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 90_10);
    skip(322 days);
    Utils.repay(spoke1, _daiReserveId(spoke1), alice, UINT256_MAX);

    // user config should not change
    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertNotEq(_getSpokeDynConfigKeys(spoke1), configs);
  }

  function test_liquidate_does_not_trigger_dynamicConfigUpdate() public {
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);

    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 500e18);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);
    configs = _getUserDynConfigKeys(spoke1, alice);
    skip(322 days);

    // usdx (user coll) is offboarded
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 0);
    // position is still healthy
    assertGe(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    oracle.setAssetPrice(usdxAssetId, 0.5e8); // make position partially liquidatable
    assertLe(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.prank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, 100e18);

    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertNotEq(_getSpokeDynConfigKeys(spoke1), configs);

    skip(123 days);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 80_00);

    vm.prank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, UINT256_MAX);

    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertNotEq(_getSpokeDynConfigKeys(spoke1), configs);
  }

  function test_borrow_triggers_dynamicConfigUpdate() public {
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);

    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 600e18);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);
    configs = _getUserDynConfigKeys(spoke1, alice);
    skip(322 days);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 0);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 100e18, alice);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), _randomBps());
    configs = _getUserDynConfigKeys(spoke1, alice);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UserDynamicConfigRefreshed(alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);

    assertNotEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertEq(_getSpokeDynConfigKeys(spoke1), _getUserDynConfigKeys(spoke1, alice));
  }

  function test_withdraw_triggers_dynamicConfigUpdate() public {
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);

    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 600e18);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);
    configs = _getUserDynConfigKeys(spoke1, alice);
    skip(322 days);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 0);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    vm.prank(alice);
    spoke1.withdraw(_usdxReserveId(spoke1), 500e6, alice);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), _randomBps());
    configs = _getUserDynConfigKeys(spoke1, alice);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UserDynamicConfigRefreshed(alice);
    Utils.withdraw(spoke1, _usdxReserveId(spoke1), alice, 500e6, alice);

    assertNotEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertEq(_getSpokeDynConfigKeys(spoke1), _getUserDynConfigKeys(spoke1, alice));
  }

  function test_usingAsCollateral_triggers_dynamicConfigUpdate() public {
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);

    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 600e18);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);
    configs = _getUserDynConfigKeys(spoke1, alice);
    skip(322 days);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 0);
    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), false);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), _randomBps());
    configs = _getUserDynConfigKeys(spoke1, alice);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);
    vm.expectEmit(address(spoke1));
    emit ISpoke.UserDynamicConfigRefreshed(alice);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UserDynamicConfigRefreshed(alice);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), false);

    assertNotEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertEq(_getSpokeDynConfigKeys(spoke1), _getUserDynConfigKeys(spoke1, alice));
  }
}
