// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/permissioned/PermissionedSpoke.Base.t.sol';

import {
  PositionManagerPolicyGate,
  GlobalManagerPolicyGate,
  BorrowAllowlistPolicyGate,
  MockAllowlist
} from 'tests/helpers/mocks/PolicyGates.sol';

/// forge-config: default.isolate = true
contract PermissionedSpokeOperations_Gas_Tests is PermissionedSpokeBase {
  string internal NAMESPACE = 'PermissionedSpoke.Operations';

  /// @dev Same authorization as the standard spoke, routed through the gate.
  function test_operations_positionManagerPolicy() public {
    _snapshotOperations(
      _deployPermissionedSpoke(address(new PositionManagerPolicyGate())),
      'position-manager policy'
    );
  }

  function test_updateUserRiskPremium_positionManagerPolicy() public {
    _snapshotUpdateUserRiskPremium(
      _deployPermissionedSpoke(address(new PositionManagerPolicyGate())),
      'position-manager policy'
    );
  }

  function test_updateUserDynamicConfig_positionManagerPolicy() public {
    _snapshotUpdateUserDynamicConfig(
      _deployPermissionedSpoke(address(new PositionManagerPolicyGate())),
      'position-manager policy'
    );
  }

  function test_liquidationCall_positionManagerPolicy() public {
    _snapshotLiquidationCall(
      _deployPermissionedSpoke(address(new PositionManagerPolicyGate())),
      'position-manager policy'
    );
  }

  /// @dev Horizon-style policy: a fixed global manager may act for any user.
  function test_operations_globalManagerPolicy() public {
    address policy = address(new GlobalManagerPolicyGate(RWA_MANAGER));
    _snapshotOperations(_deployPermissionedSpoke(policy), 'global-manager policy');
  }

  /// @dev EtherFi-style policy: borrowing restricted to an external allowlist.
  function test_operations_borrowAllowlistPolicy() public {
    MockAllowlist allowlist = new MockAllowlist();
    allowlist.setAllowed(alice, true);
    address policy = address(new BorrowAllowlistPolicyGate(allowlist));
    _snapshotOperations(_deployPermissionedSpoke(policy), 'borrow-allowlist policy');
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
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('supply: ', label));

    target.setUsingAsCollateral(usdxReserveId, true, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('usingAsCollateral: enable, ', label));

    target.borrow(usdxReserveId, 100e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('borrow: ', label));

    skip(100);

    target.repay(usdxReserveId, 50e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('repay: partial, ', label));

    target.withdraw(usdxReserveId, 100e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('withdraw: partial, ', label));
    vm.stopPrank();
  }

  function _snapshotUpdateUserRiskPremium(ISpoke target, string memory label) internal {
    SpokeActions.supply({
      spoke: target,
      reserveId: wethReserveId,
      caller: bob,
      amount: 1000e18,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: target,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 2000e6,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: target,
      reserveId: wethReserveId,
      caller: alice,
      amount: 0.25e18,
      onBehalfOf: alice
    });

    skip(100);
    vm.prank(alice);
    target.updateUserRiskPremium(alice);
    vm.snapshotGasLastFrame(
      NAMESPACE,
      string.concat('updateUserRiskPremium: 1 borrow, ', label)
    );
  }

  function _snapshotUpdateUserDynamicConfig(ISpoke target, string memory label) internal {
    vm.prank(alice);
    target.setUsingAsCollateral(usdxReserveId, true, alice);
    _updateLiquidationFee(target, usdxReserveId, 10_00);
    vm.prank(alice);
    target.updateUserDynamicConfig(alice);
    vm.snapshotGasLastFrame(
      NAMESPACE,
      string.concat('updateUserDynamicConfig: 1 collateral, ', label)
    );
  }

  function _snapshotLiquidationCall(ISpoke target, string memory label) internal {
    _updateMaxLiquidationBonus(target, usdxReserveId, 105_00);
    _updateLiquidationFee(target, usdxReserveId, 10_00);
    SpokeActions.supply({
      spoke: target,
      reserveId: wethReserveId,
      caller: bob,
      amount: 1000e18,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: target,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 1_000_000e6,
      onBehalfOf: alice
    });
    _borrowToBeLiquidatableWithPriceChange({
      spoke: target,
      user: alice,
      reserveId: wethReserveId,
      collateralReserveId: usdxReserveId,
      desiredHf: 1.05e18,
      pricePercentage: 85_00
    });
    skip(100);
    SpokeActions.liquidationCall({
      spoke: target,
      collateralReserveId: usdxReserveId,
      debtReserveId: wethReserveId,
      user: alice,
      debtToCover: type(uint256).max,
      receiveShares: false,
      caller: bob
    });
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('liquidationCall: full, ', label));
  }
}
