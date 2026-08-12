// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

contract PermissionedSpokeTest is PermissionedSpokeBase {
  function test_defaultBehavior_withoutGate() public {
    _supplyCollateralAndBorrow(alice, 100e6);

    // an unapproved caller still cannot act on behalf of alice
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 1e6,
      onBehalfOf: alice
    });
  }

  function test_updateGate() public {
    vm.expectEmit(address(spoke));
    emit IPermissionedSpoke.UpdateGate(address(gate));

    vm.prank(ADMIN);
    PermissionedSpokeInstance(address(spoke)).updateGate(address(gate));

    assertEq(PermissionedSpokeInstance(address(spoke)).getGate(), address(gate));
  }

  function test_updateGate_removal() public {
    _setGate(address(gate));
    _setGate(address(0));

    assertEq(PermissionedSpokeInstance(address(spoke)).getGate(), address(0));

    // default authorization is restored
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });
  }

  function test_updateGate_revertsIfUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    PermissionedSpokeInstance(address(spoke)).updateGate(address(gate));
  }

  function test_permissionedBorrow() public {
    gate.setGated(ISpoke.borrow.selector, true);
    _setGate(address(gate));

    // supply is not gated for ineligible users
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 200e6,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    gate.setEligible(alice, true);
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    assertEq(spoke.getUserTotalDebt(usdxReserveId, alice), 100e6);
  }

  function test_defaultApprovalsPreservedViaCallback() public {
    _setGate(address(gate));

    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    // bob is not an approved position manager for alice
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 50e6,
      onBehalfOf: alice
    });

    // approving bob as position manager makes the call pass through the callback
    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(bob, true);
    vm.prank(alice);
    spoke.setUserPositionManager(bob, true);

    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 50e6,
      onBehalfOf: alice
    });

    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, alice), 50e6);
  }

  /// @dev Horizon-style forced transfer: the RWA manager moves alice's position to bob by
  /// withdrawing on her behalf and re-supplying to bob, without any user approval.
  function test_forcedTransfer_viaGlobalManager() public {
    gate.setGlobalManager(RWA_MANAGER, true);
    _setGate(address(gate));

    uint256 amount = 100e6;
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    uint256 balanceBefore = tokenList.usdx.balanceOf(RWA_MANAGER);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });
    assertEq(tokenList.usdx.balanceOf(RWA_MANAGER), balanceBefore + amount);

    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: amount,
      onBehalfOf: bob
    });

    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, alice), 0);
    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, bob), amount);
  }

  function test_forcedWithdraw_stillValidatesHealthFactor() public {
    gate.setGlobalManager(RWA_MANAGER, true);
    _setGate(address(gate));

    _supplyCollateralAndBorrow(alice, 100e6);

    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: 100e6,
      onBehalfOf: alice
    });
  }

  function test_liquidationCallUnaffected() public {
    _setGate(address(gate));

    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 10_000e6,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: wethReserveId,
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });
    _borrowToBeLiquidatableWithPriceChange({
      spoke: spoke,
      user: alice,
      reserveId: usdxReserveId,
      collateralReserveId: wethReserveId,
      desiredHf: 1.01e18,
      pricePercentage: 90_00
    });

    uint256 debtBefore = spoke.getUserTotalDebt(usdxReserveId, alice);

    // bob is neither eligible nor a global manager; liquidations are not gated
    SpokeActions.liquidationCall({
      spoke: spoke,
      collateralReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      user: alice,
      debtToCover: type(uint256).max,
      receiveShares: false,
      caller: bob
    });

    assertLt(spoke.getUserTotalDebt(usdxReserveId, alice), debtBefore, 'liquidation executed');
  }

  function test_cannotBeBypassedWithMulticall() public {
    gate.setGated(ISpoke.borrow.selector, true);
    _setGate(address(gate));

    bytes[] memory calls = new bytes[](1);
    calls[0] = abi.encodeCall(ISpoke.borrow, (usdxReserveId, 100e6, alice));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    spoke.multicall(calls);
  }
}
