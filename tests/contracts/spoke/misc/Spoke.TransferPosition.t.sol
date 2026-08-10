// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeTransferPositionTest is Base {
  address internal TRANSFER_ADMIN = makeAddr('TRANSFER_ADMIN');

  function setUp() public virtual override {
    super.setUp();

    vm.prank(ADMIN);
    accessManager.grantRole(Roles.SPOKE_POSITION_TRANSFER_ADMIN_ROLE, TRANSFER_ADMIN, 0);
  }

  function test_transferPosition() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });
    uint256 aliceShares = spoke1.getUserSuppliedShares(reserveId, alice);
    uint256 sharesToTransfer = aliceShares / 2;

    vm.expectEmit(address(spoke1));
    emit ISpoke.TransferPosition(reserveId, alice, bob, sharesToTransfer);

    vm.prank(TRANSFER_ADMIN);
    uint256 transferredShares = spoke1.transferPosition(reserveId, alice, bob, sharesToTransfer);

    assertEq(transferredShares, sharesToTransfer);
    assertEq(spoke1.getUserSuppliedShares(reserveId, alice), aliceShares - sharesToTransfer);
    assertEq(spoke1.getUserSuppliedShares(reserveId, bob), sharesToTransfer);
  }

  function test_transferPosition_maxSignalsFullTransfer() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });
    uint256 aliceShares = spoke1.getUserSuppliedShares(reserveId, alice);

    vm.prank(TRANSFER_ADMIN);
    uint256 transferredShares = spoke1.transferPosition(reserveId, alice, bob, type(uint256).max);

    assertEq(transferredShares, aliceShares);
    assertEq(spoke1.getUserSuppliedShares(reserveId, alice), 0);
    assertEq(spoke1.getUserSuppliedShares(reserveId, bob), aliceShares);
  }

  function test_transferPosition_revertsIfUnauthorized() public {
    uint256 reserveId = _usdxReserveId(spoke1);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spoke1.transferPosition(reserveId, alice, bob, 1);

    // the spoke admin does not hold the position transfer admin role either
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, SPOKE_ADMIN)
    );
    vm.prank(SPOKE_ADMIN);
    spoke1.transferPosition(reserveId, alice, bob, 1);
  }

  function test_transferPosition_validatesHealthFactorOfFrom() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount * 2,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    vm.prank(TRANSFER_ADMIN);
    spoke1.transferPosition(reserveId, alice, bob, type(uint256).max);
  }

  function test_transferPosition_allowedWhenFrozen() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });
    uint256 aliceShares = spoke1.getUserSuppliedShares(reserveId, alice);
    _updateReserveFrozenFlag(spoke1, reserveId, true);

    vm.prank(TRANSFER_ADMIN);
    spoke1.transferPosition(reserveId, alice, bob, type(uint256).max);

    assertEq(spoke1.getUserSuppliedShares(reserveId, bob), aliceShares);
  }

  function test_transferPosition_revertsWhenPaused() public {
    uint256 reserveId = _usdxReserveId(spoke1);

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });
    _updateReservePausedFlag(spoke1, reserveId, true);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(TRANSFER_ADMIN);
    spoke1.transferPosition(reserveId, alice, bob, type(uint256).max);
  }

  function test_transferPosition_revertsOnSelfTransfer() public {
    uint256 reserveId = _usdxReserveId(spoke1);

    vm.expectRevert(ISpoke.SelfTransfer.selector);
    vm.prank(TRANSFER_ADMIN);
    spoke1.transferPosition(reserveId, alice, alice, 1);
  }

  function test_transferPosition_revertsOnZeroAddressTo() public {
    uint256 reserveId = _usdxReserveId(spoke1);

    vm.expectRevert(ISpoke.InvalidAddress.selector);
    vm.prank(TRANSFER_ADMIN);
    spoke1.transferPosition(reserveId, alice, address(0), 1);
  }

  function test_transferPosition_revertsIfReserveNotListed() public {
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(TRANSFER_ADMIN);
    spoke1.transferPosition(type(uint256).max, alice, bob, 1);
  }

  function test_transferPosition_doesNotEnableCollateralForRecipient() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    vm.prank(TRANSFER_ADMIN);
    spoke1.transferPosition(reserveId, alice, bob, type(uint256).max);

    (bool usingAsCollateral, ) = spoke1.getUserReserveStatus(reserveId, bob);
    assertFalse(usingAsCollateral);

    // the recipient can enable it and use the position
    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      usingAsCollateral: true,
      onBehalfOf: bob
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: amount / 2,
      onBehalfOf: bob
    });

    assertEq(spoke1.getUserTotalDebt(reserveId, bob), amount / 2);
  }
}
