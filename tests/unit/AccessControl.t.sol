// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'src/libraries/Roles.sol';
import 'src/dependencies/solmate/Auth.sol';
import 'tests/BaseTest.t.sol';
import 'src/contracts/AccessManaged.sol';

contract AccessControlTest is BaseTest {
  function setUp() public override {
    super.setUp();

    // Add dai
    vm.prank(ADMIN);
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
    accessManager.setRoleCapability(
      Roles.RESERVE_CONTROLLER,
      address(hub),
      LiquidityHub.addReserve.selector,
      true
    );
    // Grant role to USER1
    accessManager.setUserRole(USER1, Roles.RESERVE_CONTROLLER, true);
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

  function test_change_authority() public {
    // Deploy a new authority contract (say another instance of AccessManaged)
    AccessManaged newAuthority = new AccessManaged(ADMIN);

    // Currently the hub is it's own authority
    assertEq(address(hub.authority()), address(accessManager));

    // Grant user 1 the ability to list an asset
    vm.startPrank(ADMIN);
    accessManager.setRoleCapability(
      Roles.RESERVE_CONTROLLER,
      address(hub),
      LiquidityHub.addReserve.selector,
      true
    );
    accessManager.setUserRole(USER1, Roles.RESERVE_CONTROLLER, true);
    vm.stopPrank();

    // User 1 should be able to call addReserve
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

    // Change the authority of the hub to the new authority
    vm.prank(ADMIN);
    hub.setAuthority(Authority(newAuthority));

    // Verify that the authority has been changed
    assertFalse(address(hub.authority()) == address(accessManager));
    assertEq(address(hub.authority()), address(newAuthority));

    // Now User 1 should not be able to call addReserve anymore
    vm.prank(USER1);
    vm.expectRevert('UNAUTHORIZED');
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

    // User 1 is now given access from the new authority
    vm.startPrank(ADMIN);
    newAuthority.setRoleCapability(
      Roles.RESERVE_CONTROLLER,
      address(hub),
      LiquidityHub.addReserve.selector,
      true
    );
    newAuthority.setUserRole(USER1, Roles.RESERVE_CONTROLLER, true);
    vm.stopPrank();

    // User 1 should now be able to call addReserve again
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
