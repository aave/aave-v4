// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract PositionStatusMapTest is Base {
  PositionStatusMapWrapper internal p;

  function setUp() public override {
    p = new PositionStatusMapWrapper();
  }

  function test_constants() public view {
    uint256 collateralMask;
    uint256 borrowingMask;
    for (uint256 i; i < 256; i += 2) {
      borrowingMask |= (1 << i);
      collateralMask |= (1 << (i + 1));
    }
    assertEq(p.COLLATERAL_MASK(), collateralMask);
    assertEq(p.BORROWING_MASK(), borrowingMask);
    assertEq(p.COLLATERAL_MASK() | p.BORROWING_MASK(), UINT256_MAX);
    assertEq(p.COLLATERAL_MASK() & p.BORROWING_MASK(), 0);
  }

  function test_setBorrowing_slot0() public {
    p.setBorrowing(0, true);
    assertEq(p.isBorrowing(0), true);

    p.setBorrowing(0, false);
    assertEq(p.isBorrowing(0), false);

    p.setBorrowing(127, true);
    assertEq(p.isBorrowing(127), true);

    p.setBorrowing(127, false);
    assertEq(p.isBorrowing(127), false);
  }

  function test_setBorrowing_slot1() public {
    p.setBorrowing(128, true);
    assertEq(p.isBorrowing(128), true);

    p.setBorrowing(128, false);
    assertEq(p.isBorrowing(128), false);

    p.setBorrowing(255, true);
    assertEq(p.isBorrowing(255), true);

    p.setBorrowing(255, false);
    assertEq(p.isBorrowing(255), false);
  }

  function test_fuzz_setBorrowing(uint256 a, bool b) public {
    p.setBorrowing(a, b);
    assertEq(p.isBorrowing(a), b);
  }

  function test_setUseAsCollateral_slot0() public {
    p.setUsingAsCollateral(0, true);
    assertEq(p.isUsingAsCollateral(0), true);

    p.setUsingAsCollateral(0, false);
    assertEq(p.isUsingAsCollateral(0), false);

    p.setUsingAsCollateral(127, true);
    assertEq(p.isUsingAsCollateral(127), true);

    p.setUsingAsCollateral(127, false);
    assertEq(p.isUsingAsCollateral(127), false);
  }

  function test_setUseAsCollateral_slot1() public {
    p.setUsingAsCollateral(128, true);
    assertEq(p.isUsingAsCollateral(128), true);

    p.setUsingAsCollateral(128, false);
    assertEq(p.isUsingAsCollateral(128), false);

    p.setUsingAsCollateral(255, true);
    assertEq(p.isUsingAsCollateral(255), true);

    p.setUsingAsCollateral(255, false);
    assertEq(p.isUsingAsCollateral(255), false);
  }

  function test_fuzz_setUseAsCollateral(uint256 a, bool b) public {
    p.setUsingAsCollateral(a, b);
    assertEq(p.isUsingAsCollateral(a), b);
  }

  function test_isUsingAsCollateralOrBorrowing_slot0() public {
    p.setUsingAsCollateral(0, true);
    assertEq(p.isUsingAsCollateralOrBorrowing(0), true);

    p.setUsingAsCollateral(0, false);
    assertEq(p.isUsingAsCollateralOrBorrowing(0), false);

    p.setBorrowing(0, true);
    assertEq(p.isUsingAsCollateralOrBorrowing(0), true);

    p.setBorrowing(0, false);
    assertEq(p.isUsingAsCollateralOrBorrowing(0), false);

    p.setUsingAsCollateral(0, true);
    assertEq(p.isUsingAsCollateralOrBorrowing(0), true);
    p.setBorrowing(0, true);
    assertEq(p.isUsingAsCollateralOrBorrowing(0), true);

    p.setUsingAsCollateral(0, false);
    p.setBorrowing(0, false);

    assertEq(p.isUsingAsCollateralOrBorrowing(0), false);

    p.setUsingAsCollateral(127, true);
    assertEq(p.isUsingAsCollateralOrBorrowing(127), true);

    p.setUsingAsCollateral(127, false);
    assertEq(p.isUsingAsCollateralOrBorrowing(127), false);

    p.setBorrowing(127, true);
    assertEq(p.isUsingAsCollateralOrBorrowing(127), true);

    p.setBorrowing(127, false);
    assertEq(p.isUsingAsCollateralOrBorrowing(127), false);
  }

  function test_isUsingAsCollateralOrBorrowing_slot1() public {
    p.setUsingAsCollateral(128, true);
    assertEq(p.isUsingAsCollateralOrBorrowing(128), true);

    p.setUsingAsCollateral(128, false);
    assertEq(p.isUsingAsCollateralOrBorrowing(128), false);

    p.setUsingAsCollateral(255, true);
    assertEq(p.isUsingAsCollateralOrBorrowing(255), true);

    p.setUsingAsCollateral(255, false);
    assertEq(p.isUsingAsCollateralOrBorrowing(255), false);
  }

  function test_collateralCount() public {
    p.setUsingAsCollateral(127, true);
    assertEq(p.collateralCount(128), 1);

    p.setUsingAsCollateral(128, true);
    assertEq(p.collateralCount(128), 1);
    assertEq(p.collateralCount(129), 2);

    // ignore invalid bits
    assertEq(p.collateralCount(100), 0);

    p.setUsingAsCollateral(2, true);
    assertEq(p.collateralCount(128), 2);

    p.setUsingAsCollateral(32, true);
    assertEq(p.collateralCount(128), 3);

    p.setUsingAsCollateral(342, true);
    assertEq(p.collateralCount(343), 5);

    p.setUsingAsCollateral(32, false);
    assertEq(p.collateralCount(343), 4);

    // disregards borrowed reserves
    p.setBorrowing(32, true);
    assertEq(p.collateralCount(343), 4);

    p.setBorrowing(79, true);
    assertEq(p.collateralCount(343), 4);

    p.setBorrowing(255, true);
    assertEq(p.collateralCount(343), 4);
  }

  function test_collateralCount_ignoresInvalidBits() public {
    p.setUsingAsCollateral(127, true);
    assertEq(p.collateralCount(100), 0);
    assertEq(p.collateralCount(200), 1);

    p.setUsingAsCollateral(255, true);
    assertEq(p.collateralCount(200), 1);
    p.setUsingAsCollateral(133, true);
    assertEq(p.collateralCount(200), 2);

    p.setUsingAsCollateral(383, true);
    assertEq(p.collateralCount(300), 3);
    p.setUsingAsCollateral(283, true);
    assertEq(p.collateralCount(300), 4);

    p.setUsingAsCollateral(511, true);
    assertEq(p.collateralCount(500), 5);
    assertEq(p.collateralCount(600), 6);
  }

  function test_collateralCount(uint256 reserveCount) public {
    reserveCount = bound(reserveCount, 0, 1 << 10); // gas limit
    vm.setArbitraryStorage(address(p));

    uint256 collateralCount;
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      if (p.isUsingAsCollateral(reserveId)) ++collateralCount;
      // reserveId is 0-base indexed, assert running collateralCount is maintained correctly
      assertEq(p.collateralCount({reserveCount: reserveId + 1}), collateralCount);
    }

    assertEq(p.collateralCount(reserveCount), collateralCount);
  }

  function test_setters_use_correct_slot(uint256 a) public {
    uint256 bucket = a / 128;
    bytes32 slot = keccak256(abi.encode(bucket, p.slot()));

    vm.record();
    p.setUsingAsCollateral(a, vm.randomBool());
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(p));
    assertEq(writes.length, 1);
    assertEq(reads.length, 2);

    assertEq(writes[0], slot);
    assertEq(reads[0], slot);
    assertEq(reads[1], slot);

    vm.record();
    p.setBorrowing(a, vm.randomBool());
    (reads, writes) = vm.accesses(address(p));
    assertEq(writes.length, 1);
    assertEq(reads.length, 2);

    assertEq(writes[0], slot);
    assertEq(reads[0], slot);
    assertEq(reads[1], slot);
  }

  function test_getBucketWord(uint256 a) public {
    uint256 bucket = a / 128;
    vm.record();
    p.getBucketWord(a);
    (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(p));
    assertEq(writes.length, 0);
    assertEq(reads.length, 1);
    assertEq(reads[0], keccak256(abi.encode(bucket, p.slot())));
  }

  function test_next(uint256 reserveCount) public {
    reserveCount = bound(reserveCount, 1, 1 << 10); // gas limit
    vm.setArbitraryStorage(address(p));

    uint256 startReserveId = vm.randomUint(1, reserveCount);
    uint256 expectedReserveId = PositionStatusMap.NOT_FOUND;
    for (uint256 i = startReserveId; i > 0; --i) {
      if (p.isUsingAsCollateral(i - 1) || p.isBorrowing(i - 1)) {
        expectedReserveId = i - 1;
        break;
      }
    }
    (uint256 reserveId, bool borrowing, bool collateral) = p.next(startReserveId);
    assertEq(reserveId, expectedReserveId);
    if (reserveId != PositionStatusMap.NOT_FOUND) {
      assertEq(borrowing, p.isBorrowing(reserveId));
      assertEq(collateral, p.isUsingAsCollateral(reserveId));
    }
  }

  function test_nextBorrowing(uint256 reserveCount) public {
    reserveCount = bound(reserveCount, 1, 1 << 10); // gas limit
    vm.setArbitraryStorage(address(p));

    uint256 startReserveId = vm.randomUint(1, reserveCount);
    uint256 expectedReserveId = PositionStatusMap.NOT_FOUND;
    for (uint256 i = startReserveId; i > 0; --i) {
      if (p.isBorrowing(i - 1)) {
        expectedReserveId = i - 1;
        break;
      }
    }
    uint256 reserveId = p.nextBorrowing(startReserveId);
    assertEq(reserveId, expectedReserveId);
    if (reserveId != PositionStatusMap.NOT_FOUND) {
      assertTrue(p.isBorrowing(reserveId));
    }
  }

  function test_nextCollateral(uint256 reserveCount) public {
    reserveCount = bound(reserveCount, 1, 1 << 10); // gas limit
    vm.setArbitraryStorage(address(p));

    uint256 startReserveId = vm.randomUint(1, reserveCount);
    uint256 expectedReserveId = PositionStatusMap.NOT_FOUND;
    for (uint256 i = startReserveId; i > 0; --i) {
      if (p.isUsingAsCollateral(i - 1)) {
        expectedReserveId = i - 1;
        break;
      }
    }
    uint256 reserveId = p.nextCollateral(startReserveId);
    assertEq(reserveId, expectedReserveId);
    if (reserveId != PositionStatusMap.NOT_FOUND) {
      assertTrue(p.isUsingAsCollateral(reserveId));
    }
  }

  function test_next_continuous() public {
    uint256 reserveCount = 10000;
    for (uint256 i; i < reserveCount; i++) {
      p.setBorrowing(i, vm.randomBool());
      p.setUsingAsCollateral(i, vm.randomBool());
    }
    uint256 lastSeenReserveId = reserveCount;
    uint256 nextReserveId = reserveCount;
    bool borrowing;
    bool collateral;
    while (true) {
      (nextReserveId, borrowing, collateral) = p.next(lastSeenReserveId);
      if (nextReserveId == PositionStatusMap.NOT_FOUND) break;

      assertEq(p.isBorrowing(nextReserveId), borrowing);
      assertEq(p.isUsingAsCollateral(nextReserveId), collateral);
      if (lastSeenReserveId > 0) lastSeenReserveId--; // skipping : search is exclusive, Id was already checked
      while (lastSeenReserveId > nextReserveId) {
        assertFalse(p.isBorrowing(lastSeenReserveId));
        assertFalse(p.isUsingAsCollateral(lastSeenReserveId));
        lastSeenReserveId--;
      }
    }
    if (lastSeenReserveId > 0) lastSeenReserveId--; // skipping : search is exclusive, Id was already checked
    while (lastSeenReserveId > 0) {
      assertFalse(p.isBorrowing(lastSeenReserveId));
      assertFalse(p.isUsingAsCollateral(lastSeenReserveId));
      lastSeenReserveId--;
    }
  }

  function test_nextBorrowing_continuous() public {
    uint256 reserveCount = 10000;
    for (uint256 i; i < reserveCount; i++) {
      p.setBorrowing(i, vm.randomBool());
      p.setUsingAsCollateral(i, vm.randomBool());
    }
    uint256 lastSeenReserveId = reserveCount;
    uint256 nextReserveId = reserveCount;
    while ((nextReserveId = p.nextBorrowing(lastSeenReserveId)) != PositionStatusMap.NOT_FOUND) {
      assertTrue(p.isBorrowing(nextReserveId));
      if (lastSeenReserveId > 0) lastSeenReserveId--; // skipping : search is exclusive, Id was already checked
      while (lastSeenReserveId > nextReserveId) {
        assertFalse(p.isBorrowing(lastSeenReserveId));
        lastSeenReserveId--;
      }
    }
    if (lastSeenReserveId > 0) lastSeenReserveId--; // skipping : search is exclusive, Id was already checked
    while (lastSeenReserveId > 0) {
      assertFalse(p.isBorrowing(lastSeenReserveId));
      lastSeenReserveId--;
    }
  }

  function test_nextCollateral_continuous() public {
    uint256 reserveCount = 10000;
    for (uint256 i; i < reserveCount; i++) {
      p.setBorrowing(i, vm.randomBool());
      p.setUsingAsCollateral(i, vm.randomBool());
    }
    uint256 lastSeenReserveId = reserveCount;
    uint256 nextReserveId = reserveCount;
    while ((nextReserveId = p.nextCollateral(lastSeenReserveId)) != PositionStatusMap.NOT_FOUND) {
      assertTrue(p.isUsingAsCollateral(nextReserveId));
      if (lastSeenReserveId > 0) lastSeenReserveId--; // skipping : search is exclusive, Id was already checked
      while (lastSeenReserveId > nextReserveId) {
        assertFalse(p.isUsingAsCollateral(lastSeenReserveId));
        lastSeenReserveId--;
      }
    }
    if (lastSeenReserveId > 0) lastSeenReserveId--; // skipping : search is exclusive, Id was already checked
    while (lastSeenReserveId > 0) {
      assertFalse(p.isUsingAsCollateral(lastSeenReserveId));
      lastSeenReserveId--;
    }
  }

  // non state reading helpers tests below
  function test_bucketId() public {
    uint256 reserveId = vm.randomUint();
    assertEq(p.bucketId(reserveId), reserveId / 128);
  }

  function test_fromBitId(uint256 bitId, uint256 bucket) public view {
    bitId = bound(bitId, 0, 255);
    bucket = bound(bucket, 0, 1 << 20);
    uint256 expectedReserveId = bitId / 2 + bucket * 128;
    assertEq(p.fromBitId(bitId, bucket), expectedReserveId);
  }

  function test_isolateBorrowing(uint256 word) public view {
    assertEq(p.isolateBorrowing(word), word & p.BORROWING_MASK());
    uint256 maskedWord = word & p.BORROWING_MASK();
    for (uint256 bitId; bitId < 256; ++bitId) {
      uint256 resultBit = (maskedWord >> bitId) & 1;
      // retain borrow info on even bits, ignore collateral info on odd bits
      uint256 expectedBit = bitId % 2 == 0 ? (word >> bitId) & 1 : 0;
      assertEq(resultBit, expectedBit);
    }
  }

  function test_isolateBorrowingUntil(uint256 word, uint256 reserveCount) public view {
    uint256 result = p.isolateBorrowingUntil(word, reserveCount);
    uint256 endBitId = (reserveCount % 128) * 2;

    for (uint256 bitId; bitId < 256; ++bitId) {
      uint256 resultBit = (result >> bitId) & 1;
      if (bitId >= endBitId) {
        // bit value after endBitId should be 0 (disregarded)
        assertEq(resultBit, 0);
      } else {
        // retain borrow info on even bits, ignore collateral info on odd bits
        uint256 expectedBit = bitId % 2 == 0 ? (word >> bitId) & 1 : 0;
        assertEq(resultBit, expectedBit);
      }
    }
  }

  function test_isolateUntil(uint256 word, uint256 reserveCount) public view {
    uint256 result = p.isolateUntil(word, reserveCount);
    uint256 endBitId = (reserveCount % 128) * 2;

    for (uint256 bitId; bitId < 256; ++bitId) {
      uint256 resultBit = (result >> bitId) & 1;
      if (bitId >= endBitId) {
        // bit value after endBitId should be 0 (disregarded)
        assertEq(resultBit, 0);
      } else {
        // bit value after startBitId should be retained
        assertEq(resultBit, (word >> bitId) & 1);
      }
    }
  }

  function test_isolateCollateral(uint256 word) public view {
    assertEq(p.isolateCollateral(word), word & p.COLLATERAL_MASK());
    uint256 maskedWord = word & p.COLLATERAL_MASK();
    for (uint256 bitId; bitId < 256; ++bitId) {
      uint256 resultBit = (maskedWord >> bitId) & 1;
      // retain collateral info on odd bits, ignore borrow info on even bits
      uint256 expectedBit = bitId % 2 == 0 ? 0 : (word >> bitId) & 1;
      assertEq(resultBit, expectedBit);
    }
  }

  function test_isolateCollateralUntil(uint256 word, uint256 reserveCount) public view {
    uint256 result = p.isolateCollateralUntil(word, reserveCount);
    uint256 endBitId = (reserveCount % 128) * 2;

    for (uint256 bitId; bitId < 256; ++bitId) {
      uint256 resultBit = (result >> bitId) & 1;
      if (bitId >= endBitId) {
        // bit value after endBitId should be 0 (disregarded)
        assertEq(resultBit, 0);
      } else {
        // retain collateral info on odd bits, ignore borrow info on even bits
        uint256 expectedBit = bitId % 2 == 0 ? 0 : (word >> bitId) & 1;
        assertEq(resultBit, expectedBit);
      }
    }
  }

  function test_popCount(bytes32) public {
    uint256 bits = vm.randomUint();
    assertEq(LibBit.popCount(bits), _popCountNaive(bits));
  }

  function _popCountNaive(uint256 x) internal pure returns (uint256 count) {
    while (x != 0) {
      count += x & 1;
      x >>= 1;
    }
  }

  function test_fls() public pure {
    assertEq(LibBit.fls(0xff << 3), 10);
    for (uint256 i = 1; i < 255; i++) {
      assertEq(LibBit.fls((1 << i) - 1), i - 1);
      assertEq(LibBit.fls((1 << i)), i);
      assertEq(LibBit.fls((1 << i) + 1), i);
    }
    assertEq(LibBit.fls(0), 256);
  }
}
