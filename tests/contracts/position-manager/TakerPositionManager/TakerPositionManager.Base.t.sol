// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {TakerPositionManagerHelpers} from 'tests/helpers/position-manager/taker-position-manager/TakerPositionManagerHelpers.sol';

contract TakerPositionManagerBaseTest is Base, TakerPositionManagerHelpers {
  TakerPositionManager public positionManager;
  SharesAndAmount public returnValues;

  function setUp() public virtual override {
    super.setUp();

    positionManager = new TakerPositionManager(address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function _withdrawPermitData(
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (ITakerPositionManager.WithdrawPermit memory) {
    return _withdrawPermitData(positionManager, spoke1, spender, onBehalfOf, deadline);
  }

  function _approveBorrowData(
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (ITakerPositionManager.BorrowPermit memory) {
    return _approveBorrowData(positionManager, spoke1, spender, onBehalfOf, deadline);
  }
}
