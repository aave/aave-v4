// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

contract PermissionedSpokeTest is PermissionedSpokeBase {
  ISpoke internal pspoke; // frozen users may exit
  ISpoke internal strictSpoke; // frozen users may not exit
  ISpoke internal custodySpoke; // only CUSTODY acts and liquidates

  function setUp() public override {
    super.setUp();
    pspoke = _deployPermissionedSpoke(_gateConfig(true, true));
    strictSpoke = _deployPermissionedSpoke(_gateConfig(true, false));
    custodySpoke = _deployPermissionedSpoke(
      IEligibilityPolicyGate.Config({
        registry: address(0),
        onlyCaller: CUSTODY,
        onlyLiquidator: CUSTODY,
        allowOwnerRepay: true,
        allowFrozenExit: false
      })
    );

    _setStatus(alice, IEligibilityRegistry.Status.ACTIVE);
    _setStatus(bob, IEligibilityRegistry.Status.ACTIVE);

    // liquidity
    _supply(pspoke, P_USDX, bob, 100_000e6, bob);
    _supply(strictSpoke, P_USDX, bob, 100_000e6, bob);
    _approvePositionManager(custodySpoke, bob, CUSTODY);
    _supply(custodySpoke, P_USDX, CUSTODY, 100_000e6, bob);
  }

  // ---------------------------------------------------------------- helpers

  function _supply(
    ISpoke s,
    uint256 reserveId,
    address caller,
    uint256 amount,
    address user
  ) internal {
    SpokeActions.supply({
      spoke: s,
      reserveId: reserveId,
      caller: caller,
      amount: amount,
      onBehalfOf: user
    });
  }

  /// @dev 1 weth collateral (2000 usd) and 1000 usdx debt.
  function _openPosition(ISpoke s, address caller, address user) internal {
    SpokeActions.supplyCollateral({
      spoke: s,
      reserveId: P_WETH,
      caller: caller,
      amount: 1e18,
      onBehalfOf: user
    });
    SpokeActions.borrow({
      spoke: s,
      reserveId: P_USDX,
      caller: caller,
      amount: 1000e6,
      onBehalfOf: user
    });
  }

  function _expectUnauthorized() internal {
    vm.expectRevert(ISpoke.Unauthorized.selector);
  }

  // ---------------------------------------------------------------- status rules

  function test_supply_revertsWith_Unauthorized_userNotOnboarded() public {
    _expectUnauthorized();
    _supply(pspoke, P_USDX, carol, 1e6, carol);
  }

  function test_positionActions_activeUser() public {
    _openPosition(pspoke, alice, alice);
    SpokeActions.repay({
      spoke: pspoke,
      reserveId: P_USDX,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });
    SpokeActions.withdraw({
      spoke: pspoke,
      reserveId: P_WETH,
      caller: alice,
      amount: 0.1e18,
      onBehalfOf: alice
    });
  }

  function test_positionActions_offboardedUser_exitOnly() public {
    _openPosition(pspoke, alice, alice);
    _setStatus(alice, IEligibilityRegistry.Status.OFFBOARDED);
    _checkExitOnly(pspoke, alice, true);
  }

  function test_positionActions_expiredKyc_exitOnly() public {
    _openPosition(pspoke, alice, alice);
    _setStatus(alice, IEligibilityRegistry.Status.ACTIVE, uint40(block.timestamp + 1));
    skip(2);
    assertEq(uint8(registry.getStatus(alice)), uint8(IEligibilityRegistry.Status.OFFBOARDED));
    _checkExitOnly(pspoke, alice, true);
  }

  function test_positionActions_frozenUser_exitPerSpoke() public {
    _openPosition(pspoke, alice, alice);
    _openPosition(strictSpoke, alice, alice);
    _setStatus(alice, IEligibilityRegistry.Status.FROZEN);
    _checkExitOnly(pspoke, alice, true);
    _checkExitOnly(strictSpoke, alice, false);
  }

  /// @dev supply, borrow and enable collateral denied; owner repay allowed; withdraw and disable
  /// collateral per `canExit`.
  function _checkExitOnly(ISpoke s, address user, bool canExit) internal {
    _expectUnauthorized();
    _supply(s, P_USDX, user, 1e6, user);
    _expectUnauthorized();
    SpokeActions.borrow({spoke: s, reserveId: P_USDX, caller: user, amount: 1e6, onBehalfOf: user});
    _expectUnauthorized();
    SpokeActions.setUsingAsCollateral({
      spoke: s,
      reserveId: P_DAI,
      caller: user,
      usingAsCollateral: true,
      onBehalfOf: user
    });

    SpokeActions.repay({
      spoke: s,
      reserveId: P_USDX,
      caller: user,
      amount: UINT256_MAX,
      onBehalfOf: user
    });

    if (!canExit) _expectUnauthorized();
    SpokeActions.withdraw({
      spoke: s,
      reserveId: P_WETH,
      caller: user,
      amount: 0.1e18,
      onBehalfOf: user
    });
    if (!canExit) _expectUnauthorized();
    SpokeActions.setUsingAsCollateral({
      spoke: s,
      reserveId: P_WETH,
      caller: user,
      usingAsCollateral: false,
      onBehalfOf: user
    });
  }

  function test_updateUserRiskPremium_frozenUser() public {
    _openPosition(strictSpoke, alice, alice);
    _setStatus(alice, IEligibilityRegistry.Status.FROZEN);
    vm.prank(alice);
    strictSpoke.updateUserRiskPremium(alice);
  }

  // ---------------------------------------------------------------- position managers

  function test_supply_onBehalfOf_positionManagerMustBeActive() public {
    _approvePositionManager(pspoke, alice, POSITION_MANAGER);
    _expectUnauthorized();
    _supply(pspoke, P_USDX, POSITION_MANAGER, 1e6, alice);

    _setStatus(POSITION_MANAGER, IEligibilityRegistry.Status.ACTIVE);
    _supply(pspoke, P_USDX, POSITION_MANAGER, 1e6, alice);
  }

  function test_repay_onBehalfOf_frozenUser() public {
    _openPosition(strictSpoke, alice, alice);
    _approvePositionManager(strictSpoke, alice, POSITION_MANAGER);
    _setStatus(POSITION_MANAGER, IEligibilityRegistry.Status.ACTIVE);
    _setStatus(alice, IEligibilityRegistry.Status.FROZEN);
    SpokeActions.repay({
      spoke: strictSpoke,
      reserveId: P_USDX,
      caller: POSITION_MANAGER,
      amount: 100e6,
      onBehalfOf: alice
    });
  }

  function test_positionActions_revertsWith_Unauthorized_unapprovedCaller() public {
    _openPosition(pspoke, alice, alice);
    _expectUnauthorized();
    SpokeActions.withdraw({
      spoke: pspoke,
      reserveId: P_WETH,
      caller: bob,
      amount: 0.1e18,
      onBehalfOf: alice
    });
    _expectUnauthorized();
    SpokeActions.repay({
      spoke: pspoke,
      reserveId: P_USDX,
      caller: bob,
      amount: 1e6,
      onBehalfOf: alice
    });
  }

  // ---------------------------------------------------------------- reserve managers

  function test_withdraw_reserveManager_frozenUser() public {
    _openPosition(strictSpoke, alice, alice);
    _setReserveManager(strictSpoke, P_WETH, RESERVE_MANAGER, AuthKind.ALL_ACTIONS);
    _setReserveManager(strictSpoke, P_USDX, RESERVE_MANAGER, AuthKind.ALL_ACTIONS);
    _setStatus(RESERVE_MANAGER, IEligibilityRegistry.Status.ACTIVE);
    _setStatus(alice, IEligibilityRegistry.Status.FROZEN);

    SpokeActions.repay({
      spoke: strictSpoke,
      reserveId: P_USDX,
      caller: RESERVE_MANAGER,
      amount: 1000e6,
      onBehalfOf: alice
    });
    uint256 balanceBefore = tokenList.weth.balanceOf(RESERVE_MANAGER);
    SpokeActions.withdraw({
      spoke: strictSpoke,
      reserveId: P_WETH,
      caller: RESERVE_MANAGER,
      amount: 0.5e18,
      onBehalfOf: alice
    });
    assertEq(tokenList.weth.balanceOf(RESERVE_MANAGER), balanceBefore + 0.5e18);
  }

  function test_borrow_revertsWith_Unauthorized_reserveManager() public {
    _openPosition(pspoke, alice, alice);
    _setReserveManager(pspoke, P_USDX, RESERVE_MANAGER, AuthKind.ALL_ACTIONS);
    _setStatus(RESERVE_MANAGER, IEligibilityRegistry.Status.ACTIVE);
    _expectUnauthorized();
    SpokeActions.borrow({
      spoke: pspoke,
      reserveId: P_USDX,
      caller: RESERVE_MANAGER,
      amount: 1e6,
      onBehalfOf: alice
    });
  }

  function test_repay_reserveManager_scopedToReserveAndSpoke() public {
    _openPosition(pspoke, alice, alice);
    _openPosition(strictSpoke, alice, alice);
    _setReserveManager(pspoke, P_USDX, RESERVE_MANAGER, AuthKind.ALL_ACTIONS);
    _setStatus(RESERVE_MANAGER, IEligibilityRegistry.Status.ACTIVE);

    // other reserve
    _expectUnauthorized();
    SpokeActions.withdraw({
      spoke: pspoke,
      reserveId: P_WETH,
      caller: RESERVE_MANAGER,
      amount: 0.1e18,
      onBehalfOf: alice
    });
    // other spoke
    _expectUnauthorized();
    SpokeActions.repay({
      spoke: strictSpoke,
      reserveId: P_USDX,
      caller: RESERVE_MANAGER,
      amount: 1e6,
      onBehalfOf: alice
    });
    // its reserve
    SpokeActions.repay({
      spoke: pspoke,
      reserveId: P_USDX,
      caller: RESERVE_MANAGER,
      amount: 1e6,
      onBehalfOf: alice
    });
  }

  function test_repay_reserveManager_mustBeActiveAndGranted() public {
    _openPosition(pspoke, alice, alice);
    _setReserveManager(pspoke, P_USDX, RESERVE_MANAGER, AuthKind.ALL_ACTIONS);
    _expectUnauthorized();
    SpokeActions.repay({
      spoke: pspoke,
      reserveId: P_USDX,
      caller: RESERVE_MANAGER,
      amount: 1e6,
      onBehalfOf: alice
    });

    _setStatus(RESERVE_MANAGER, IEligibilityRegistry.Status.ACTIVE);
    SpokeActions.repay({
      spoke: pspoke,
      reserveId: P_USDX,
      caller: RESERVE_MANAGER,
      amount: 1e6,
      onBehalfOf: alice
    });

    _setReserveManager(pspoke, P_USDX, RESERVE_MANAGER, 0);
    _expectUnauthorized();
    SpokeActions.repay({
      spoke: pspoke,
      reserveId: P_USDX,
      caller: RESERVE_MANAGER,
      amount: 1e6,
      onBehalfOf: alice
    });
  }

  function test_supply_revertsWith_Unauthorized_reserveManagerActionNotGranted() public {
    _openPosition(pspoke, alice, alice);
    _setReserveManager(pspoke, P_USDX, RESERVE_MANAGER, AuthKind.ACTION_REPAY);
    _setStatus(RESERVE_MANAGER, IEligibilityRegistry.Status.ACTIVE);

    SpokeActions.repay({
      spoke: pspoke,
      reserveId: P_USDX,
      caller: RESERVE_MANAGER,
      amount: 1e6,
      onBehalfOf: alice
    });
    _expectUnauthorized();
    _supply(pspoke, P_USDX, RESERVE_MANAGER, 1e6, alice);
  }

  // ---------------------------------------------------------------- liquidation

  function _makeLiquidatable(ISpoke s, address caller, address user) internal {
    _openPosition(s, caller, user);
    SpokeActions.borrow({
      spoke: s,
      reserveId: P_USDX,
      caller: caller,
      amount: 500e6,
      onBehalfOf: user
    });
    _mockReservePrice(s, P_WETH, 1500e8);
    assertLt(s.getUserAccountData(user).healthFactor, 1e18);
  }

  function _liquidate(ISpoke s, address user, address liquidator, bool receiveShares) internal {
    SpokeActions.liquidationCall({
      spoke: s,
      collateralReserveId: P_WETH,
      debtReserveId: P_USDX,
      user: user,
      debtToCover: 100e6,
      receiveShares: receiveShares,
      caller: liquidator
    });
  }

  function test_liquidationCall_frozenUser_openToAnyLiquidator() public {
    _makeLiquidatable(pspoke, alice, alice);
    _setStatus(alice, IEligibilityRegistry.Status.FROZEN);
    // LIQUIDATOR has no status
    _liquidate(pspoke, alice, LIQUIDATOR, false);
  }

  function test_liquidationCall_receiveShares_liquidatorMustBeActive() public {
    _makeLiquidatable(pspoke, alice, alice);
    _expectUnauthorized();
    _liquidate(pspoke, alice, LIQUIDATOR, true);

    _setStatus(LIQUIDATOR, IEligibilityRegistry.Status.ACTIVE);
    _liquidate(pspoke, alice, LIQUIDATOR, true);
  }

  // ---------------------------------------------------------------- custody (only caller)

  function test_supply_revertsWith_Unauthorized_notOnlyCaller() public {
    _expectUnauthorized();
    _supply(custodySpoke, P_USDX, bob, 1e6, bob);
    _approvePositionManager(custodySpoke, alice, CUSTODY);
    _openPosition(custodySpoke, CUSTODY, alice);
  }

  function test_repay_onlyCaller_ownerRepayAllowed() public {
    _approvePositionManager(custodySpoke, alice, CUSTODY);
    _openPosition(custodySpoke, CUSTODY, alice);
    SpokeActions.repay({
      spoke: custodySpoke,
      reserveId: P_USDX,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });
    _expectUnauthorized();
    SpokeActions.withdraw({
      spoke: custodySpoke,
      reserveId: P_WETH,
      caller: alice,
      amount: 0.1e18,
      onBehalfOf: alice
    });
  }

  function test_liquidationCall_revertsWith_Unauthorized_notOnlyLiquidator() public {
    _approvePositionManager(custodySpoke, alice, CUSTODY);
    _makeLiquidatable(custodySpoke, CUSTODY, alice);
    _expectUnauthorized();
    _liquidate(custodySpoke, alice, LIQUIDATOR, false);
    _expectUnauthorized();
    _liquidate(custodySpoke, alice, LIQUIDATOR, true);
    _liquidate(custodySpoke, alice, CUSTODY, true);
  }

  // ---------------------------------------------------------------- spoke

  function test_POLICY_GATE() public view {
    address gate = IPermissionedSpoke(address(pspoke)).POLICY_GATE();
    assertEq(address(IEligibilityPolicyGate(gate).REGISTRY()), address(registry));
    assertTrue(IEligibilityPolicyGate(gate).ALLOW_FROZEN_EXIT());
  }

  function test_multicall_revertsWith_Unauthorized_notOnboarded() public {
    bytes[] memory calls = new bytes[](1);
    calls[0] = abi.encodeCall(ISpoke.supply, (P_USDX, 1e6, carol));
    _expectUnauthorized();
    vm.prank(carol);
    pspoke.multicall(calls);
  }
}
