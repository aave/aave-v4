// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();

    // Add dai
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(bm),
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
    vm.warp(block.timestamp + 20);
  }

  function test_first_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), USER1, amount);

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, 0);
    assertEq(reserveData.supplyIndex, WadRayMath.RAY);
    assertEq(reserveData.borrowIndex, WadRayMath.RAY);
    assertEq(reserveData.supplyRate, 0);
    assertEq(reserveData.borrowRate, 0);
    assertEq(userData.principalBalance, 0);
    assertEq(userData.interestBalance, 0);
    assertEq(dai.balanceOf(USER1), amount);
    assertEq(dai.balanceOf(address(hub)), 0);

    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, amount);
    assertEq(reserveData.supplyIndex, WadRayMath.RAY);
    assertEq(reserveData.borrowIndex, WadRayMath.RAY);
    assertEq(reserveData.supplyRate, 0);
    assertEq(reserveData.borrowRate, 0);
    assertEq(userData.principalBalance, amount);
    assertEq(userData.interestBalance, 0);
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

  function test_supply_index_increase() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), USER1, amount);

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, 0);
    assertEq(reserveData.supplyIndex, WadRayMath.RAY);
    assertEq(reserveData.borrowIndex, WadRayMath.RAY);
    assertEq(reserveData.supplyRate, 0);
    assertEq(reserveData.borrowRate, 0);
    assertEq(userData.principalBalance, 0);
    assertEq(userData.interestBalance, 0);
    assertEq(dai.balanceOf(USER1), amount);
    assertEq(dai.balanceOf(address(hub)), 0);

    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, amount);
    assertEq(reserveData.supplyIndex, WadRayMath.RAY);
    assertEq(reserveData.borrowIndex, WadRayMath.RAY);
    assertEq(reserveData.supplyRate, 0);
    assertEq(reserveData.borrowRate, 0);
    assertEq(userData.principalBalance, amount);
    assertEq(userData.interestBalance, 0);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    // Index grows but same block, no interest acc
    uint256 newSupplyRate = 0.1e27; // 10.00%
    uint256 newBorrowRate = 0.2e27; // 20.00%
    vm.mockCall(
      address(bm),
      abi.encodeWithSelector(IBorrowModule.calculateInterestRates.selector),
      abi.encode(newSupplyRate, newBorrowRate)
    );

    userData = hub.getUser(assetId, USER1);
    assertEq(userData.principalBalance, amount);
    assertEq(userData.interestBalance, 0);

    // Time flies, no interest acc
    uint256 elapsedTime = 1e4;
    vm.warp(block.timestamp + elapsedTime);

    userData = hub.getUser(assetId, USER1);
    reserveData = hub.getReserve(assetId);
    assertEq(userData.principalBalance, amount);
    assertEq(userData.interestBalance, 0);
    assertEq(reserveData.supplyIndex, WadRayMath.RAY);

    // state update due to reserve operation
    uint256 newSupplyIndex = reserveData.supplyIndex.rayMul(
      MathUtils.calculateLinearInterest(newSupplyRate, uint40(reserveData.lastUpdateTimestamp))
    );
    uint256 newInterestBalance = (newSupplyIndex - WadRayMath.RAY).rayMul(
      userData.principalBalance
    );

    deal(address(dai), USER2, 1);
    Utils.supply(vm, hub, assetId, USER2, 1, USER2);

    // reserve update
    userData = hub.getUser(assetId, USER1);
    reserveData = hub.getReserve(assetId);
    assertEq(userData.principalBalance, amount);
    assertEq(userData.interestBalance, newInterestBalance);
    assertEq(reserveData.supplyIndex, newSupplyIndex);
    assertEq(reserveData.supplyRate, newSupplyRate);
  }

  /// forge-config: default.fuzz.max-test-rejects = 1
  function test_fuzz_supply_index_increase(
    uint256 assetId,
    uint256 userInt,
    uint256 amount
  ) public {
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    userInt = bound(userInt, 1, type(uint160).max);
    amount = bound(amount, 0, type(uint128).max);

    address user = address(uint160(userInt));

    // initial supply
    deal(hub.reservesList(assetId), user, amount);
    Utils.supply(vm, hub, assetId, user, amount, user);

    uint256 elapsedTimeChange = bound(userInt, 0, 30 days); // [0, 30 days] range
    uint256 supplyRateChange = bound(userInt, 0, 1e27); // [0.00%, 100.00%] range;
    uint256 newSupplyRate = 0;
    uint256 newSupplyIndex = WadRayMath.RAY;
    uint256 newAmount = amount;
    uint256 newInterestBalance;
    LiquidityHub.Reserve memory reserveData;
    LiquidityHub.UserConfig memory userData;

    for (uint256 i = 0; i < 50; i += 1) {
      console2.log(i);
      reserveData = hub.getReserve(assetId);
      userData = hub.getUser(assetId, user);

      // check reserve index and user interest
      assertEq(userData.principalBalance, newAmount, 'user principal balance');
      assertEq(userData.interestBalance, newInterestBalance, 'user interest balance');
      assertEq(reserveData.supplyIndex, newSupplyIndex, 'supply index');
      assertEq(reserveData.supplyRate, newSupplyRate, 'supply rate');

      // rate increases
      newSupplyRate = (supplyRateChange * i) % 2e27; // randomize, 200.00% max
      console2.log('newSupplyRate %e', newSupplyRate);
      vm.mockCall(
        address(bm),
        abi.encodeWithSelector(IBorrowModule.calculateInterestRates.selector),
        abi.encode(newSupplyRate, newSupplyRate) // borrowRate not relevant
      );

      // time flies
      {
        uint256 elapsedTime = (i % 2 == 0 ? elapsedTimeChange : elapsedTimeChange * 2) % 30 days; // randomize, 30 days max
        vm.warp(block.timestamp + elapsedTime);
        console2.log('time', block.timestamp);
      }

      // calculate new index
      newSupplyIndex = reserveData.supplyIndex.rayMul(
        MathUtils.calculateLinearInterest(newSupplyRate, uint40(reserveData.lastUpdateTimestamp))
      );
      newInterestBalance = (newSupplyIndex - WadRayMath.RAY).rayMul(userData.principalBalance);
      console2.log('newSupplyIndex %e', newSupplyIndex);
      console2.log('newInterestBalance %e', newInterestBalance);

      // update reserve state
      deal(hub.reservesList(assetId), USER1, 1);
      Utils.supply(vm, hub, assetId, USER1, 1, USER1);
    }
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
    assertEq(reserveData.supplyIndex, WadRayMath.RAY);
    assertEq(reserveData.borrowIndex, WadRayMath.RAY);
    assertEq(reserveData.supplyRate, 0);
    assertEq(reserveData.borrowRate, 0);
    assertEq(userData.principalBalance, amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    Utils.withdraw(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.virtualBalance, 0);
    assertEq(reserveData.supplyIndex, WadRayMath.RAY);
    assertEq(reserveData.borrowIndex, WadRayMath.RAY);
    assertEq(reserveData.supplyRate, 0);
    assertEq(reserveData.borrowRate, 0);
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
