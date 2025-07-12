// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';

contract PositionStatusTest is Base {
  PositionStatusWrapper internal p;

  function setUp() public override {
    p = new PositionStatusWrapper();
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
    assertEq(p.isUsingAsCollateral(128), true);

    p.setUsingAsCollateral(128, false);
    assertEq(p.isUsingAsCollateral(128), false);

    p.setUsingAsCollateral(255, true);
    assertEq(p.isUsingAsCollateral(255), true);

    p.setUsingAsCollateral(255, false);
    assertEq(p.isUsingAsCollateral(255), false);
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
}
