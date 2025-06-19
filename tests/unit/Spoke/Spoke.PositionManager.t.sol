// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokePositionManagerTest is SpokeBase {
  function test_setApprovalForPositionManager(bytes32) public {
    vm.setArbitraryStorage(address(spoke1));

    address user = vm.randomAddress();
    address positionManager = vm.randomAddress();
    bool approve = vm.randomBool();

    // if position manager not active, then user should not be able to approve, else action should be idempotent
    if (!spoke1.isPositionManagerActive(positionManager) && approve) {
      vm.expectRevert(ISpoke.InactivePositionManager.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.ApprovalForPositionManager(user, positionManager, approve);
    }

    vm.prank(user);
    spoke1.setApprovalForPositionManager(positionManager, approve);
  }

  function test_renouncePositionManagerRole() public {
    vm.setArbitraryStorage(address(spoke1));

    address user = vm.randomAddress();
    address positionManager = vm.randomAddress();

    vm.expectEmit(address(spoke1));
    emit ISpoke.ApprovalForPositionManager(user, positionManager, false);
    vm.prank(positionManager);
    spoke1.renouncePositionManagerRole(user);
  }

  function test_onlyPositionManager_on_supply() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    vm.prank(alice);
    tokenList.usdx.approve(address(hub), 0);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.supply(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    _approvePositionManager(alice);

    DataTypes.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(POSITION_MANAGER), address(hub), amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(reserveId, POSITION_MANAGER, alice, amount);
    Utils.supply(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserSuppliedAmount(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserSuppliedAmount(reserveId, alice), amount);
  }

  function test_onlyPositionManager_on_withdraw() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    vm.prank(alice);
    tokenList.usdx.approve(address(hub), 0);
    Utils.supply(spoke1, reserveId, alice, amount, alice);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.withdraw(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    _approvePositionManager(alice);
    _resetAllowance(alice);

    DataTypes.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);
    amount /= 2;

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(hub), address(POSITION_MANAGER), amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(reserveId, POSITION_MANAGER, alice, amount);
    Utils.withdraw(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserSuppliedAmount(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserSuppliedAmount(reserveId, alice), amount);
  }

  function test_onlyPositionManager_on_borrow() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    Utils.supplyCollateral(spoke1, reserveId, alice, (amount * 3) / 2, alice);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.borrow(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    _approvePositionManager(alice);
    _resetAllowance(alice);

    DataTypes.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(hub), address(POSITION_MANAGER), amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow(reserveId, POSITION_MANAGER, alice, amount);
    Utils.borrow(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount);
  }

  function test_onlyPositionManager_on_repay() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    Utils.supplyCollateral(spoke1, reserveId, alice, (amount * 3) / 2, alice);
    Utils.borrow(spoke1, reserveId, alice, amount, alice);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.repay(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    _approvePositionManager(alice);
    _resetAllowance(alice);

    DataTypes.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(POSITION_MANAGER), address(hub), amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(reserveId, POSITION_MANAGER, alice, amount);
    Utils.repay(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), 0);
  }

  function _approvePositionManager(address who) internal {
    assertFalse(spoke1.isPositionManager(who, POSITION_MANAGER));
    assertFalse(spoke1.isPositionManagerActive(POSITION_MANAGER));

    vm.expectEmit(address(spoke1));
    emit ISpoke.PositionManagerSet(POSITION_MANAGER, true);
    vm.prank(SPOKE_ADMIN);
    spoke1.setPositionManager(POSITION_MANAGER, true);

    vm.expectEmit(address(spoke1));
    emit ISpoke.ApprovalForPositionManager(who, POSITION_MANAGER, true);
    vm.prank(who);
    spoke1.setApprovalForPositionManager(POSITION_MANAGER, true);

    assertTrue(spoke1.isPositionManager(who, POSITION_MANAGER));
    assertTrue(spoke1.isPositionManagerActive(POSITION_MANAGER));
  }

  function _resetAllowance(address user) internal {
    vm.prank(user);
    tokenList.usdx.approve(address(hub), 0);
  }
}
