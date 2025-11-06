// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract RescuableTest is Base {
  RescuableWrapper public rescuable;

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();

    rescuable = new RescuableWrapper(ADMIN);
  }

  function test_constructor() public view {
    assertEq(rescuable.rescueGuardian(), address(ADMIN));
  }

  function test_rescueToken_fuzz(uint256 lostAmount) public {
    lostAmount = bound(lostAmount, 1, 100e18);

    deal(address(tokenList.dai), address(rescuable), lostAmount);

    uint256 prevBalanceThis = tokenList.dai.balanceOf(address(this));

    vm.prank(address(ADMIN));
    rescuable.rescueToken(address(tokenList.dai), address(this), lostAmount);

    assertEq(tokenList.dai.balanceOf(address(this)), prevBalanceThis + lostAmount);
    assertEq(tokenList.dai.balanceOf(address(rescuable)), 0);
  }

  function test_rescueToken_revertsWith_OnlyRescueGuardian() public {
    uint256 lostAmount = 10e18;

    deal(address(tokenList.dai), address(rescuable), lostAmount);

    vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
    vm.prank(bob);
    rescuable.rescueToken(address(tokenList.dai), address(this), lostAmount);
  }

  function test_rescueNative_fuzz(uint256 lostAmount) public {
    lostAmount = bound(lostAmount, 1, 100e18);

    deal(address(rescuable), lostAmount);

    uint256 prevBalanceReceiver = address(ADMIN).balance;

    vm.prank(address(ADMIN));
    rescuable.rescueNative(address(ADMIN), lostAmount);

    assertEq(address(ADMIN).balance, prevBalanceReceiver + lostAmount);
    assertEq(address(rescuable).balance, 0);
    assertEq(tokenList.weth.balanceOf(address(rescuable)), 0);
  }

  function test_rescueNative_revertsWith_OnlyRescueGuardian() public {
    uint256 lostAmount = 10e18;

    deal(address(rescuable), lostAmount);

    vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
    vm.prank(bob);
    rescuable.rescueNative(bob, lostAmount);
  }
}
