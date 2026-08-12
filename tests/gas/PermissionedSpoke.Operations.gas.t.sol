// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

/// forge-config: default.isolate = true
contract PermissionedSpokeOperations_Gas_Tests is PermissionedSpokeBase {
  string internal NAMESPACE = 'PermissionedSpoke.Operations';

  function setUp() public virtual override {
    super.setUp();

    // seed borrowable liquidity
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 100_000e6,
      onBehalfOf: bob
    });
  }

  function test_updateGate() public {
    vm.prank(ADMIN);
    PermissionedSpokeInstance(address(spoke)).updateGate(address(gate));
    vm.snapshotGasLastCall(NAMESPACE, 'updateGate: set');
  }

  function test_operations_gateUnset() public {
    _snapshotOperations('gate unset');
  }

  function test_operations_gateSet() public {
    gate.setGated(ISpoke.supply.selector, true);
    gate.setGated(ISpoke.withdraw.selector, true);
    gate.setGated(ISpoke.borrow.selector, true);
    gate.setGated(ISpoke.repay.selector, true);
    gate.setGated(ISpoke.setUsingAsCollateral.selector, true);
    gate.setEligible(alice, true);
    _setGate(address(gate));

    _snapshotOperations('gate set');
  }

  function _snapshotOperations(string memory label) internal {
    vm.startPrank(alice);
    spoke.supply(usdxReserveId, 1000e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('supply: ', label));

    spoke.setUsingAsCollateral(usdxReserveId, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('usingAsCollateral: enable, ', label));

    spoke.borrow(usdxReserveId, 100e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('borrow: ', label));

    skip(100);

    spoke.repay(usdxReserveId, 50e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('repay: partial, ', label));

    spoke.withdraw(usdxReserveId, 100e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('withdraw: partial, ', label));
    vm.stopPrank();
  }
}
