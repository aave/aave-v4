// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  bytes32 constant DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;

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
    address UNALLOWED = makeAddr('UNALLOWED');
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
}
