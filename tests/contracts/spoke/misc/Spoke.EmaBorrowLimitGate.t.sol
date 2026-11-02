// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/GateSpokeBase.sol';

import {EmaBorrowLimitGate} from 'src/spoke/gates/EmaBorrowLimitGate.sol';

contract SpokeEmaBorrowLimitGateTest is GateSpokeBase {
  EmaBorrowLimitGate internal limitGate;
  PositionManagerGate internal positionManagerGate;
  ISpoke internal target;

  uint32 internal constant TAU = 1 days;

  function setUp() public override {
    super.setUp();
    positionManagerGate = new PositionManagerGate(address(accessManager));
    limitGate = new EmaBorrowLimitGate(address(accessManager), address(positionManagerGate));
    target = _deploySpokeWithGate(address(limitGate));

    // seed the market with 100e6 drawn before the limit is configured
    SpokeActions.supplyCollateral({
      spoke: target,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 10_000e6,
      onBehalfOf: alice
    });
    _borrow(alice, alice, 100e6);
  }

  function test_disabledByDefault() public {
    _borrow(alice, alice, 1_000e6);
  }

  function test_minHeadroom() public {
    _configure(10_00, 50e6);
    assertEq(limitGate.getDrawLimit(address(target), usdxReserveId), 150e6);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    _borrow(alice, alice, 50e6 + 1);
    _borrow(alice, alice, 50e6);
  }

  /// @dev Splitting a burst across calls in one block does not move the EMA, so it buys nothing.
  function test_sameBlockBurstSharesAllowance() public {
    _configure(10_00, 0);
    _borrow(alice, alice, 5e6);
    _borrow(alice, alice, 5e6);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    _borrow(alice, alice, 1);
  }

  /// @dev After one time constant the EMA closes half the gap, so the limit recovers.
  function test_limitRecoversOverTime() public {
    _configure(10_00, 0);
    _borrow(alice, alice, 10e6);

    skip(TAU);
    uint256 drawn = _drawn();
    uint256 expectedEma = 100e6 + (drawn - 100e6) / 2;
    uint256 limit = limitGate.getDrawLimit(address(target), usdxReserveId);
    assertEq(limit, expectedEma + (expectedEma * 10_00) / 100_00);

    _borrow(alice, alice, limit - drawn);
    vm.expectRevert(ISpoke.Unauthorized.selector);
    _borrow(alice, alice, 1);
  }

  /// @dev Drawn stays maxGrowth above an EMA compounding at ~maxGrowth / tau: 2 days allow ~1.1 * e^0.2.
  function test_sustainedFlowIsRateLimited() public {
    _configure(10_00, 0);

    uint256 start = _drawn();
    for (uint256 i = 0; i < 48; ++i) {
      skip(1 hours);
      uint256 headroom = limitGate.getDrawLimit(address(target), usdxReserveId) - _drawn();
      if (headroom > 0) _borrow(alice, alice, headroom);
    }

    assertLt(_drawn(), (start * 135_00) / 100_00);
    assertGt(_drawn(), (start * 125_00) / 100_00);
  }

  function test_repayIsNeverLimited() public {
    _configure(0, 0);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    _borrow(alice, alice, 1);

    vm.prank(alice);
    target.repay(usdxReserveId, 50e6, alice);
    assertLt(_drawn(), 100e6);
  }

  function test_positionManagersAreAuthorizedAndLimited() public {
    _configure(10_00, 0);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    _borrow(bob, alice, 1e6);

    vm.prank(ADMIN);
    positionManagerGate.updatePositionManager(address(target), bob, true);
    vm.prank(alice);
    positionManagerGate.setUserPositionManager(address(target), bob, true);

    _borrow(bob, alice, 1e6);
    vm.expectRevert(ISpoke.Unauthorized.selector);
    _borrow(bob, alice, 10e6);
  }

  function _configure(uint16 maxGrowth, uint128 minHeadroom) internal {
    vm.prank(ADMIN);
    limitGate.setConfig(
      address(target),
      usdxReserveId,
      EmaBorrowLimitGate.Config({tau: TAU, maxGrowth: maxGrowth, minHeadroom: minHeadroom})
    );
  }

  function _borrow(address caller, address onBehalfOf, uint256 amount) internal {
    vm.prank(caller);
    target.borrow(usdxReserveId, amount, onBehalfOf);
  }

  function _drawn() internal view returns (uint256 drawn) {
    (drawn, ) = hub1.getSpokeOwed(usdxAssetId, address(target));
  }
}
