// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';
import {MockSpokeGate} from 'tests/helpers/mocks/MockSpokeGate.sol';

contract SpokeGateTest is Base {
  MockSpokeGate internal gate;

  function setUp() public virtual override {
    super.setUp();
    gate = new MockSpokeGate();
  }

  function test_updateGate() public {
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateGate(address(gate));

    vm.prank(SPOKE_ADMIN);
    spoke1.updateGate(address(gate));

    assertEq(spoke1.getGate(), address(gate));
  }

  function test_updateGate_removesGate() public {
    _setGate(address(gate));

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateGate(address(0));

    vm.prank(SPOKE_ADMIN);
    spoke1.updateGate(address(0));

    assertEq(spoke1.getGate(), address(0));
  }

  function test_updateGate_revertsIfUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spoke1.updateGate(address(gate));
  }

  function test_updateGate_revertsIfNotContract() public {
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateGate(makeAddr('EOA_GATE'));
  }

  function test_gate_blocksActionsForIneligibleUser() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    _gateAllActions();
    _setGate(address(gate));

    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      usingAsCollateral: true,
      onBehalfOf: alice
    });
  }

  function test_gate_allowsActionsForEligibleUser() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    _gateAllActions();
    _setGate(address(gate));
    gate.setEligible(alice, true);

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
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserTotalDebt(reserveId, alice), 0);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), amount);
  }

  function test_gate_isSelectorScoped() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    gate.setGated(ISpoke.borrow.selector, true);
    _setGate(address(gate));

    // alice is not eligible, but only borrow is gated
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount / 2,
      onBehalfOf: alice
    });
  }

  function test_gate_checksOnBehalfOfForPositionManagerCalls() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    gate.setGated(ISpoke.borrow.selector, true);
    _setGate(address(gate));

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount * 2,
      onBehalfOf: alice
    });

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(POSITION_MANAGER, true);
    vm.prank(alice);
    spoke1.setUserPositionManager(POSITION_MANAGER, true);

    // alice not eligible: manager cannot borrow on her behalf
    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    // alice eligible: manager can borrow on her behalf, even though it is not eligible itself
    gate.setEligible(alice, true);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount);
  }

  function test_gate_canLimitActionAmount() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    gate.setGated(ISpoke.borrow.selector, true);
    gate.setEligible(alice, true);
    gate.setMaxActionAmount(amount);
    _setGate(address(gate));

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount * 4,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount + 1,
      onBehalfOf: alice
    });

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });
  }

  function test_gate_doesNotApplyToLiquidationCall() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: bob,
      amount: 10_000e6,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });
    _borrowToBeLiquidatableWithPriceChange({
      spoke: spoke1,
      user: alice,
      reserveId: debtReserveId,
      collateralReserveId: collateralReserveId,
      desiredHf: 1.01e18,
      pricePercentage: 90_00
    });

    // gate everything after the position is set up; neither alice nor bob are eligible
    _gateAllActions();
    gate.setGated(ISpoke.liquidationCall.selector, true);
    _setGate(address(gate));

    uint256 debtBefore = spoke1.getUserTotalDebt(debtReserveId, alice);

    SpokeActions.liquidationCall({
      spoke: spoke1,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      user: alice,
      debtToCover: type(uint256).max,
      receiveShares: false,
      caller: bob
    });

    assertLt(spoke1.getUserTotalDebt(debtReserveId, alice), debtBefore, 'liquidation executed');
  }

  function test_gate_cannotBeBypassedWithMulticall() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    gate.setGated(ISpoke.borrow.selector, true);
    _setGate(address(gate));

    bytes[] memory calls = new bytes[](1);
    calls[0] = abi.encodeCall(ISpoke.borrow, (reserveId, 100e6, alice));

    vm.expectRevert(ISpoke.GateAccessDenied.selector);
    vm.prank(alice);
    spoke1.multicall(calls);
  }

  function _gateAllActions() internal {
    gate.setGated(ISpoke.supply.selector, true);
    gate.setGated(ISpoke.withdraw.selector, true);
    gate.setGated(ISpoke.borrow.selector, true);
    gate.setGated(ISpoke.repay.selector, true);
    gate.setGated(ISpoke.setUsingAsCollateral.selector, true);
  }

  function _setGate(address newGate) internal {
    vm.prank(SPOKE_ADMIN);
    spoke1.updateGate(newGate);
  }
}
