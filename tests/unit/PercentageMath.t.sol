// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {PercentageMathWrapper} from 'tests/mocks/PercentageMathWrapper.sol';

contract PercentageMathTests is Test {
  PercentageMathWrapper internal w;

  function setUp() public {
    w = new PercentageMathWrapper();
  }

  function test_constants() public view {
    assertEq(w.PERCENTAGE_FACTOR(), 1e4, 'percentage factor');
  }

  function test_percentMul_fuzz(uint256 value, uint256 percentage) public {
    if (!(percentage == 0 || !(value > type(uint256).max / percentage))) {
      vm.expectRevert();
      w.percentMulDown(value, percentage);
      vm.expectRevert();
      w.percentMulUp(value, percentage);
    } else {
      assertEq(w.percentMulDown(value, percentage), (value * percentage) / (w.PERCENTAGE_FACTOR()));
      assertEq(
        w.percentMulUp(value, percentage),
        value * percentage == 0 ? 0 : (value * percentage - 1) / w.PERCENTAGE_FACTOR() + 1
      );
    }
  }

  function test_percentDiv_fuzz(uint256 value, uint256 percentage) public {
    if (percentage == 0 || value > type(uint256).max / w.PERCENTAGE_FACTOR()) {
      vm.expectRevert();
      w.percentDivDown(value, percentage);
      vm.expectRevert();
      w.percentDivUp(value, percentage);
    } else {
      assertEq(w.percentDivDown(value, percentage), (value * w.PERCENTAGE_FACTOR()) / percentage);
      assertEq(
        w.percentDivUp(value, percentage),
        value == 0 ? 0 : (value * w.PERCENTAGE_FACTOR() - 1) / percentage + 1
      );
    }
  }

  function test_percentMul() public view {
    assertEq(w.percentMulDown(1e18, 50_00), 0.5e18);
    assertEq(w.percentMulDown(14.2515e18, 74_42), 10.605966300000000000e18);
    assertEq(w.percentMulDown(9087312e27, 13_33), 1211338689600000000000000000000000);

    assertEq(w.percentMulUp(1e18, 50_00), 0.5e18);
    assertEq(w.percentMulUp(14.2515e18, 74_42), 10.605966300000000000e18);
    assertEq(w.percentMulUp(9087312e27, 13_33), 1211338689600000000000000000000000);
  }

  function test_percentDiv() public view {
    assertEq(w.percentDivDown(1e18, 50_00), 2e18);
    assertEq(w.percentDivDown(14.2515e18, 74_42), 19.150094060736361193e18);
    assertEq(w.percentDivDown(9087312e27, 13_33), 68171882970742685671417854463615903);

    assertEq(w.percentDivUp(1e18, 50_00), 2e18);
    assertEq(w.percentDivUp(14.2515e18, 74_42), 19.150094060736361194e18);
    assertEq(w.percentDivUp(9087312e27, 13_33), 68171882970742685671417854463615904);
  }

  function test_fromBpsDown() public view {
    assertEq(w.fromBpsDown(1e18), 1e14);
    assertEq(w.fromBpsDown(1e3), 0);
  }

  /// percentDivUp by >=100% should never exceed original value
  function test_percentDivUp_le_value(uint256 value, uint256 percent) public view {
    percent = bound(percent, w.PERCENTAGE_FACTOR(), w.PERCENTAGE_FACTOR() * 10);
    value = bound(value, 0, UINT256_MAX / percent); // to prevent overflow
    assertLe(
      w.percentDivUp(value, percent),
      value,
      'percentDivUp by >=100% should never exceed value'
    );
  }

  /// percentDivUp by <=100% should always be >= original value
  function test_percentDivUp_ge_value(uint256 value, uint256 percent) public view {
    percent = bound(percent, 1, w.PERCENTAGE_FACTOR());
    value = bound(value, 0, UINT256_MAX / w.PERCENTAGE_FACTOR()); // to prevent overflow
    assertGe(
      w.percentDivUp(value, percent),
      value,
      'percentDivUp by <=100% should always be ge value'
    );
  }

  /// percentMulUp by >=100% should always be >= original value
  function test_percentMulUp_ge_value(uint256 value, uint256 percent) public view {
    percent = bound(percent, w.PERCENTAGE_FACTOR(), w.PERCENTAGE_FACTOR() * 10);
    value = bound(value, 0, UINT256_MAX / percent); // to prevent overflow
    assertGe(
      w.percentMulUp(value, percent),
      value,
      'percentMulUp by >=100% should always be ge value'
    );
  }

  /// percentMulUp by <=100% should never exceed original value
  function test_percentMulUp_le_value(uint256 value, uint256 percent) public view {
    percent = bound(percent, 1, w.PERCENTAGE_FACTOR());
    value = bound(value, 0, UINT256_MAX / w.PERCENTAGE_FACTOR()); // to prevent overflow
    assertLe(
      w.percentMulUp(value, percent),
      value,
      'percentMulUp by >=100% should never exceed value'
    );
  }
}
