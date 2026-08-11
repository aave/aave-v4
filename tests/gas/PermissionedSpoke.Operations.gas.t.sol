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

  function test_updateMandatoryPositionManager() public {
    vm.prank(ADMIN);
    PermissionedSpokeInstance(address(spoke)).updateMandatoryPositionManager(
      address(mandatoryPositionManager)
    );
    vm.snapshotGasLastCall(NAMESPACE, 'updateMandatoryPositionManager: set');
  }

  function test_operations_mandatoryPositionManagerUnset() public {
    _snapshotOperations('mpm unset');
  }

  function test_operations_mandatoryPositionManagerSet() public {
    mandatoryPositionManager.setGated(ISpoke.supply.selector, true);
    mandatoryPositionManager.setGated(ISpoke.withdraw.selector, true);
    mandatoryPositionManager.setGated(ISpoke.borrow.selector, true);
    mandatoryPositionManager.setGated(ISpoke.repay.selector, true);
    mandatoryPositionManager.setGated(ISpoke.setUsingAsCollateral.selector, true);
    mandatoryPositionManager.setEligible(alice, true);
    _setMandatoryPositionManager(address(mandatoryPositionManager));

    _snapshotOperations('mpm set');
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
