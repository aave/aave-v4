// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {PermissionedBorrowingAccessManager} from 'src/access/PermissionedBorrowingAccessManager.sol';
import {IBorrowerEligibility} from 'src/access/interfaces/IBorrowerEligibility.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

contract MockBorrowerEligibility is IBorrowerEligibility {
  mapping(address borrower => bool eligible) internal _eligibleBorrowers;

  function setBorrowerEligible(address borrower, bool eligible) external {
    _eligibleBorrowers[borrower] = eligible;
  }

  function isBorrowerEligible(address borrower) external view returns (bool) {
    return _eligibleBorrowers[borrower];
  }
}

contract MockPermissionedSpoke is AccessManaged {
  constructor(address authority_) AccessManaged(authority_) {}

  function borrow(
    uint256 reserveId,
    uint256 amount,
    address
  ) external restricted returns (uint256, uint256) {
    return (reserveId, amount);
  }

  function supply() external restricted {}
}

contract PermissionedBorrowingAccessManagerTest is Test {
  uint64 internal constant BORROWER_ROLE = 303;

  address internal ADMIN = makeAddr('ADMIN');
  address internal ELIGIBLE_BORROWER = makeAddr('ELIGIBLE_BORROWER');
  address internal INELIGIBLE_BORROWER = makeAddr('INELIGIBLE_BORROWER');

  MockBorrowerEligibility internal eligibility;
  PermissionedBorrowingAccessManager internal accessManager;
  MockPermissionedSpoke internal spoke;

  function setUp() public {
    eligibility = new MockBorrowerEligibility();

    uint256 managerNonce = vm.getNonce(address(this));
    address expectedAccessManager = vm.computeCreateAddress(address(this), managerNonce);
    address expectedSpoke = vm.computeCreateAddress(address(this), managerNonce + 1);

    accessManager = new PermissionedBorrowingAccessManager(
      ADMIN,
      expectedSpoke,
      address(eligibility)
    );
    spoke = new MockPermissionedSpoke(address(accessManager));

    assertEq(address(accessManager), expectedAccessManager);
    assertEq(address(spoke), expectedSpoke);

    vm.prank(ADMIN);
    accessManager.setTargetFunctionRole(address(spoke), _borrowSelector(), BORROWER_ROLE);
  }

  function test_constructor_revertsWith_InvalidSpoke() public {
    vm.expectRevert(PermissionedBorrowingAccessManager.InvalidAddress.selector);
    new PermissionedBorrowingAccessManager(ADMIN, address(0), address(eligibility));
  }

  function test_constructor_revertsWith_InvalidEligibilityProvider() public {
    vm.expectRevert(PermissionedBorrowingAccessManager.InvalidAddress.selector);
    new PermissionedBorrowingAccessManager(ADMIN, address(spoke), address(0));
  }

  function test_canCall_allowsEligibleBorrower() public {
    eligibility.setBorrowerEligible(ELIGIBLE_BORROWER, true);

    (bool immediate, uint32 delay) = accessManager.canCall(
      ELIGIBLE_BORROWER,
      address(spoke),
      ISpoke.borrow.selector
    );

    assertTrue(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_deniesIneligibleBorrower() public view {
    (bool immediate, uint32 delay) = accessManager.canCall(
      INELIGIBLE_BORROWER,
      address(spoke),
      ISpoke.borrow.selector
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_preservesImmediateRoleAuthorization() public {
    vm.prank(ADMIN);
    accessManager.grantRole(BORROWER_ROLE, INELIGIBLE_BORROWER, 0);

    (bool immediate, uint32 delay) = accessManager.canCall(
      INELIGIBLE_BORROWER,
      address(spoke),
      ISpoke.borrow.selector
    );

    assertTrue(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_preservesDelayedRoleAuthorizationForEligibleBorrower() public {
    eligibility.setBorrowerEligible(ELIGIBLE_BORROWER, true);
    vm.prank(ADMIN);
    accessManager.grantRole(BORROWER_ROLE, ELIGIBLE_BORROWER, 1 days);

    (bool immediate, uint32 delay) = accessManager.canCall(
      ELIGIBLE_BORROWER,
      address(spoke),
      ISpoke.borrow.selector
    );

    assertFalse(immediate);
    assertEq(delay, 1 days);
  }

  function test_canCall_doesNotApplyEligibilityToOtherSelectors() public {
    eligibility.setBorrowerEligible(ELIGIBLE_BORROWER, true);

    (bool immediate, uint32 delay) = accessManager.canCall(
      ELIGIBLE_BORROWER,
      address(spoke),
      MockPermissionedSpoke.supply.selector
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_doesNotApplyEligibilityToOtherTargets() public {
    eligibility.setBorrowerEligible(ELIGIBLE_BORROWER, true);

    (bool immediate, uint32 delay) = accessManager.canCall(
      ELIGIBLE_BORROWER,
      makeAddr('OTHER_TARGET'),
      ISpoke.borrow.selector
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_doesNotBypassClosedTarget() public {
    eligibility.setBorrowerEligible(ELIGIBLE_BORROWER, true);
    vm.prank(ADMIN);
    accessManager.setTargetClosed(address(spoke), true);

    (bool immediate, uint32 delay) = accessManager.canCall(
      ELIGIBLE_BORROWER,
      address(spoke),
      ISpoke.borrow.selector
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_canCall_doesNotBypassAccessManagerExecutionCheck() public {
    eligibility.setBorrowerEligible(address(accessManager), true);

    (bool immediate, uint32 delay) = accessManager.canCall(
      address(accessManager),
      address(spoke),
      ISpoke.borrow.selector
    );

    assertFalse(immediate);
    assertEq(delay, 0);
  }

  function test_borrow_allowsEligibleBorrower() public {
    eligibility.setBorrowerEligible(ELIGIBLE_BORROWER, true);

    vm.prank(ELIGIBLE_BORROWER);
    (uint256 reserveId, uint256 amount) = spoke.borrow(7, 100e18, ELIGIBLE_BORROWER);

    assertEq(reserveId, 7);
    assertEq(amount, 100e18);
  }

  function test_borrow_revertsForIneligibleBorrower() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, INELIGIBLE_BORROWER)
    );
    vm.prank(INELIGIBLE_BORROWER);
    spoke.borrow(7, 100e18, INELIGIBLE_BORROWER);
  }

  function _borrowSelector() internal pure returns (bytes4[] memory selectors) {
    selectors = new bytes4[](1);
    selectors[0] = ISpoke.borrow.selector;
  }
}
