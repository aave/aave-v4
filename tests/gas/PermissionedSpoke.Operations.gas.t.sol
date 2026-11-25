// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

/// @dev Same actions on a canonical spoke and on a permissioned spoke with a registry, both with
/// the same reserves.
/// forge-config: default.isolate = true
contract PermissionedSpokeOperations_Gas_Tests is PermissionedSpokeBase {
  string internal NAMESPACE = 'PermissionedSpoke.Operations';
  ISpoke internal canonical;
  ISpoke internal permissioned;

  function setUp() public override {
    super.setUp();
    canonical = _deployCanonicalSpoke();
    permissioned = _deployPermissionedSpoke(_gateConfig(true, true));
    address[4] memory active = [alice, bob, POSITION_MANAGER, RESERVE_MANAGER];
    for (uint256 i; i < active.length; ++i) {
      _setStatus(active[i], IEligibilityRegistry.Status.ACTIVE);
    }
    _setReserveManager(permissioned, P_USDX, RESERVE_MANAGER, AuthKind.ALL_ACTIONS);
    ISpoke[2] memory spokes = [canonical, permissioned];
    for (uint256 i; i < spokes.length; ++i) {
      vm.prank(bob);
      spokes[i].supply(P_USDX, 100_000e6, bob);
      _approvePositionManager(spokes[i], alice, POSITION_MANAGER);
    }
  }

  function test_ownerActions_canonical() public {
    _ownerActions(canonical, 'canonical');
  }

  function test_ownerActions_permissioned() public {
    _ownerActions(permissioned, 'permissioned');
  }

  function test_positionManagerActions_canonical() public {
    _positionManagerActions(canonical, 'canonical');
  }

  function test_positionManagerActions_permissioned() public {
    _positionManagerActions(permissioned, 'permissioned');
  }

  function test_repay_reserveManager() public {
    _openPosition(permissioned);
    vm.prank(RESERVE_MANAGER);
    permissioned.repay(P_USDX, 100e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, 'repay: reserve manager, permissioned');
  }

  function test_liquidation_canonical() public {
    _liquidation(canonical, 'canonical');
  }

  function test_liquidation_permissioned() public {
    _liquidation(permissioned, 'permissioned');
  }

  function _ownerActions(ISpoke spoke, string memory kind) internal {
    vm.startPrank(alice);
    spoke.supply(P_WETH, 1e18, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('supply: owner, ', kind));
    spoke.setUsingAsCollateral(P_WETH, true, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('usingAsCollateral: owner, enable, ', kind));
    spoke.borrow(P_USDX, 500e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('borrow: owner, ', kind));
    spoke.repay(P_USDX, 100e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('repay: owner, partial, ', kind));
    spoke.withdraw(P_WETH, 0.1e18, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('withdraw: owner, partial, ', kind));
    vm.stopPrank();
  }

  function _positionManagerActions(ISpoke spoke, string memory kind) internal {
    vm.startPrank(POSITION_MANAGER);
    spoke.supply(P_WETH, 1e18, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('supply: position manager, ', kind));
    spoke.setUsingAsCollateral(P_WETH, true, alice);
    spoke.borrow(P_USDX, 500e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('borrow: position manager, ', kind));
    spoke.repay(P_USDX, 100e6, alice);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('repay: position manager, partial, ', kind));
    vm.stopPrank();
  }

  function _liquidation(ISpoke spoke, string memory kind) internal {
    _openPosition(spoke);
    vm.prank(alice);
    spoke.borrow(P_USDX, 1000e6, alice);
    _mockReservePrice(spoke, P_WETH, 1500e8);
    vm.prank(LIQUIDATOR);
    spoke.liquidationCall(P_WETH, P_USDX, alice, 100e6, false);
    vm.snapshotGasLastFrame(NAMESPACE, string.concat('liquidationCall: partial, ', kind));
  }

  function _openPosition(ISpoke spoke) internal {
    vm.startPrank(alice);
    spoke.supply(P_WETH, 1e18, alice);
    spoke.setUsingAsCollateral(P_WETH, true, alice);
    spoke.borrow(P_USDX, 500e6, alice);
    vm.stopPrank();
  }
}
