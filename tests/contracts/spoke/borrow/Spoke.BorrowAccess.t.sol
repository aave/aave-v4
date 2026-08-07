// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {
  IBorrowRegistry,
  MockPermissionedBorrowSpokeInstance
} from 'tests/helpers/mocks/MockPermissionedBorrowSpokeInstance.sol';

contract MockBorrowRegistry is IBorrowRegistry {
  mapping(address borrower => bool eligible) internal _eligible;

  function setEligible(address borrower, bool eligible) external {
    _eligible[borrower] = eligible;
  }

  function isEligible(address borrower) external view returns (bool) {
    return _eligible[borrower];
  }
}

contract SpokeBorrowAccessTest is Base {
  MockBorrowRegistry internal borrowRegistry;

  function setUp() public override {
    super.setUp();

    borrowRegistry = new MockBorrowRegistry();
    MockPermissionedBorrowSpokeInstance permissionedImplementation = new MockPermissionedBorrowSpokeInstance(
      spoke1.ORACLE(),
      spoke1.MAX_USER_RESERVES_LIMIT(),
      borrowRegistry
    );

    vm.prank(_getProxyAdminAddress(address(spoke1)));
    ITransparentUpgradeableProxy(address(spoke1)).upgradeToAndCall(
      address(permissionedImplementation),
      ''
    );
  }

  function test_borrow_revertsWith_BorrowAccessDenied() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    vm.expectRevert(
      abi.encodeWithSelector(ISpoke.BorrowAccessDenied.selector, bob, bob, reserveId, amount)
    );
    vm.prank(bob);
    spoke1.borrow(reserveId, amount, bob);
  }

  function test_borrow_succeeds_whenBorrowerIsEligible() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 100e18;

    _prepareBorrow(bob, borrowAmount);
    borrowRegistry.setEligible(bob, true);

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    assertEq(spoke1.getUserTotalDebt(daiReserveId, bob), borrowAmount);
  }

  function test_borrow_succeeds_throughPositionManager_whenBorrowerIsEligible() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 100e18;

    _prepareBorrow(bob, borrowAmount);
    borrowRegistry.setEligible(bob, true);

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(POSITION_MANAGER, true);
    vm.prank(bob);
    spoke1.setUserPositionManager(POSITION_MANAGER, true);

    uint256 managerBalanceBefore = tokenList.dai.balanceOf(POSITION_MANAGER);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: POSITION_MANAGER,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    assertEq(tokenList.dai.balanceOf(POSITION_MANAGER), managerBalanceBefore + borrowAmount);
    assertEq(spoke1.getUserTotalDebt(daiReserveId, bob), borrowAmount);
  }

  function _prepareBorrow(address borrower, uint256 borrowAmount) internal {
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: borrower,
      amount: 10e18,
      onBehalfOf: borrower
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });
  }
}
