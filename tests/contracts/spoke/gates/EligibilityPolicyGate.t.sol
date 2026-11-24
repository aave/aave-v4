// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

contract EligibilityPolicyGateTest is PermissionedSpokeBase {
  address internal SPOKE = makeAddr('SPOKE');

  function _gate(
    address registry_,
    address onlyCaller,
    address onlyLiquidator,
    bool allowOwnerRepay
  ) internal returns (EligibilityPolicyGate) {
    return
      new EligibilityPolicyGate(
        IEligibilityPolicyGate.Config({
          registry: registry_,
          onlyCaller: onlyCaller,
          onlyLiquidator: onlyLiquidator,
          allowOwnerRepay: allowOwnerRepay,
          allowFrozenExit: false
        })
      );
  }

  function _repayData(address user) internal pure returns (bytes memory) {
    return abi.encodeCall(ISpoke.repay, (0, 1, user));
  }

  function _liquidationData(bool receiveShares) internal pure returns (bytes memory) {
    return abi.encodeCall(ISpoke.liquidationCall, (0, 1, address(1), 1, receiveShares));
  }

  function test_constructor_revertsWith_InvalidConfig() public {
    vm.expectRevert(IEligibilityPolicyGate.InvalidConfig.selector);
    _gate(address(0), address(0), address(0), true);
  }

  function test_isEligible_ownerRepay() public {
    EligibilityPolicyGate allowed = _gate(address(0), CUSTODY, address(0), true);
    EligibilityPolicyGate blocked = _gate(address(0), CUSTODY, address(0), false);
    assertTrue(allowed.isEligible(alice, alice, _repayData(alice), AuthKind.OWNER));
    assertFalse(blocked.isEligible(alice, alice, _repayData(alice), AuthKind.OWNER));
    // only the owner's own repay is covered
    assertFalse(allowed.isEligible(bob, alice, _repayData(alice), AuthKind.POSITION_MANAGER));
  }

  function test_isEligible_liquidationCall_noRegistry() public {
    EligibilityPolicyGate gate = _gate(address(0), CUSTODY, address(0), true);
    assertTrue(gate.isEligible(LIQUIDATOR, LIQUIDATOR, _liquidationData(false), AuthKind.OWNER));
    assertTrue(gate.isEligible(LIQUIDATOR, LIQUIDATOR, _liquidationData(true), AuthKind.OWNER));
  }

  function test_isEligible_liquidationCall_onlyLiquidator() public {
    EligibilityPolicyGate gate = _gate(address(registry), address(0), CUSTODY, true);
    assertFalse(gate.isEligible(LIQUIDATOR, LIQUIDATOR, _liquidationData(false), AuthKind.OWNER));
    assertTrue(gate.isEligible(CUSTODY, CUSTODY, _liquidationData(true), AuthKind.OWNER));
  }

  function test_getReserveManagerActions_keyedByCallingSpoke() public {
    EligibilityPolicyGate gate = _gate(address(registry), address(0), address(0), true);
    vm.prank(COMPLIANCE);
    registry.updateReserveManager(SPOKE, 3, RESERVE_MANAGER, AuthKind.ACTION_REPAY);

    vm.prank(SPOKE);
    assertEq(gate.getReserveManagerActions(RESERVE_MANAGER, 3), AuthKind.ACTION_REPAY);
    vm.prank(SPOKE);
    assertEq(gate.getReserveManagerActions(RESERVE_MANAGER, 4), 0);
    // another caller
    assertEq(gate.getReserveManagerActions(RESERVE_MANAGER, 3), 0);
  }

  function test_getReserveManagerActions_noRegistry() public {
    EligibilityPolicyGate gate = _gate(address(0), CUSTODY, address(0), true);
    vm.prank(SPOKE);
    assertEq(gate.getReserveManagerActions(RESERVE_MANAGER, 0), 0);
  }
}
