// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/GateSpokeBase.sol';

import {
  GlobalManagerPolicyGate,
  BorrowAllowlistPolicyGate,
  MockAllowlist
} from 'tests/helpers/mocks/PolicyGates.sol';

/// forge-config: default.isolate = true
contract SpokeGateOperations_Gas_Tests is GateSpokeBase {
  string internal NAMESPACE = 'Spoke.Gate.Operations';

  /// @dev Same authorization as the standard spoke, routed through the gate.
  function test_operations_positionManagerPolicy() public {
    ISpoke target = _deploySpokeWithGate(address(new PositionManagerGate(address(accessManager))));
    _snapshotOperations(target, 'position-manager policy');
  }

  /// @dev Horizon-style policy: a fixed global manager may act for any user.
  function test_operations_globalManagerPolicy() public {
    ISpoke target = _deploySpokeWithGate(address(new GlobalManagerPolicyGate(RWA_MANAGER)));
    _snapshotOperations(target, 'global-manager policy');
  }

  /// @dev EtherFi-style policy: borrowing restricted to an external allowlist.
  function test_operations_borrowAllowlistPolicy() public {
    MockAllowlist allowlist = new MockAllowlist();
    allowlist.setAllowed(alice, true);
    ISpoke target = _deploySpokeWithGate(address(new BorrowAllowlistPolicyGate(allowlist)));
    _snapshotOperations(target, 'borrow-allowlist policy');
  }

  function _snapshotOperations(ISpoke target, string memory label) internal {
    // seed borrowable liquidity
    SpokeActions.supply({
      spoke: target,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 100_000e6,
      onBehalfOf: bob
    });

    vm.startPrank(alice);
    target.supply(usdxReserveId, 1000e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('supply: ', label));

    target.setUsingAsCollateral(usdxReserveId, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('usingAsCollateral: enable, ', label));

    target.borrow(usdxReserveId, 100e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('borrow: ', label));

    skip(100);

    target.repay(usdxReserveId, 50e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('repay: partial, ', label));

    target.withdraw(usdxReserveId, 100e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, string.concat('withdraw: partial, ', label));
    vm.stopPrank();
  }
}
