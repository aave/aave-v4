// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  using SafeCast for uint256;

  function test_setUsingAsCollateral_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(daiReserveId, true, alice);

    assertTrue(spoke1.isUsingAsCollateral(daiReserveId, alice), 'alice using as collateral');
    assertFalse(spoke1.isUsingAsCollateral(daiReserveId, bob), 'bob not using as collateral');

    updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.frozen, 'reserve status frozen');

    // disallow when activating
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.setUsingAsCollateral(daiReserveId, true, bob);

    // allow when deactivating
    vm.prank(alice);
    spoke1.setUsingAsCollateral(daiReserveId, false, alice);

    assertFalse(
      spoke1.isUsingAsCollateral(daiReserveId, alice),
      'alice deactivated using as collateral frozen reserve'
    );
  }

  function test_setUsingAsCollateral_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(daiReserveId, true, alice);
  }

  /// no action taken when collateral status is unchanged
  function test_setUsingAsCollateral_collateralStatusUnchanged() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // slight update in collateral factor so user is subject to dynamic risk config refresh
    updateCollateralFactor(spoke1, daiReserveId, _getCollateralFactor(spoke1, daiReserveId) + 1_00);
    // slight update collateral risk so user is subject to risk premium refresh
    updateCollateralRisk(spoke1, daiReserveId, _getCollateralRisk(spoke1, daiReserveId) + 1_00);

    // Bob not using DAI as collateral
    assertFalse(spoke1.isUsingAsCollateral(daiReserveId, bob), 'bob not using as collateral');

    // No action taken, because collateral status is already false
    DynamicConfig[] memory bobDynConfig = _getUserDynConfigKeys(spoke1, bob);
    uint256 bobRp = _getUserRpStored(spoke1, daiReserveId, bob);

    vm.recordLogs();
    Utils.setUsingAsCollateral(spoke1, daiReserveId, bob, false, bob);
    _assertEventNotEmitted(ISpoke.UsingAsCollateral.selector);

    assertFalse(spoke1.isUsingAsCollateral(daiReserveId, bob));
    assertEq(_getUserRpStored(spoke1, daiReserveId, bob), bobRp);
    assertEq(_getUserDynConfigKeys(spoke1, bob), bobDynConfig);

    // Bob can change dai collateral status to true
    Utils.setUsingAsCollateral(spoke1, daiReserveId, bob, true, bob);
    assertTrue(spoke1.isUsingAsCollateral(daiReserveId, bob), 'bob using as collateral');

    // slight update in collateral factor so user is subject to dynamic risk config refresh
    updateCollateralFactor(spoke1, daiReserveId, _getCollateralFactor(spoke1, daiReserveId) + 1_00);
    // slight update collateral risk so user is subject to risk premium refresh
    updateCollateralRisk(spoke1, daiReserveId, _getCollateralRisk(spoke1, daiReserveId) + 1_00);

    // No action taken, because collateral status is already true
    bobDynConfig = _getUserDynConfigKeys(spoke1, bob);
    bobRp = _getUserRpStored(spoke1, daiReserveId, bob);

    vm.recordLogs();
    Utils.setUsingAsCollateral(spoke1, daiReserveId, bob, true, bob);
    _assertEventsNotEmitted(
      ISpoke.UsingAsCollateral.selector,
      ISpoke.RefreshSingleUserDynamicConfig.selector,
      ISpoke.RefreshAllUserDynamicConfig.selector
    );

    assertTrue(spoke1.isUsingAsCollateral(daiReserveId, bob));
    assertEq(_getUserRpStored(spoke1, daiReserveId, bob), bobRp);
    assertEq(_getUserDynConfigKeys(spoke1, bob), bobDynConfig);
  }

  function test_setUsingAsCollateral() public {
    bool newCollateralFlag = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    uint256 daiReserveId = _daiReserveId(spoke1);

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, daiAmount);
    Utils.supply(spoke1, daiReserveId, bob, daiAmount, bob);

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.UsingAsCollateral(daiReserveId, bob, bob, usingAsCollateral);
    spoke1.setUsingAsCollateral(daiReserveId, usingAsCollateral, bob);

    assertEq(
      spoke1.isUsingAsCollateral(daiReserveId, bob),
      usingAsCollateral,
      'wrong usingAsCollateral'
    );
  }
}
