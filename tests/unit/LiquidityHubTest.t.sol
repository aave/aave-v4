// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  bytes32 constant DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000;
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

  function testChangeRiskAccessRevert() public {
    vm.prank(UNALLOWED);
    vm.expectRevert();
    hub.changeRisk();
  }

  function testChangeRiskAccess() public {
    vm.startPrank(ADMIN);
    hub.grantRole(hub.RISK_CONTROLLER(), USER1);
    vm.stopPrank();
    vm.prank(USER1);
    hub.changeRisk();
  }

  function testChangeInterestRateAccessRevert() public {
    vm.prank(UNALLOWED);
    vm.expectRevert();
    hub.changeInterestRate();
  }

  function testChangeInterestRateAccess() public {
    vm.startPrank(ADMIN);
    hub.grantRole(hub.INTEREST_RATE_CONTROLLER(), USER1);
    vm.stopPrank();
    vm.prank(USER1);
    hub.changeInterestRate();
  }

  function testRevokeRole() public {
    vm.startPrank(ADMIN);
    hub.grantRole(hub.INTEREST_RATE_CONTROLLER(), USER1);
    vm.stopPrank();
   
    // After granted role, USER1 can change interest rate
    vm.prank(USER1);
    hub.changeInterestRate();

    vm.startPrank(ADMIN);
    hub.revokeRole(hub.INTEREST_RATE_CONTROLLER(), USER1);
    vm.stopPrank();

    // After revoked role, USER1 cannot change interest rate
    vm.prank(USER1);
    vm.expectRevert();
    hub.changeInterestRate();
  }

  function testAddNewAddressToRole() public {
    vm.startPrank(ADMIN);
    hub.grantRole(hub.INTEREST_RATE_CONTROLLER(), USER2);
    vm.stopPrank();

    vm.prank(USER2);
    hub.changeInterestRate();
  }

  function testRoleAdmin() public {
    // Set INTEREST_RATE_CONTROLLER_ADMIN as USER1
    vm.startPrank(ADMIN);
    hub.setRoleAdmin(hub.INTEREST_RATE_CONTROLLER(), hub.INTEREST_RATE_CONTROLLER_ADMIN());
    hub.grantRole(hub.INTEREST_RATE_CONTROLLER_ADMIN(), USER1);
    vm.stopPrank();

    // USER1 can grant INTEREST_RATE_CONTROLLER role
    vm.startPrank(USER1);
    hub.grantRole(hub.INTEREST_RATE_CONTROLLER(), USER2);

    // USER1 CANNOT grant RISK_CONTROLLER role
    bytes32 RISK_CONTROLLER = hub.RISK_CONTROLLER();
    vm.expectRevert();
    hub.grantRole(RISK_CONTROLLER, USER2);
    vm.stopPrank();
  }

  function testRevokeRoleAdmin() public {
    // Set INTEREST_RATE_CONTROLLER_ADMIN as USER1
    vm.startPrank(ADMIN);
    hub.setRoleAdmin(hub.INTEREST_RATE_CONTROLLER(), hub.INTEREST_RATE_CONTROLLER_ADMIN());
    hub.grantRole(hub.INTEREST_RATE_CONTROLLER_ADMIN(), USER1);
    vm.stopPrank();

    // USER1 can grant INTEREST_RATE_CONTROLLER role
    vm.startPrank(USER1);
    hub.grantRole(hub.INTEREST_RATE_CONTROLLER(), USER2);
    vm.stopPrank();

    // Revoke INTEREST_RATE_CONTROLLER_ADMIN role from USER1
    vm.startPrank(ADMIN);
    hub.revokeRole(hub.INTEREST_RATE_CONTROLLER_ADMIN(), USER1);
    vm.stopPrank();

    // Now USER1 cannot grant INTEREST_RATE_CONTROLLER role
    bytes32 INTEREST_RATE_CONTROLLER = hub.INTEREST_RATE_CONTROLLER();
    vm.prank(USER1);
    vm.expectRevert();
    hub.grantRole(INTEREST_RATE_CONTROLLER, USER3);
  }
}
