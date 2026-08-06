// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeGlobalPositionManagerTest is Base {
  function test_updateGlobalPositionManager_revertsWhenUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateGlobalPositionManager(POSITION_MANAGER, true);
  }

  function test_updateGlobalPositionManager() public {
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateGlobalPositionManager(POSITION_MANAGER, true);

    vm.prank(SPOKE_ADMIN);
    spoke1.updateGlobalPositionManager(POSITION_MANAGER, true);

    assertTrue(spoke1.isGlobalPositionManager(POSITION_MANAGER));
    assertFalse(spoke1.isPositionManager(alice, POSITION_MANAGER));
  }

  function test_globalPositionManager_isApprovedForEveryUserWhenActive() public {
    _setPositionManagerActive(true);
    _setGlobalPositionManager(true);

    assertTrue(spoke1.isPositionManager(alice, POSITION_MANAGER));
    assertTrue(spoke1.isPositionManager(bob, POSITION_MANAGER));
  }

  function test_globalPositionManager_cannotBeOptedOutByUser() public {
    _setPositionManagerActive(true);
    _setGlobalPositionManager(true);

    vm.prank(alice);
    spoke1.setUserPositionManager(POSITION_MANAGER, false);

    assertTrue(spoke1.isPositionManager(alice, POSITION_MANAGER));
  }

  function test_disablingGlobalStatus_fallsBackToUserApproval() public {
    _setPositionManagerActive(true);

    vm.prank(alice);
    spoke1.setUserPositionManager(POSITION_MANAGER, true);

    _setGlobalPositionManager(true);
    assertTrue(spoke1.isPositionManager(alice, POSITION_MANAGER));
    assertTrue(spoke1.isPositionManager(bob, POSITION_MANAGER));

    _setGlobalPositionManager(false);
    assertTrue(spoke1.isPositionManager(alice, POSITION_MANAGER));
    assertFalse(spoke1.isPositionManager(bob, POSITION_MANAGER));
  }

  function test_deactivatingGlobalPositionManager_blocksDelegatedAccess() public {
    _setPositionManagerActive(true);
    _setGlobalPositionManager(true);
    assertTrue(spoke1.isPositionManager(alice, POSITION_MANAGER));

    _setPositionManagerActive(false);

    assertTrue(spoke1.isGlobalPositionManager(POSITION_MANAGER));
    assertFalse(spoke1.isPositionManager(alice, POSITION_MANAGER));
  }

  function test_globalPositionManager_canBorrowWithoutUserOptIn() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: (amount * 3) / 2,
      onBehalfOf: alice
    });
    _setPositionManagerActive(true);
    _setGlobalPositionManager(true);

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
  }

  function _setPositionManagerActive(bool active) internal {
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(POSITION_MANAGER, active);
  }

  function _setGlobalPositionManager(bool global) internal {
    vm.prank(SPOKE_ADMIN);
    spoke1.updateGlobalPositionManager(POSITION_MANAGER, global);
  }
}
