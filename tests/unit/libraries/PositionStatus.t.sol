// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';

import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract PositionStatusTest is Test {
   
    using PositionStatus for DataTypes.PositionStatus;
    DataTypes.PositionStatus positionStatus;

  function setUp() public {

  }

  function test_setBorrowing_slot0() public {
  
    positionStatus.setBorrowing( 0, true);
    assertEq(positionStatus.isBorrowing(0), true);
    positionStatus.setBorrowing( 127, true);
    assertEq(positionStatus.isBorrowing(127), true);
  
  }

  function test_setBorrowing_slot1() public {

    
    positionStatus.setBorrowing( 128, true);
    assertEq(positionStatus.isBorrowing(128), true);

    positionStatus.setBorrowing( 128, false);
    assertEq(positionStatus.isBorrowing(128), false);

    positionStatus.setBorrowing( 255, true);
    assertEq(positionStatus.isBorrowing(255), true);

    positionStatus.setBorrowing( 255, false);
    assertEq(positionStatus.isBorrowing(255), false);

  }

  function test_fuzz_setBorrowing(uint256 a, bool b) public {
    if(a >= PositionStatus.MAX_RESERVES_COUNT) {
        vm.expectRevert();
        console.log("a is %d, b is %d", a, b);
        positionStatus.setBorrowing(a, b);
        return;
    }
    positionStatus.setBorrowing(a, b);
    assertEq(positionStatus.isBorrowing(a), b);
  }


}