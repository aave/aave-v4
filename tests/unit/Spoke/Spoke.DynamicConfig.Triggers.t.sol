// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeDynamicConfigTriggersTest is SpokeBase {
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

    _assertDynamicConfigRefreshEventsNotEmitted();
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
    Utils.repay(spoke1, _daiReserveId(spoke1), alice, UINT256_MAX, alice);

    _assertDynamicConfigRefreshEventsNotEmitted();
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

    _mockReservePrice(spoke1, _usdxReserveId(spoke1), 0.5e8); // make position partially liquidatable
    assertLe(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.prank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, 100e18);

    _assertDynamicConfigRefreshEventsNotEmitted();
    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertNotEq(_getSpokeDynConfigKeys(spoke1), configs);

    skip(123 days);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 80_00);

    vm.prank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, UINT256_MAX);

    _assertDynamicConfigRefreshEventsNotEmitted();
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
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
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
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
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
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), false, alice);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), _randomBps());
    configs = _getUserDynConfigKeys(spoke1, alice);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);

    // when enabling, only the relevant asset is refreshed
    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshSingleUserDynamicConfig(alice, _wethReserveId(spoke1));
    vm.prank(alice);
    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, alice);

    DynamicConfig[] memory userConfig = _getUserDynConfigKeys(spoke1, alice);
    DynamicConfig[] memory spokeConfig = _getSpokeDynConfigKeys(spoke1);
    // weth is refreshed but not all
    assertEq(userConfig[_wethReserveId(spoke1)], spokeConfig[_wethReserveId(spoke1)]);
    assertNotEq(abi.encode(userConfig), abi.encode(spokeConfig));

    // when disabling all configs are refreshed
    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), false, alice);

    assertNotEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertEq(_getSpokeDynConfigKeys(spoke1), _getUserDynConfigKeys(spoke1, alice));
  }

  function test_updateUserDynamicConfig_triggers_dynamicConfigUpdate() public {
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 95_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 90_00);
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);

    // no action yet, so user config should not change
    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertNotEq(_getSpokeDynConfigKeys(spoke1), configs);

    // manually trigger update
    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(alice);
    spoke1.updateUserDynamicConfig(alice);

    // user config should change
    assertNotEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertEq(_getSpokeDynConfigKeys(spoke1), _getUserDynConfigKeys(spoke1, alice));
  }

  function test_updateUserDynamicConfig_reverts_when_not_authorized(address caller) public {
    vm.assume(
      caller != alice &&
        caller != POSITION_MANAGER &&
        caller != SPOKE_ADMIN &&
        caller != USER_POSITION_UPDATER
    );

    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice);

    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 95_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 90_00);
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);

    // no action yet, so user config should not change
    assertEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertNotEq(_getSpokeDynConfigKeys(spoke1), configs);

    // Caller other than alice, position manager or approved admin should not be able to update
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    spoke1.updateUserDynamicConfig(alice);

    assertFalse(spoke1.isPositionManager(alice, POSITION_MANAGER));
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, POSITION_MANAGER)
    );
    vm.prank(POSITION_MANAGER);
    spoke1.updateUserDynamicConfig(alice);

    vm.prank(ADMIN);
    spoke1.updatePositionManager(POSITION_MANAGER, true);

    vm.prank(alice);
    spoke1.setUserPositionManager(POSITION_MANAGER, true);

    _updateUserDynamicConfig({caller: alice, existingConfigs: configs});
    _updateUserDynamicConfig({caller: POSITION_MANAGER, existingConfigs: configs});
    _updateUserDynamicConfig({caller: SPOKE_ADMIN, existingConfigs: configs});
    _updateUserDynamicConfig({caller: USER_POSITION_UPDATER, existingConfigs: configs});
  }

  function _updateUserDynamicConfig(
    address caller,
    DynamicConfig[] memory existingConfigs
  ) internal {
    uint256 snapshotId = vm.snapshotState();

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(caller);
    spoke1.updateUserDynamicConfig(alice);

    // user config should change
    assertNotEq(_getUserDynConfigKeys(spoke1, alice), existingConfigs);
    assertEq(_getSpokeDynConfigKeys(spoke1), _getUserDynConfigKeys(spoke1, alice));

    vm.revertToState(snapshotId);
  }
}
