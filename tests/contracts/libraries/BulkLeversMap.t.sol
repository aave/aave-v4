// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {BulkLeversMapWrapper} from 'tests/helpers/mocks/BulkLeversMapWrapper.sol';

contract BulkLeversMapTest is Test {
  uint8 internal constant ASSET_MASK = 0x01;
  uint8 internal constant SPOKE_MASK = 0x02;
  uint8 internal constant ALL_MASKS = ASSET_MASK | SPOKE_MASK;

  BulkLeversMapWrapper internal w;

  function setUp() public {
    w = new BulkLeversMapWrapper();
  }

  function test_constants() public view {
    assertEq(w.ASSET_MASK(), ASSET_MASK);
    assertEq(w.SPOKE_MASK(), SPOKE_MASK);
  }

  function test_fuzz_brake_flagUpdated_replacesBulkLevers(
    uint8 bulkLevers,
    bool spokeLever
  ) public view {
    uint8 mask = _mask(spokeLever);
    assertEq(w.brake(uint8(bound(bulkLevers, 0, ALL_MASKS)), mask, true), mask);
  }

  function test_fuzz_brake_flagAlreadySet_doesNotRecordUnheldFlag(bool spokeLever) public view {
    assertEq(w.brake(0, _mask(spokeLever), false), 0);
  }

  function test_fuzz_brake_flagAlreadySet_joinsHeldFlag(
    uint8 bulkLevers,
    bool spokeLever
  ) public view {
    bulkLevers = uint8(bound(bulkLevers, 1, ALL_MASKS));
    uint8 mask = _mask(spokeLever);
    assertEq(w.brake(bulkLevers, mask, false), bulkLevers | mask);
  }

  function test_fuzz_release_notHeld_isNoOp(bool spokeLever) public view {
    uint8 mask = _mask(spokeLever);
    uint8 otherMask = _mask(!spokeLever);
    _assertRelease(0, mask, 0, false);
    _assertRelease(otherMask, mask, otherMask, false);
  }

  function test_fuzz_release_onlyHolder_clearsFlag(bool spokeLever) public view {
    uint8 mask = _mask(spokeLever);
    _assertRelease(mask, mask, 0, true);
  }

  function test_fuzz_release_sharedHold_keepsFlag(bool spokeLever) public view {
    uint8 mask = _mask(spokeLever);
    _assertRelease(ALL_MASKS, mask, _mask(!spokeLever), false);
  }

  function test_fuzz_isHeld(uint8 bulkLevers, bool spokeLever) public view {
    uint8 mask = _mask(spokeLever);
    assertTrue(w.isHeld(bulkLevers | mask, mask));
    assertFalse(w.isHeld(bulkLevers & ~mask, mask));
  }

  /// @dev Both bulk levers brake the same flag; the flag is cleared only once both have released, in either order.
  function test_fuzz_overlappingLevers_clearFlagOnLastRelease(bool spokeLeverFirst) public view {
    uint8 first = _mask(spokeLeverFirst);
    uint8 second = _mask(!spokeLeverFirst);

    uint8 bulkLevers = w.brake(0, first, true);
    bulkLevers = w.brake(bulkLevers, second, false);
    assertEq(bulkLevers, ALL_MASKS);

    bool cleared;
    (bulkLevers, cleared) = w.release(bulkLevers, first);
    assertFalse(cleared);
    (bulkLevers, cleared) = w.release(bulkLevers, first);
    assertFalse(cleared, 'repeated release');
    (bulkLevers, cleared) = w.release(bulkLevers, second);
    assertTrue(cleared);
    assertEq(bulkLevers, 0);
  }

  function _assertRelease(
    uint8 bulkLevers,
    uint8 mask,
    uint8 expectedBulkLevers,
    bool expectedCleared
  ) internal view {
    (uint8 newBulkLevers, bool cleared) = w.release(bulkLevers, mask);
    assertEq(newBulkLevers, expectedBulkLevers);
    assertEq(cleared, expectedCleared);
  }

  function _mask(bool spokeLever) internal pure returns (uint8) {
    return spokeLever ? SPOKE_MASK : ASSET_MASK;
  }
}
