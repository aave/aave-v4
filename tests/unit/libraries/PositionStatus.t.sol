// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {LibBit} from 'src/dependencies/solady/LibBit.sol';
import {Test, console2 as console} from 'forge-std/Test.sol';

import {PositionStatusWrapper, PositionStatus} from 'tests/mocks/PositionStatusWrapper.sol';

contract PositionStatusTest is Test {
  PositionStatusWrapper internal p;

  function setUp() public {
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
    assertEq(p.COLLATERAL_MASK() ^ p.BORROWING_MASK(), UINT256_MAX);
  }

  function test_setBorrowing_slot0() public {
    p.setBorrowing(0, true);
    assertEq(p.isBorrowing(0), true);

    p.setBorrowing(0, false);
    assertEq(p.isBorrowing(0), false);

    p.setBorrowing(0, true);
    assertEq(p.isBorrowing(0), true);

    p.setBorrowing(127, true);
    assertEq(p.isBorrowing(127), true);
    assertEq(p.isBorrowing(0), true);

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

  /// forge-config: default.allow_internal_expect_revert = true
  function test_fuzz_setBorrowing(uint256 a, bool b) public {
    if (a >= PositionStatus.MAX_RESERVES_COUNT) {
      vm.expectRevert(PositionStatus.InvalidReserveId.selector);
      p.setBorrowing(a, b);
      return;
    }
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

  /// forge-config: default.allow_internal_expect_revert = true
  function test_fuzz_setUseAsCollateral(uint256 a, bool b) public {
    if (a >= PositionStatus.MAX_RESERVES_COUNT) {
      vm.expectRevert();
      p.setUsingAsCollateral(a, b);
      return;
    }
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
    assertEq(p.collateralCount(PositionStatus.MAX_RESERVES_COUNT), 1);
    assertEq(p.collateralCount(128), 1);

    // ignore invalid bits
    assertEq(p.collateralCount(100), 0);

    p.setUsingAsCollateral(2, true);
    assertEq(p.collateralCount(PositionStatus.MAX_RESERVES_COUNT), 2);
    assertEq(p.collateralCount(128), 2);

    p.setUsingAsCollateral(32, true);
    assertEq(p.collateralCount(PositionStatus.MAX_RESERVES_COUNT), 3);
    assertEq(p.collateralCount(128), 3);

    p.setUsingAsCollateral(342, true);
    assertEq(p.collateralCount(PositionStatus.MAX_RESERVES_COUNT), 4);
    assertEq(p.collateralCount(343), 4);

    p.setUsingAsCollateral(342, true);
    assertEq(p.collateralCount(PositionStatus.MAX_RESERVES_COUNT), 4);
    assertEq(p.collateralCount(343), 4);

    p.setUsingAsCollateral(32, false);
    assertEq(p.collateralCount(PositionStatus.MAX_RESERVES_COUNT), 3);
    assertEq(p.collateralCount(343), 3);

    // disregards borrowed assets
    p.setBorrowing(32, true);
    assertEq(p.collateralCount(PositionStatus.MAX_RESERVES_COUNT), 3);
    assertEq(p.collateralCount(343), 3);

    p.setBorrowing(79, true);
    assertEq(p.collateralCount(PositionStatus.MAX_RESERVES_COUNT), 3);
    assertEq(p.collateralCount(343), 3);

    vm.expectRevert();
    p.collateralCount(PositionStatus.MAX_RESERVES_COUNT + 1);
  }

  function test_collateralCount_symbolic(uint256 reserveCount) public {
    reserveCount = bound(reserveCount, 0, PositionStatus.MAX_RESERVES_COUNT);
    vm.setArbitraryStorage(address(p));

    uint256 collateralCount;
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      if (p.isUsingAsCollateral(reserveId)) ++collateralCount;
    }

    assertEq(p.collateralCount(reserveCount), collateralCount);
  }

  function test_popCount(uint256 bits) public pure {
    assertEq(LibBit.popCount(bits), _popCountNaive(bits));
  }

  function _popCountNaive(uint256 x) internal pure returns (uint256 count) {
    while (x != 0) {
      count += x & 1;
      x >>= 1;
    }
  }
}
