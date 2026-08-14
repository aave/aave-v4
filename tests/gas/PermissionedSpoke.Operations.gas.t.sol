// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

import {
  PositionManagerPolicyGate,
  GlobalManagerPolicyGate,
  BorrowAllowlistPolicyGate,
  MockAllowlist
} from 'tests/helpers/mocks/PolicyGates.sol';

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

  /// @dev Same authorization as the standard spoke, routed through the gate.
  function test_operations_positionManagerPolicy() public {
    _setGate(address(new PositionManagerPolicyGate(spoke)));
    _snapshotOperations('position-manager policy');
  }

  /// @dev Horizon-style policy: a fixed global manager may act for any user.
  function test_operations_globalManagerPolicy() public {
    _setGate(address(new GlobalManagerPolicyGate(spoke, RWA_MANAGER)));
    _snapshotOperations('global-manager policy');
  }

  /// @dev EtherFi-style policy: borrowing restricted to an external allowlist.
  function test_operations_borrowAllowlistPolicy() public {
    MockAllowlist allowlist = new MockAllowlist();
    allowlist.setAllowed(alice, true);
    _setGate(address(new BorrowAllowlistPolicyGate(spoke, allowlist)));
    _snapshotOperations('borrow-allowlist policy');
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
