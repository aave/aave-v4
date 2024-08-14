// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  bytes32 constant DEFAULT_ADMIN_ROLE =
    0x0000000000000000000000000000000000000000000000000000000000000000;
  address UNALLOWED = makeAddr('UNALLOWED');
  address USER2 = makeAddr('USER2');
  address USER3 = makeAddr('USER3');

  function setUp() public override {
    super.setUp();

    vm.prank(USER1);
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

  function testSetup() public {
    assertEq(hub.hasRole(hub.RESERVE_CONTROLLER(), USER1), true);
    assertEq(hub.hasRole(DEFAULT_ADMIN_ROLE, ADMIN), true);
  }

  function testAddReserveAccessRevert() public {
    vm.prank(UNALLOWED);
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

  function testAddReserveAccess() public {
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

  function testRoleAdmin() public {
    // Set RESERVE_CONTROLLER_ADMIN as USER1
    vm.startPrank(ADMIN);
    hub.setRoleAdmin(hub.RESERVE_CONTROLLER(), hub.RESERVE_CONTROLLER_ADMIN());
    hub.grantRole(hub.RESERVE_CONTROLLER_ADMIN(), USER1);
    vm.stopPrank();

    // USER1 can grant RESERVE_CONTROLLER role
    vm.startPrank(USER1);
    hub.grantRole(hub.RESERVE_CONTROLLER(), USER2);

    // USER1 CANNOT grant POOL_MANAGER role
    bytes32 POOL_MANAGER = hub.POOL_MANAGER();
    vm.expectRevert();
    hub.grantRole(POOL_MANAGER, USER2);
    vm.stopPrank();
  }

  function testRevokeRoleAdmin() public {
    // Set RESERVE_CONTROLLER_ADMIN as USER1
    vm.startPrank(ADMIN);
    hub.setRoleAdmin(hub.RESERVE_CONTROLLER(), hub.RESERVE_CONTROLLER_ADMIN());
    hub.grantRole(hub.RESERVE_CONTROLLER_ADMIN(), USER1);
    vm.stopPrank();

    // USER1 can grant RESERVE_CONTROLLER role
    vm.startPrank(USER1);
    hub.grantRole(hub.RESERVE_CONTROLLER(), USER2);
    vm.stopPrank();

    // Revoke RESERVE_CONTROLLER_ADMIN role from USER1
    vm.startPrank(ADMIN);
    hub.revokeRole(hub.RESERVE_CONTROLLER_ADMIN(), USER1);
    vm.stopPrank();

    // Now USER1 cannot grant RESERVE_CONTROLLER role
    bytes32 RESERVE_CONTROLLER = hub.RESERVE_CONTROLLER();
    vm.prank(USER1);
    vm.expectRevert();
    hub.grantRole(RESERVE_CONTROLLER, USER3);
  }
}
