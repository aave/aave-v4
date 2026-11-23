// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {AccessManaged} from 'src/dependencies/openzeppelin/AccessManaged.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

contract MockRestrictedTarget is AccessManaged {
  uint256 public value;

  constructor(address authority_) AccessManaged(authority_) {}

  function setValue(uint256 newValue) external restricted {
    value = newValue;
  }
}

/// @dev A role whose members hold an execution delay, with a second role as its guardian.
contract AccessManagerEnumerableExecutionDelayTest is Test {
  using SafeCast for uint256;

  uint64 internal constant DELAYED_ROLE = 500;
  uint64 internal constant GUARDIAN_ROLE = 501;
  uint32 internal constant EXECUTION_DELAY = 5 days;
  uint256 internal constant NEW_VALUE = 42;

  address internal ADMIN = makeAddr('ADMIN');
  address internal MEMBER = makeAddr('MEMBER');
  address internal OTHER_MEMBER = makeAddr('OTHER_MEMBER');
  address internal GUARDIAN = makeAddr('GUARDIAN');
  address internal STRANGER = makeAddr('STRANGER');

  AccessManagerEnumerable internal accessManagerEnumerable;
  MockRestrictedTarget internal target;
  bytes internal data;
  bytes32 internal operationId;

  function setUp() public virtual {
    accessManagerEnumerable = new AccessManagerEnumerable(ADMIN);
    target = new MockRestrictedTarget(address(accessManagerEnumerable));
    data = abi.encodeCall(MockRestrictedTarget.setValue, (NEW_VALUE));
    operationId = accessManagerEnumerable.hashOperation({
      caller: MEMBER,
      target: address(target),
      data: data
    });

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = MockRestrictedTarget.setValue.selector;

    vm.startPrank(ADMIN);
    accessManagerEnumerable.grantRole(DELAYED_ROLE, MEMBER, EXECUTION_DELAY);
    accessManagerEnumerable.grantRole(DELAYED_ROLE, OTHER_MEMBER, EXECUTION_DELAY);
    accessManagerEnumerable.grantRole(GUARDIAN_ROLE, GUARDIAN, 0);
    accessManagerEnumerable.setRoleGuardian(DELAYED_ROLE, GUARDIAN_ROLE);
    accessManagerEnumerable.setTargetFunctionRole(address(target), selectors, DELAYED_ROLE);
    vm.stopPrank();
  }

  function test_grantRole_withExecutionDelay() public view {
    (
      uint48 since,
      uint32 currentDelay,
      uint32 pendingDelay,
      uint48 effect
    ) = accessManagerEnumerable.getAccess(DELAYED_ROLE, MEMBER);
    assertEq(since, block.timestamp);
    assertEq(currentDelay, EXECUTION_DELAY);
    assertEq(pendingDelay, 0);
    assertEq(effect, 0);

    (bool isMember, uint32 executionDelay) = accessManagerEnumerable.hasRole(DELAYED_ROLE, MEMBER);
    assertTrue(isMember);
    assertEq(executionDelay, EXECUTION_DELAY);

    (bool immediate, uint32 delay) = accessManagerEnumerable.canCall(
      MEMBER,
      address(target),
      MockRestrictedTarget.setValue.selector
    );
    assertFalse(immediate);
    assertEq(delay, EXECUTION_DELAY);

    assertEq(accessManagerEnumerable.getRoleGuardian(DELAYED_ROLE), GUARDIAN_ROLE);
    _assertEnumeration();
  }

  function test_grantRole_increaseExecutionDelay() public {
    uint32 newDelay = EXECUTION_DELAY + 1 days;

    vm.prank(ADMIN);
    accessManagerEnumerable.grantRole(DELAYED_ROLE, MEMBER, newDelay);

    (, uint32 currentDelay, uint32 pendingDelay, uint48 effect) = accessManagerEnumerable.getAccess(
      DELAYED_ROLE,
      MEMBER
    );
    assertEq(currentDelay, newDelay);
    assertEq(pendingDelay, 0);
    assertEq(effect, 0);
    _assertEnumeration();
  }

  /// @dev A lower delay only applies once the difference with the old one has passed.
  function test_grantRole_decreaseExecutionDelay() public {
    uint32 newDelay = 1 days;
    uint256 effectAt = block.timestamp + EXECUTION_DELAY - newDelay;

    vm.prank(ADMIN);
    accessManagerEnumerable.grantRole(DELAYED_ROLE, MEMBER, newDelay);

    (, uint32 currentDelay, uint32 pendingDelay, uint48 effect) = accessManagerEnumerable.getAccess(
      DELAYED_ROLE,
      MEMBER
    );
    assertEq(currentDelay, EXECUTION_DELAY);
    assertEq(pendingDelay, newDelay);
    assertEq(effect, effectAt);

    vm.warp(effectAt - 1);
    (, currentDelay, , ) = accessManagerEnumerable.getAccess(DELAYED_ROLE, MEMBER);
    assertEq(currentDelay, EXECUTION_DELAY);

    vm.warp(effectAt);
    (, currentDelay, pendingDelay, effect) = accessManagerEnumerable.getAccess(
      DELAYED_ROLE,
      MEMBER
    );
    assertEq(currentDelay, newDelay);
    assertEq(pendingDelay, 0);
    assertEq(effect, 0);
    _assertEnumeration();
  }

  function test_restrictedCall_revertsWith_AccessManagerNotScheduled() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerNotScheduled.selector, operationId)
    );
    vm.prank(MEMBER);
    target.setValue(NEW_VALUE);
  }

  function test_execute_revertsWith_AccessManagerNotScheduled() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerNotScheduled.selector, operationId)
    );
    vm.prank(MEMBER);
    accessManagerEnumerable.execute(address(target), data);
  }

  function test_schedule() public {
    uint256 timepoint = block.timestamp + EXECUTION_DELAY;

    vm.expectEmit(address(accessManagerEnumerable));
    emit IAccessManager.OperationScheduled({
      operationId: operationId,
      nonce: 1,
      schedule: timepoint.toUint48(),
      caller: MEMBER,
      target: address(target),
      data: data
    });
    vm.prank(MEMBER);
    (bytes32 scheduledId, uint32 nonce) = accessManagerEnumerable.schedule(
      address(target),
      data,
      0
    );

    assertEq(scheduledId, operationId);
    assertEq(nonce, 1);
    assertEq(accessManagerEnumerable.getSchedule(operationId), timepoint);
    assertEq(target.value(), 0);
    _assertEnumeration();
  }

  function test_schedule_revertsWith_AccessManagerUnauthorizedCall_whenTooSoon() public {
    uint48 when = (block.timestamp + EXECUTION_DELAY - 1).toUint48();

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedCall.selector,
        MEMBER,
        address(target),
        MockRestrictedTarget.setValue.selector
      )
    );
    vm.prank(MEMBER);
    accessManagerEnumerable.schedule(address(target), data, when);
  }

  function test_schedule_revertsWith_AccessManagerUnauthorizedCall_whenNotMember() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedCall.selector,
        STRANGER,
        address(target),
        MockRestrictedTarget.setValue.selector
      )
    );
    vm.prank(STRANGER);
    accessManagerEnumerable.schedule(address(target), data, 0);
  }

  function test_schedule_revertsWith_AccessManagerAlreadyScheduled() public {
    _schedule();

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerAlreadyScheduled.selector, operationId)
    );
    vm.prank(MEMBER);
    accessManagerEnumerable.schedule(address(target), data, 0);
  }

  function test_execute_revertsWith_AccessManagerNotReady() public {
    uint256 timepoint = _schedule();

    vm.warp(timepoint - 1);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerNotReady.selector, operationId)
    );
    vm.prank(MEMBER);
    accessManagerEnumerable.execute(address(target), data);
  }

  function test_execute() public {
    uint256 timepoint = _schedule();

    vm.warp(timepoint);
    vm.expectEmit(address(accessManagerEnumerable));
    emit IAccessManager.OperationExecuted(operationId, 1);
    vm.prank(MEMBER);
    accessManagerEnumerable.execute(address(target), data);

    assertEq(target.value(), NEW_VALUE);
    assertEq(accessManagerEnumerable.getSchedule(operationId), 0);
    _assertEnumeration();
  }

  function test_restrictedCall_consumesSchedule() public {
    uint256 timepoint = _schedule();

    vm.warp(timepoint);
    vm.expectEmit(address(accessManagerEnumerable));
    emit IAccessManager.OperationExecuted(operationId, 1);
    vm.prank(MEMBER);
    target.setValue(NEW_VALUE);

    assertEq(target.value(), NEW_VALUE);
    assertEq(accessManagerEnumerable.getSchedule(operationId), 0);
  }

  /// @dev A schedule belongs to its caller, another member of the role cannot execute it.
  function test_execute_revertsWith_AccessManagerNotScheduled_whenOtherMember() public {
    uint256 timepoint = _schedule();
    bytes32 otherOperationId = accessManagerEnumerable.hashOperation({
      caller: OTHER_MEMBER,
      target: address(target),
      data: data
    });

    vm.warp(timepoint);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerNotScheduled.selector, otherOperationId)
    );
    vm.prank(OTHER_MEMBER);
    accessManagerEnumerable.execute(address(target), data);
  }

  function test_execute_lastSecondBeforeExpiration() public {
    uint256 timepoint = _schedule();

    vm.warp(timepoint + accessManagerEnumerable.expiration() - 1);
    vm.prank(MEMBER);
    accessManagerEnumerable.execute(address(target), data);

    assertEq(target.value(), NEW_VALUE);
  }

  function test_execute_revertsWith_AccessManagerExpired() public {
    uint256 timepoint = _schedule();

    vm.warp(timepoint + accessManagerEnumerable.expiration());
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerExpired.selector, operationId)
    );
    vm.prank(MEMBER);
    accessManagerEnumerable.execute(address(target), data);
  }

  function test_cancel_byGuardian() public {
    _assertCancel(GUARDIAN);
  }

  function test_cancel_byCaller() public {
    _assertCancel(MEMBER);
  }

  function test_cancel_byAdmin() public {
    _assertCancel(ADMIN);
  }

  function test_cancel_revertsWith_AccessManagerUnauthorizedCancel_whenOtherMember() public {
    _assertCancelUnauthorized(OTHER_MEMBER);
  }

  function test_cancel_revertsWith_AccessManagerUnauthorizedCancel_whenStranger() public {
    _assertCancelUnauthorized(STRANGER);
  }

  function test_cancel_revertsWith_AccessManagerNotScheduled() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerNotScheduled.selector, operationId)
    );
    vm.prank(GUARDIAN);
    accessManagerEnumerable.cancel({caller: MEMBER, target: address(target), data: data});
  }

  /// @dev A canceled operation can be scheduled again and waits the full delay again.
  function test_schedule_afterCancel() public {
    _schedule();
    vm.prank(GUARDIAN);
    accessManagerEnumerable.cancel({caller: MEMBER, target: address(target), data: data});

    skip(1 days);
    uint256 timepoint = block.timestamp + EXECUTION_DELAY;
    vm.prank(MEMBER);
    (, uint32 nonce) = accessManagerEnumerable.schedule(address(target), data, 0);

    assertEq(nonce, 2);
    assertEq(accessManagerEnumerable.getSchedule(operationId), timepoint);
  }

  function _schedule() internal returns (uint256 timepoint) {
    timepoint = block.timestamp + EXECUTION_DELAY;
    vm.prank(MEMBER);
    accessManagerEnumerable.schedule(address(target), data, 0);
  }

  function _assertCancel(address canceller) internal {
    uint256 timepoint = _schedule();

    vm.expectEmit(address(accessManagerEnumerable));
    emit IAccessManager.OperationCanceled(operationId, 1);
    vm.prank(canceller);
    accessManagerEnumerable.cancel({caller: MEMBER, target: address(target), data: data});

    assertEq(accessManagerEnumerable.getSchedule(operationId), 0);
    _assertEnumeration();

    vm.warp(timepoint);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManager.AccessManagerNotScheduled.selector, operationId)
    );
    vm.prank(MEMBER);
    accessManagerEnumerable.execute(address(target), data);
    assertEq(target.value(), 0);
  }

  function _assertCancelUnauthorized(address canceller) internal {
    _schedule();

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedCancel.selector,
        canceller,
        MEMBER,
        address(target),
        MockRestrictedTarget.setValue.selector
      )
    );
    vm.prank(canceller);
    accessManagerEnumerable.cancel({caller: MEMBER, target: address(target), data: data});
  }

  /// @dev The tracked roles, members, targets and selectors do not depend on delays or schedules.
  function _assertEnumeration() internal view {
    assertEq(accessManagerEnumerable.getRoleCount(), 2);
    assertTrue(accessManagerEnumerable.isRole(DELAYED_ROLE));
    assertTrue(accessManagerEnumerable.isRole(GUARDIAN_ROLE));

    address[] memory delayedMembers = accessManagerEnumerable.getRoleMembers(DELAYED_ROLE, 0, 2);
    assertEq(accessManagerEnumerable.getRoleMemberCount(DELAYED_ROLE), 2);
    assertEq(delayedMembers[0], MEMBER);
    assertEq(delayedMembers[1], OTHER_MEMBER);

    assertEq(accessManagerEnumerable.getRoleMemberCount(GUARDIAN_ROLE), 1);
    assertEq(accessManagerEnumerable.getRoleMember(GUARDIAN_ROLE, 0), GUARDIAN);

    assertEq(accessManagerEnumerable.getRoleTargetCount(DELAYED_ROLE), 1);
    assertEq(accessManagerEnumerable.getRoleTarget(DELAYED_ROLE, 0), address(target));
    assertEq(accessManagerEnumerable.getRoleTargetSelectorCount(DELAYED_ROLE, address(target)), 1);
    assertEq(
      accessManagerEnumerable.getRoleTargetSelector(DELAYED_ROLE, address(target), 0),
      MockRestrictedTarget.setValue.selector
    );
    assertEq(
      accessManagerEnumerable.getRoleOfTargetSelector(
        address(target),
        MockRestrictedTarget.setValue.selector
      ),
      DELAYED_ROLE
    );
  }
}
