// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  function setUp() public override {
    super.setUp();

    // Add dai
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(0),
        lt: 0,
        lb: 0,
        rf: 0,
        decimals: 18,
        active: true,
        borrowable: false,
        supplyCap: type(uint256).max,
        borrowCap: type(uint256).max
      }),
      address(dai)
    );
  }

  function test_first_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), USER1, amount);

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, 0);
    assertEq(userData.principalBalance, 0);
    assertEq(dai.balanceOf(USER1), amount);
    assertEq(dai.balanceOf(address(hub)), 0);

    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, amount);
    assertEq(userData.principalBalance, amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    // TODO: indexes and IRs init
  }

  function test_fuzz_supply_events(
    uint256 assetId,
    uint256 userInt,
    uint256 amount,
    uint256 onBehalfOfInt
  ) public {
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    userInt = bound(userInt, 1, type(uint160).max);
    onBehalfOfInt = bound(onBehalfOfInt, 1, type(uint160).max);
    amount = bound(amount, 0, type(uint128).max);

    address user = address(uint160(userInt));
    address onBehalfOf = address(uint160(onBehalfOfInt));
    address asset = hub.reservesList(assetId);

    deal(asset, user, amount);

    vm.startPrank(user);
    IERC20(asset).approve(address(hub), amount);

    vm.expectEmit(true, true, true, true, asset);
    emit Transfer(user, address(hub), amount);

    vm.expectEmit(true, true, true, true, address(hub));
    emit Supply(assetId, user, onBehalfOf, amount, 0);

    hub.supply(assetId, amount, onBehalfOf, 0);
    vm.stopPrank();
  }

  function test_withdraw() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), USER1, amount);
    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, amount);
    assertEq(userData.principalBalance, amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    Utils.withdraw(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, 0);
    assertEq(userData.principalBalance, 0);
    assertEq(dai.balanceOf(USER1), amount);
    assertEq(dai.balanceOf(address(hub)), 0);
  }

  function test_fuzz_withdraw_events(
    uint256 assetId,
    uint256 userInt,
    uint256 amount,
    uint256 toInt
  ) public {
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    userInt = bound(userInt, 1, type(uint160).max);
    toInt = bound(toInt, 1, type(uint160).max);

    address user = address(uint160(userInt));
    address to = address(uint160(toInt));
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, user);
    amount = bound(amount, 0, userData.principalBalance);

    address asset = hub.reservesList(assetId);

    // User supply
    deal(asset, user, amount);
    Utils.supply(vm, hub, assetId, user, amount, user);

    vm.expectEmit(true, true, true, true, asset);
    emit Transfer(address(hub), to, amount);

    vm.expectEmit(true, true, true, true, address(hub));
    emit Withdraw(assetId, user, to, amount);

    Utils.withdraw(vm, hub, assetId, user, amount, to);
  }

  function test_withdraw_more_than_supplied_reverts() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), USER1, amount);
    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, amount);
    assertEq(userData.principalBalance, amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    vm.prank(USER1);

    vm.expectRevert(Errors.NOT_AVAILABLE_LIQUIDITY);
    hub.withdraw(assetId, amount + 1, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, amount);
    assertEq(userData.principalBalance, amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);
  }
}
