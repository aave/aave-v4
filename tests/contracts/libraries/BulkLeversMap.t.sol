// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {BulkLeversMapWrapper} from 'tests/helpers/mocks/BulkLeversMapWrapper.sol';

contract BulkLeversMapTest is Test {
  uint8 internal constant ASSET_MASK = 0x01;
  uint8 internal constant SPOKE_MASK = 0x02;
  uint8 internal constant HUB_MASK = 0x04;
  uint8 internal constant RESERVE_MASK = 0x08;
  uint8 internal constant ALL_MASKS = ASSET_MASK | SPOKE_MASK | HUB_MASK;

  BulkLeversMapWrapper internal w;

  function setUp() public {
    w = new BulkLeversMapWrapper();
  }

  function test_constants() public view {
    assertEq(w.ASSET_MASK(), ASSET_MASK);
    assertEq(w.SPOKE_MASK(), SPOKE_MASK);
    assertEq(w.HUB_MASK(), HUB_MASK);
    assertEq(w.RESERVE_MASK(), RESERVE_MASK);
  }

  function test_fuzz_brake_flagUpdated_replacesBulkLevers(
    uint8 bulkLevers,
    uint256 lever
  ) public view {
    uint8 mask = _mask(lever);
    assertEq(w.brake(uint8(bound(bulkLevers, 0, ALL_MASKS)), mask, true), mask);
  }

  function test_fuzz_brake_flagAlreadySet_doesNotRecordUnheldFlag(uint256 lever) public view {
    assertEq(w.brake(0, _mask(lever), false), 0);
  }

  function test_fuzz_brake_flagAlreadySet_joinsHeldFlag(
    uint8 bulkLevers,
    uint256 lever
  ) public view {
    bulkLevers = uint8(bound(bulkLevers, 1, ALL_MASKS));
    uint8 mask = _mask(lever);
    assertEq(w.brake(bulkLevers, mask, false), bulkLevers | mask);
  }

  function test_fuzz_release_notHeld_isNoOp(uint256 lever) public view {
    uint8 mask = _mask(lever);
    uint8 otherMasks = ALL_MASKS & ~mask;
    _assertRelease(0, mask, 0, false);
    _assertRelease(otherMasks, mask, otherMasks, false);
  }

  function test_fuzz_release_onlyHolder_clearsFlag(uint256 lever) public view {
    uint8 mask = _mask(lever);
    _assertRelease(mask, mask, 0, true);
  }

  function test_fuzz_release_sharedHold_keepsFlag(uint256 lever) public view {
    uint8 mask = _mask(lever);
    _assertRelease(ALL_MASKS, mask, ALL_MASKS & ~mask, false);
  }

  function test_fuzz_isHeld(uint8 bulkLevers, uint256 lever) public view {
    uint8 mask = _mask(lever);
    assertTrue(w.isHeld(bulkLevers | mask, mask));
    assertFalse(w.isHeld(bulkLevers & ~mask, mask));
  }

  /// @dev Two bulk levers brake the same flag; the flag is cleared only once both have released, in either order.
  function test_fuzz_overlappingLevers_clearFlagOnLastRelease(
    uint256 firstLever,
    bool nextLever
  ) public view {
    firstLever = bound(firstLever, 0, 2);
    uint8 first = _mask(firstLever);
    uint8 second = _mask(firstLever + (nextLever ? 1 : 2));

    uint8 bulkLevers = w.brake(0, first, true);
    bulkLevers = w.brake(bulkLevers, second, false);
    assertEq(bulkLevers, first | second);

    bool cleared;
    (bulkLevers, cleared) = w.release(bulkLevers, first);
    assertFalse(cleared);
    (bulkLevers, cleared) = w.release(bulkLevers, first);
    assertFalse(cleared, 'repeated release');
    (bulkLevers, cleared) = w.release(bulkLevers, second);
    assertTrue(cleared);
    assertEq(bulkLevers, 0);
  }

  /// @dev All three bulk levers brake the same flag; the flag is cleared only on the last release.
  function test_fuzz_allLevers_clearFlagOnLastRelease(
    uint256 firstLever,
    bool reverse
  ) public view {
    firstLever = bound(firstLever, 0, 2);
    uint8[3] memory order = [
      _mask(firstLever),
      _mask(firstLever + (reverse ? 2 : 1)),
      _mask(firstLever + (reverse ? 1 : 2))
    ];

    uint8 bulkLevers = w.brake(0, order[0], true);
    bulkLevers = w.brake(bulkLevers, order[1], false);
    bulkLevers = w.brake(bulkLevers, order[2], false);
    assertEq(bulkLevers, ALL_MASKS);

    bool cleared;
    (bulkLevers, cleared) = w.release(bulkLevers, order[2]);
    assertFalse(cleared);
    (bulkLevers, cleared) = w.release(bulkLevers, order[0]);
    assertFalse(cleared);
    (bulkLevers, cleared) = w.release(bulkLevers, order[1]);
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

  /// @dev Returns one of the three bulk lever masks, chosen by `lever`.
  function _mask(uint256 lever) internal pure returns (uint8) {
    uint256 index = lever % 3;
    return
      index == 0
        ? ASSET_MASK
        : index == 1
          ? SPOKE_MASK
          : HUB_MASK;
  }
}
