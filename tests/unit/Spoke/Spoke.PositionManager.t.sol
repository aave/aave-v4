// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokePositionManagerTest is SpokeBase {
  function test_setPositionManager(bytes32) public {
    vm.setArbitraryStorage(address(spoke1));

    address user = vm.randomAddress();
    address positionManager = vm.randomAddress();
    bool approve = vm.randomBool();

    // if position manager not active, then user should not be able to approve, else action should be idempotent
    if (!spoke1.isPositionManagerActive(positionManager) && approve) {
      vm.expectRevert(ISpoke.InactivePositionManager.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.ApprovalForPositionManager(user, positionManager, approve);
    }

    vm.prank(user);
    spoke1.setApprovalForPositionManager(positionManager, approve);
  }
}
