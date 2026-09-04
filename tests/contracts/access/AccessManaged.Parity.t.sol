// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract LegacyBooleanAuthority {
  function canCall(address, address, bytes4) external pure returns (bool) {
    return true;
  }
}

contract AccessManagedParityTest is Base {
  function _executeScheduledDirectly(address target, bytes memory data) internal {
    IAccessManager manager = IAccessManager(IAccessManaged(target).authority());
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = bytes4(data);
    vm.startPrank(ADMIN);
    manager.setTargetFunctionRole(target, selectors, 777);
    manager.grantRole(777, alice, 100);
    vm.stopPrank();
    vm.prank(alice);
    (bytes32 operationId, ) = manager.schedule(target, data, 0);
    vm.warp(block.timestamp + 100);
    vm.prank(alice);
    (bool success, ) = target.call(data);
    assertTrue(success, 'matured operation must execute through the managed target');
    assertEq(manager.getSchedule(operationId), 0, 'schedule consumed');
    assertEq(IAccessManaged(target).isConsumingScheduledOp(), bytes4(0), 'marker reset');
  }

  function test_compat_directScheduledHubCall() public {
    _executeScheduledDirectly(address(hub1), abi.encodeCall(IHub.mintFeeShares, (daiAssetId)));
  }

  function test_compat_directScheduledSpokeCall() public {
    _executeScheduledDirectly(
      address(spoke1),
      abi.encodeCall(ISpoke.updatePositionManager, (bob, true))
    );
    assertTrue(spoke1.isPositionManagerActive(bob));
  }

  function test_compat_legacyBooleanAuthority() public {
    address authority = address(new LegacyBooleanAuthority());
    vm.prank(hub1.authority());
    hub1.setAuthority(authority);
    assertEq(hub1.mintFeeShares(daiAssetId), 0);
  }

  function test_compat_replacementAuthorityRequiresCode() public {
    address authority = hub1.authority();
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedInvalidAuthority.selector, bob)
    );
    vm.prank(authority);
    hub1.setAuthority(bob);
  }
}
