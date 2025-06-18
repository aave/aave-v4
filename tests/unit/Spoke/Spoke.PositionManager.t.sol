// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokePositionManagerTest is SpokeBase {
  function test_setPositionManager() public {
    vm.setArbitraryStorage(address(spoke1));

    address user = vm.randomAddress();
    address positionManager = vm.randomAddress();

    bool state = spoke1.isPositionManager(user, positionManager);

    vm.expectEmit(address(spoke1));
    emit ISpoke.PositionManagerSet(user, positionManager, state);
    vm.prank(user);
    spoke1.setPositionManager(positionManager, state);

    assertEq(spoke1.isPositionManager(user, positionManager), state);

    vm.expectEmit(address(spoke1));
    emit ISpoke.PositionManagerSet(user, positionManager, !state);
    vm.prank(user);
    spoke1.setPositionManager(positionManager, !state);

    assertEq(spoke1.isPositionManager(user, positionManager), !state);
  }
}
