// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';

import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract PositionStatusTest is Test {
  using PositionStatus for DataTypes.PositionStatus;
  DataTypes.PositionStatus positionStatus;

  function test_setBorrowing_slot0() public {
    positionStatus.setBorrowing(0, true);
    assertEq(positionStatus.isBorrowing(0), true);

    positionStatus.setBorrowing(0, false);
    assertEq(positionStatus.isBorrowing(0), false);

    positionStatus.setBorrowing(127, true);
    assertEq(positionStatus.isBorrowing(127), true);

    positionStatus.setBorrowing(127, false);
    assertEq(positionStatus.isBorrowing(127), false);
  }

  function test_setBorrowing_slot1() public {
    positionStatus.setBorrowing(128, true);
    assertEq(positionStatus.isBorrowing(128), true);

    positionStatus.setBorrowing(128, false);
    assertEq(positionStatus.isBorrowing(128), false);

    positionStatus.setBorrowing(255, true);
    assertEq(positionStatus.isBorrowing(255), true);

    positionStatus.setBorrowing(255, false);
    assertEq(positionStatus.isBorrowing(255), false);
  }

  /// forge-config: default.allow_internal_expect_revert = true
  function test_fuzz_setBorrowing(uint256 a, bool b) public {
    if (a >= PositionStatus.MAX_RESERVES_COUNT) {
      vm.expectRevert(PositionStatus.InvalidReserveId.selector);
      positionStatus.setBorrowing(a, b);
      return;
    }
    positionStatus.setBorrowing(a, b);
    assertEq(positionStatus.isBorrowing(a), b);
  }

  function test_setUseAsCollateral_slot0() public {
    positionStatus.setUsingAsCollateral(0, true);
    assertEq(positionStatus.isUsingAsCollateral(0), true);

    positionStatus.setUsingAsCollateral(0, false);
    assertEq(positionStatus.isUsingAsCollateral(0), false);

    positionStatus.setUsingAsCollateral(127, true);
    assertEq(positionStatus.isUsingAsCollateral(127), true);

    positionStatus.setUsingAsCollateral(127, false);
    assertEq(positionStatus.isUsingAsCollateral(127), false);
  }

  function test_setUseAsCollateral_slot1() public {
    positionStatus.setUsingAsCollateral(128, true);
    assertEq(positionStatus.isUsingAsCollateral(128), true);

    positionStatus.setUsingAsCollateral(128, false);
    assertEq(positionStatus.isUsingAsCollateral(128), false);

    positionStatus.setUsingAsCollateral(255, true);
    assertEq(positionStatus.isUsingAsCollateral(255), true);

    positionStatus.setUsingAsCollateral(255, false);
    assertEq(positionStatus.isUsingAsCollateral(255), false);
  }

  /// forge-config: default.allow_internal_expect_revert = true
  function test_fuzz_setUseAsCollateral(uint256 a, bool b) public {
    if (a >= PositionStatus.MAX_RESERVES_COUNT) {
      vm.expectRevert();
      positionStatus.setUsingAsCollateral(a, b);
      return;
    }
    positionStatus.setUsingAsCollateral(a, b);
    assertEq(positionStatus.isUsingAsCollateral(a), b);
  }

  function test_isUsingAsCollateralOrBorrowing_slot0() public {
    positionStatus.setUsingAsCollateral(0, true);
    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(0), true);

    positionStatus.setUsingAsCollateral(0, false);
    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(0), false);

    positionStatus.setBorrowing(0, true);
    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(0), true);

    positionStatus.setBorrowing(0, false);
    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(0), false);

    positionStatus.setUsingAsCollateral(0, true);
    positionStatus.setBorrowing(0, true);

    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(0), true);

    positionStatus.setUsingAsCollateral(0, false);
    positionStatus.setBorrowing(0, false);

    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(0), false);

    positionStatus.setUsingAsCollateral(127, true);
    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(127), true);

    positionStatus.setUsingAsCollateral(127, false);
    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(127), false);

    positionStatus.setBorrowing(127, true);
    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(127), true);

    positionStatus.setBorrowing(127, false);
    assertEq(positionStatus.isUsingAsCollateralOrBorrowing(127), false);
  }

  function test_isUsingAsCollateralOrBorrowing_slot1() public {
    positionStatus.setUsingAsCollateral(128, true);
    assertEq(positionStatus.isUsingAsCollateral(128), true);

    positionStatus.setUsingAsCollateral(128, false);
    assertEq(positionStatus.isUsingAsCollateral(128), false);

    positionStatus.setUsingAsCollateral(255, true);
    assertEq(positionStatus.isUsingAsCollateral(255), true);

    positionStatus.setUsingAsCollateral(255, false);
    assertEq(positionStatus.isUsingAsCollateral(255), false);
  }
}
