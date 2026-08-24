// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/babylon-spoke/BabylonSpoke.Base.t.sol';

contract BabylonSpokeConfigTest is BabylonSpokeBaseTest {
  function test_liquidationCall_revertsWith_UnsupportedLiquidationCall() public {
    vm.prank(liquidator);
    vm.expectRevert(IBabylonSpoke.UnsupportedLiquidationCall.selector);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      100e6,
      false
    );
  }

  function test_updateLiquidationBypass() public {
    uint256 reserveId = _daiReserveId(spoke1);
    IBabylonSpoke.LiquidationBypass memory bypass = babylonSpoke.getLiquidationBypass(reserveId);
    assertFalse(bypass.bypassLiquidationDust);
    assertFalse(bypass.bypassTargetHealthFactor);

    bypass = IBabylonSpoke.LiquidationBypass({
      bypassLiquidationDust: true,
      bypassTargetHealthFactor: true
    });
    vm.expectEmit(address(babylonSpoke));
    emit IBabylonSpoke.UpdateLiquidationBypass(reserveId, bypass);
    vm.prank(SPOKE_ADMIN);
    babylonSpoke.updateLiquidationBypass(reserveId, bypass);

    IBabylonSpoke.LiquidationBypass memory stored = babylonSpoke.getLiquidationBypass(reserveId);
    assertTrue(stored.bypassLiquidationDust);
    assertTrue(stored.bypassTargetHealthFactor);

    bypass = IBabylonSpoke.LiquidationBypass({
      bypassLiquidationDust: false,
      bypassTargetHealthFactor: false
    });
    vm.prank(SPOKE_ADMIN);
    babylonSpoke.updateLiquidationBypass(reserveId, bypass);

    stored = babylonSpoke.getLiquidationBypass(reserveId);
    assertFalse(stored.bypassLiquidationDust);
    assertFalse(stored.bypassTargetHealthFactor);
  }

  function test_updateLiquidationBypass_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    babylonSpoke.updateLiquidationBypass(
      _daiReserveId(spoke1),
      IBabylonSpoke.LiquidationBypass({bypassLiquidationDust: true, bypassTargetHealthFactor: true})
    );
  }

  function test_updateLiquidationBypass_revertsWith_ReserveNotListed() public {
    uint256 unlistedReserveId = spoke1.getReserveCount();
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(SPOKE_ADMIN);
    babylonSpoke.updateLiquidationBypass(
      unlistedReserveId,
      IBabylonSpoke.LiquidationBypass({bypassLiquidationDust: true, bypassTargetHealthFactor: true})
    );
  }

  function test_liquidationCall_revertsWith_InvalidMaxCollateralToRemove() public {
    _setupPosition(2100e18, 0.98e18);

    vm.prank(liquidator);
    vm.expectRevert(IBabylonSpoke.InvalidMaxCollateralToRemove.selector);
    babylonSpoke.liquidationCall(
      _daiReserveId(spoke1),
      _usdxReserveId(spoke1),
      alice,
      100e6,
      0,
      false
    );
  }
}
