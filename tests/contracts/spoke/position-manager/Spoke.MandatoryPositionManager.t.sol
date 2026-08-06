// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeMandatoryPositionManagerTest is Base {
  function test_updateMandatoryPositionManager() public {
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateMandatoryPositionManager(ISpoke.borrow.selector, POSITION_MANAGER);

    vm.prank(SPOKE_ADMIN);
    spoke1.updateMandatoryPositionManager(ISpoke.borrow.selector, POSITION_MANAGER);

    assertEq(spoke1.getMandatoryPositionManager(ISpoke.borrow.selector), POSITION_MANAGER);
  }

  function test_updateMandatoryPositionManager_revertsIfUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spoke1.updateMandatoryPositionManager(ISpoke.borrow.selector, POSITION_MANAGER);
  }

  function test_mandatoryPositionManager_restrictsBorrowToConfiguredManager() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    address otherPositionManager = makeAddr('OTHER_POSITION_MANAGER');

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: (amount * 3) / 2,
      onBehalfOf: alice
    });
    _activateAndApprovePositionManager(POSITION_MANAGER, alice);
    _activateAndApprovePositionManager(otherPositionManager, alice);
    _setMandatoryPositionManager(ISpoke.borrow.selector, POSITION_MANAGER);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: otherPositionManager,
      amount: amount,
      onBehalfOf: alice
    });

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount);
  }

  function test_mandatoryPositionManager_isSelectorScoped() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    _setMandatoryPositionManager(ISpoke.borrow.selector, POSITION_MANAGER);

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), amount);
  }

  function test_mandatoryPositionManager_canBeRemoved() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: (amount * 3) / 2,
      onBehalfOf: alice
    });
    _setMandatoryPositionManager(ISpoke.borrow.selector, POSITION_MANAGER);
    _setMandatoryPositionManager(ISpoke.borrow.selector, address(0));

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getMandatoryPositionManager(ISpoke.borrow.selector), address(0));
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount);
  }

  function test_mandatoryPositionManager_stillRequiresUserApproval() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: (amount * 3) / 2,
      onBehalfOf: alice
    });
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(POSITION_MANAGER, true);
    _setMandatoryPositionManager(ISpoke.borrow.selector, POSITION_MANAGER);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });
  }

  function test_mandatoryPositionManager_cannotBeBypassedWithMulticall() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: (amount * 3) / 2,
      onBehalfOf: alice
    });
    _setMandatoryPositionManager(ISpoke.borrow.selector, POSITION_MANAGER);

    bytes[] memory calls = new bytes[](1);
    calls[0] = abi.encodeCall(ISpoke.borrow, (reserveId, amount, alice));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    spoke1.multicall(calls);
  }

  function _activateAndApprovePositionManager(address positionManager, address user) internal {
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(positionManager, true);

    vm.prank(user);
    spoke1.setUserPositionManager(positionManager, true);
  }

  function _setMandatoryPositionManager(bytes4 selector, address positionManager) internal {
    vm.prank(SPOKE_ADMIN);
    spoke1.updateMandatoryPositionManager(selector, positionManager);
  }
}
