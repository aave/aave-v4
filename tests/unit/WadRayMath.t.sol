// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {WadRayMathWrapper} from 'tests/mocks/WadRayMathWrapper.sol';

contract WadRayMathDifferentialTests is Test {
  WadRayMathWrapper internal w;

  function setUp() public {
    w = new WadRayMathWrapper();
  }

  function test_constants() public view {
    assertEq(w.WAD(), 1e18, 'wad');
    assertEq(w.RAY(), 1e27, 'ray');
    assertEq(w.PERCENTAGE_FACTOR(), 1e4, 'percentage factor');
  }

  function test_fuzz_wadMul(uint256 a, uint256 b) public {
    // overflow case
    if (!(b == 0 || !(a > type(uint256).max / b))) {
      vm.expectRevert();
      w.wadMulDown(a, b);
      vm.expectRevert();
      w.wadMulUp(a, b);
    } else {
      assertEq(w.wadMulDown(a, b), (a * b) / w.WAD());
      assertEq(w.wadMulUp(a, b), a * b == 0 ? 0 : (a * b - 1) / w.WAD() + 1);
    }
  }

  function test_fuzz_wadDiv(uint256 a, uint256 b) public {
    if (b == 0 || (a > type(uint256).max / w.WAD())) {
      vm.expectRevert();
      w.wadDivDown(a, b);
      vm.expectRevert();
      w.wadDivUp(a, b);

      return;
    }

    assertEq(w.wadDivDown(a, b), (a * w.WAD()) / b);
    assertEq(w.wadDivUp(a, b), a == 0 ? 0 : (a * w.WAD() - 1) / b + 1);
  }

  function test_fuzz_rayMul(uint256 a, uint256 b) public {
    // overflow case
    if (!(b == 0 || !(a > type(uint256).max / b))) {
      vm.expectRevert();
      w.rayMulDown(a, b);
      vm.expectRevert();
      w.rayMulUp(a, b);
    } else {
      assertEq(w.rayMulDown(a, b), (a * b) / w.RAY());
      assertEq(w.rayMulUp(a, b), a * b == 0 ? 0 : (a * b - 1) / w.RAY() + 1);
    }
  }

  function test_fuzz_rayDiv(uint256 a, uint256 b) public {
    if (b == 0 || (a > type(uint256).max / w.RAY())) {
      vm.expectRevert();
      w.rayDivDown(a, b);
      vm.expectRevert();
      w.rayDivUp(a, b);

      return;
    }

    assertEq(w.rayDivDown(a, b), (a * w.RAY()) / b);
    assertEq(w.rayDivUp(a, b), a == 0 ? 0 : (a * w.RAY() - 1) / b + 1);
  }

  function test_wadMul() public {
    assertEq(w.wadMulDown(0, 1e18), 0);
    assertEq(w.wadMulDown(1e18, 0), 0);
    assertEq(w.wadMulDown(0, 0), 0);

    assertEq(w.wadMulDown(2.5e18, 0.5e18), 1.25e18);
    assertEq(w.wadMulDown(3e18, 1e18), 3e18);
    assertEq(w.wadMulDown(369, 271), 0);
    assertEq(w.wadMulDown(412.2e18, 1e18), 412.2e18);
    assertEq(w.wadMulDown(6e18, 2e18), 12e18);

    assertEq(w.wadMulUp(0, 1e18), 0);
    assertEq(w.wadMulUp(1e18, 0), 0);
    assertEq(w.wadMulUp(0, 0), 0);

    assertEq(w.wadMulUp(2.5e18, 0.5e18), 1.25e18);
    assertEq(w.wadMulUp(3e18, 1e18), 3e18);
    assertEq(w.wadMulUp(369, 271), 1);
    assertEq(w.wadMulUp(412.2e18, 1e18), 412.2e18);
    assertEq(w.wadMulUp(6e18, 2e18), 12e18);
  }

  function test_rayMul() public {
    assertEq(w.rayMulDown(0, 1e27), 0);
    assertEq(w.rayMulDown(1e27, 0), 0);
    assertEq(w.rayMulDown(0, 0), 0);

    assertEq(w.rayMulDown(2.5e27, 0.5e27), 1.25e27);
    assertEq(w.rayMulDown(3e27, 1e27), 3e27);
    assertEq(w.rayMulDown(369, 271), 0);
    assertEq(w.rayMulDown(412.2e27, 1e27), 412.2e27);
    assertEq(w.rayMulDown(6e27, 2e27), 12e27);

    assertEq(w.rayMulUp(0, 1e27), 0);
    assertEq(w.rayMulUp(1e27, 0), 0);
    assertEq(w.rayMulUp(0, 0), 0);

    assertEq(w.rayMulUp(2.5e27, 0.5e27), 1.25e27);
    assertEq(w.rayMulUp(3e27, 1e27), 3e27);
    assertEq(w.rayMulUp(369, 271), 1);
    assertEq(w.rayMulUp(412.2e27, 1e27), 412.2e27);
    assertEq(w.rayMulUp(6e27, 2e27), 12e27);
  }

  function test_wadDiv() public {
    assertEq(w.wadDivDown(0, 1e18), 0);
    vm.expectRevert();
    assertEq(w.wadDivDown(1e18, 0), 0);
    vm.expectRevert();
    assertEq(w.wadDivDown(0, 0), 0);

    assertEq(w.wadDivDown(2.5e18, 0.5e18), 5e18);
    assertEq(w.wadDivDown(412.2e18, 1e18), 412.2e18);
    assertEq(w.wadDivDown(8.745e18, 0.67e18), 13.052238805970149253e18);
    assertEq(w.wadDivDown(6e18, 2e18), 3e18);
    assertEq(w.wadDivDown(1.25e18, 0.5e18), 2.5e18);
    assertEq(w.wadDivDown(3e18, 1e18), 3e18);
    assertEq(w.wadDivDown(2, 100000000000000e18), 0);

    assertEq(w.wadDivUp(0, 1e18), 0);
    vm.expectRevert();
    assertEq(w.wadDivUp(1e18, 0), 0);
    vm.expectRevert();
    assertEq(w.wadDivUp(0, 0), 0);

    assertEq(w.wadDivUp(2.5e18, 0.5e18), 5e18);
    assertEq(w.wadDivUp(412.2e18, 1e18), 412.2e18);
    assertEq(w.wadDivUp(8.745e18, 0.67e18), 13.052238805970149254e18);
    assertEq(w.wadDivUp(6e18, 2e18), 3e18);
    assertEq(w.wadDivUp(1.25e18, 0.5e18), 2.5e18);
    assertEq(w.wadDivUp(3e18, 1e18), 3e18);
    assertEq(w.wadDivUp(2, 100000000000000e18), 1);
  }

  function test_rayDiv() public {
    assertEq(w.rayDivDown(0, 1e27), 0);
    vm.expectRevert();
    assertEq(w.rayDivDown(1e27, 0), 0);
    vm.expectRevert();
    assertEq(w.rayDivDown(0, 0), 0);

    assertEq(w.rayDivDown(2.5e27, 0.5e27), 5e27);
    assertEq(w.rayDivDown(412.2e27, 1e27), 412.2e27);
    assertEq(w.rayDivDown(8.745e27, 0.67e27), 13.052238805970149253731343283e27);
    assertEq(w.rayDivDown(6e27, 2e27), 3e27);
    assertEq(w.rayDivDown(1.25e27, 0.5e27), 2.5e27);
    assertEq(w.rayDivDown(3e27, 1e27), 3e27);
    assertEq(w.rayDivDown(2, 100000000000000e27), 0);

    assertEq(w.rayDivUp(0, 1e27), 0);
    vm.expectRevert();
    assertEq(w.rayDivUp(1e27, 0), 0);
    vm.expectRevert();
    assertEq(w.rayDivUp(0, 0), 0);

    assertEq(w.rayDivUp(2.5e27, 0.5e27), 5e27);
    assertEq(w.rayDivUp(412.2e27, 1e27), 412.2e27);
    assertEq(w.rayDivUp(8.745e27, 0.67e27), 13.052238805970149253731343284e27);
    assertEq(w.rayDivUp(6e27, 2e27), 3e27);
    assertEq(w.rayDivUp(1.25e27, 0.5e27), 2.5e27);
    assertEq(w.rayDivUp(3e27, 1e27), 3e27);
    assertEq(w.rayDivUp(2, 100000000000000e27), 1);
  }

  function test_fromWadDown_fuzz(uint256 a) public {
    assertEq(w.fromWadDown(a), a / w.WAD());
  }

  function test_toWad_fuzz(uint256 a) public {
    uint256 b;
    bool safetyCheck;
    unchecked {
      b = a * w.WAD();
      safetyCheck = b / w.WAD() == a;
    }
    if (!safetyCheck) {
      vm.expectRevert();
      w.toWad(a);
    } else {
      assertEq(w.toWad(a), a * w.WAD());
      assertEq(w.toWad(a), b);
    }
  }

  function test_bpsToRay_fuzz(uint256 a) public {
    uint256 b;
    bool safetyCheck;
    unchecked {
      b = a * w.RAY();
      safetyCheck = b / w.RAY() == a;
    }
    if (!safetyCheck) {
      vm.expectRevert();
      w.bpsToRay(a);
    } else {
      assertEq(w.bpsToRay(a), (a * w.RAY()) / 100_00);
      assertEq(w.bpsToRay(a), b / 100_00);
    }
  }
}
