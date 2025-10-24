// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubApproveTest is HubBase {
  function test_approve() public {
    uint256 amount = 1000e18;

    vm.expectEmit(address(hub1));
    emit IHub.ApproveSpoke(alice, address(spoke1), address(tokenList.dai), amount);

    vm.prank(alice);
    hub1.approve(address(spoke1), address(tokenList.dai), amount);

    assertEq(hub1.allowance(alice, address(spoke1), address(tokenList.dai)), amount);
  }
}
