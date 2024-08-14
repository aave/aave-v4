// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  function setUp() public override {
    super.setUp();

    vm.prank(ADMIN);
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

  function testSupply() public {
    deal(address(dai), USER1, 100e18);
    vm.startPrank(USER1);

    dai.approve(address(hub), 100e18);
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    hub.supply(assetId, 100e18);
  }

  function testAddReserve() public {
    vm.prank(ADMIN);
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
      address(usdc)
    );
  }

  function testAddReserveNotAuthorized() public {
    vm.prank(USER1);
    vm.expectRevert();
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
      address(usdc)
    );
  }

  function testAddReserveGrantAccess() public {
    // Fails before access grant
    vm.prank(USER1);
    vm.expectRevert();
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
      address(usdc)
    );

    vm.startPrank(ADMIN);
    // Get function signature of addReserve
    bytes4 sig = bytes4(0xe71fa26c);
    hub.setRoleCapability(hub.RESERVE_CONTROLLER(), address(hub), sig, true);
    // Grant role to USER1
    hub.setUserRole(USER1, hub.RESERVE_CONTROLLER(), true);
    vm.stopPrank();

    // Succeeds after access grant
    vm.prank(USER1);
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
      address(usdc)
    );
  }
}
