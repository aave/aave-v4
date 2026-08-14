// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

contract PermissionedSpokeTest is PermissionedSpokeBase {
  function test_initialize() public {
    assertEq(PermissionedSpokeInstance(address(spoke)).getGate(), address(gate));

    // the single-argument initializer is disabled
    PermissionedSpokeInstance implementation = new PermissionedSpokeInstance({
      oracle_: address(oracle1),
      maxUserReservesLimit_: DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT
    });
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    new TransparentUpgradeableProxy(
      address(implementation),
      PROXY_ADMIN_OWNER,
      abi.encodeCall(ISpokeInstance.initialize, (address(accessManager)))
    );

    // the gate is required at initialization
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    new TransparentUpgradeableProxy(
      address(implementation),
      PROXY_ADMIN_OWNER,
      abi.encodeWithSignature('initialize(address,address)', address(accessManager), address(0))
    );
  }

  function test_updateGate() public {
    address newGate = address(new MockSpokeGate());

    vm.expectEmit(address(spoke));
    emit IPermissionedSpoke.UpdateGate(newGate);
    vm.prank(ADMIN);
    PermissionedSpokeInstance(address(spoke)).updateGate(newGate);

    assertEq(PermissionedSpokeInstance(address(spoke)).getGate(), newGate);

    // the gate cannot be unset
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    vm.prank(ADMIN);
    PermissionedSpokeInstance(address(spoke)).updateGate(address(0));
  }

  function test_updateGate_revertsIfUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    PermissionedSpokeInstance(address(spoke)).updateGate(address(gate));
  }

  function test_defaultBehaviorViaCallback() public {
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

  function test_permissionedBorrow() public {
    gate.setGated(ISpoke.borrow.selector, true);

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

  function test_approvedPositionManagersPreservedViaCallback() public {
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

    // gate everything; neither alice nor bob are eligible
    gate.setGated(ISpoke.supply.selector, true);
    gate.setGated(ISpoke.withdraw.selector, true);
    gate.setGated(ISpoke.borrow.selector, true);
    gate.setGated(ISpoke.repay.selector, true);
    gate.setGated(ISpoke.setUsingAsCollateral.selector, true);
    gate.setGated(ISpoke.liquidationCall.selector, true);

    uint256 debtBefore = spoke.getUserTotalDebt(usdxReserveId, alice);

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

    bytes[] memory calls = new bytes[](1);
    calls[0] = abi.encodeCall(ISpoke.borrow, (usdxReserveId, 100e6, alice));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    spoke.multicall(calls);
  }
}
