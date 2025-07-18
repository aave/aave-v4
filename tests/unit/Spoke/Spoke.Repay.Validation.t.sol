// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepayValidationTest is SpokeBase {
  function test_repay_revertsWith_ReserveNotActive() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReserveActiveFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.prank(bob);
    spoke1.repay(daiReserveId, amount);
  }

  function test_repay_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.repay(daiReserveId, amount);
  }

  function test_repay_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.repay(reserveId, amount);
  }
}
