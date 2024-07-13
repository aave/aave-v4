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

  function testChangeRiskUnauthorized() public {
    vm.prank(USER1);
    vm.expectRevert();
    hub.changeRisk();
  }

  function testChangeRiskGrantAccess() public {
    vm.startPrank(ADMIN);
    // Get function signature of changeRisk
    bytes4 sig = bytes4(keccak256(bytes('changeRisk()')));
    hub.setRoleCapability(hub.RISK_CONTROLLER(), address(hub), sig, true);
    // Grant role to USER1
    hub.setUserRole(USER1, hub.RISK_CONTROLLER(), true);
    vm.stopPrank();

    vm.prank(USER1);
    hub.changeRisk();
  }

  function testChangeInterestRateUnauthorized() public {
    vm.prank(USER1);
    vm.expectRevert();
    hub.changeInterestRate();
  }

  function testChangeInterestRateGrantAccess() public {
    vm.startPrank(ADMIN);
    // Get function signature of changeInterestRate
    bytes4 sig = bytes4(keccak256(bytes('changeInterestRate()')));
    hub.setRoleCapability(hub.INTEREST_RATE_CONTROLLER(), address(hub), sig, true);
    // Grant role to USER1
    hub.setUserRole(USER1, hub.INTEREST_RATE_CONTROLLER(), true);
    vm.stopPrank();

    vm.prank(USER1);
    hub.changeInterestRate();
  }

  function testRevokeRole() public {
    vm.startPrank(ADMIN);
    // Get function signature of changeRisk
    bytes4 sig = bytes4(keccak256(bytes('changeRisk()')));
    hub.setRoleCapability(hub.RISK_CONTROLLER(), address(hub), sig, true);
    // Grant role to USER1
    hub.setUserRole(USER1, hub.RISK_CONTROLLER(), true);
    vm.stopPrank();

    vm.prank(USER1);
    hub.changeRisk();

    vm.startPrank(ADMIN);
    // Revoke role from USER1
    hub.setUserRole(USER1, hub.RISK_CONTROLLER(), false);
    vm.stopPrank();

    vm.prank(USER1);
    vm.expectRevert();
    hub.changeRisk();
  }

  function testChangeRoleCapability() public {
    vm.startPrank(ADMIN);
    // Get function signature of changeRisk
    bytes4 sig = bytes4(keccak256(bytes('changeRisk()')));
    hub.setRoleCapability(hub.RISK_CONTROLLER(), address(hub), sig, true);
    // Grant role to USER1
    hub.setUserRole(USER1, hub.RISK_CONTROLLER(), true);
    vm.stopPrank();

    vm.prank(USER1);
    hub.changeRisk();

    vm.startPrank(ADMIN);
    // Revoke function permission from role
    hub.setRoleCapability(hub.RISK_CONTROLLER(), address(hub), sig, false);
    vm.stopPrank();

    vm.prank(USER1);
    vm.expectRevert();
    hub.changeRisk();
  }
}
