// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {WadRayMathWrapper, WadRayMathExtendedWrapper} from 'tests/mocks/WadRayMathWrapper.sol';

contract WadRayMathTests is Test {
  WadRayMathWrapper internal w;

  function setUp() public {
    w = new WadRayMathWrapper();
  }

  function test_constants() public view {
    assertEq(w.WAD(), 1e18, 'wad');
    assertEq(w.HALF_WAD(), 1e18 / 2, 'half wad');
    assertEq(w.RAY(), 1e27, 'ray');
    assertEq(w.HALF_RAY(), 1e27 / 2, 'half_ray');
  }

  function test_wadMul_edge() public view {
    assertEq(w.wadMul(0, 1e18), 0);
    assertEq(w.wadMul(1e18, 0), 0);
    assertEq(w.wadMul(0, 0), 0);
  }

  function test_wadMul_fuzz(uint256 a, uint256 b) public {
    if ((b == 0 || (a > (type(uint256).max - w.HALF_WAD()) / b) == false) == false) {
      vm.expectRevert();
      w.wadMul(a, b);
      return;
    }

    assertEq(w.wadMul(a, b), ((a * b) + w.HALF_WAD()) / w.WAD());
  }

  function test_wadDiv_fuzz(uint256 a, uint256 b) public {
    if ((b == 0) || (((a > ((type(uint256).max - b / 2) / w.WAD())) == false) == false)) {
      vm.expectRevert();
      w.wadDiv(a, b);
      return;
    }

    assertEq(w.wadDiv(a, b), ((a * w.WAD()) + (b / 2)) / b);
  }

  function test_wadMul() public view {
    assertEq(w.wadMul(2.5e18, 0.5e18), 1.25e18);
    assertEq(w.wadMul(412.2e18, 1e18), 412.2e18);
    assertEq(w.wadMul(6e18, 2e18), 12e18);
  }

  function test_rayMul() public view {
    assertEq(w.rayMul(2.5e27, 0.5e27), 1.25e27);
    assertEq(w.rayMul(412.2e27, 1e27), 412.2e27);
    assertEq(w.rayMul(6e27, 2e27), 12e27);
  }

  function test_wadDiv() public view {
    assertEq(w.wadDiv(2.5e18, 0.5e18), 5e18);
    assertEq(w.wadDiv(412.2e18, 1e18), 412.2e18);
    assertEq(w.wadDiv(8.745e18, 0.67e18), 13.052238805970149254e18);
    assertEq(w.wadDiv(6e18, 2e18), 3e18);
  }

  function test_rayDiv() public view {
    assertEq(w.rayDiv(2.5e27, 0.5e27), 5e27);
    assertEq(w.rayDiv(412.2e27, 1e27), 412.2e27);
    assertEq(w.rayDiv(8.745e27, 0.67e27), 13.052238805970149253731343284e27);
    assertEq(w.rayDiv(6e27, 2e27), 3e27);
  }

  function test_wadToRay() public view {
    assertEq(w.wadToRay(1e18), 1e27);
    assertEq(w.wadToRay(412.2e18), 412.2e27);
    assertEq(w.wadToRay(0), 0);
  }

  function test_rayToWad() public view {
    assertEq(w.rayToWad(1e27), 1e18);
    assertEq(w.rayToWad(412.2e27), 412.2e18);
    assertEq(w.rayToWad(0), 0);
  }

  function test_wadToRay_fuzz(uint256 a) public {
    uint256 b;
    bool safetyCheck;
    unchecked {
      b = a * w.WAD_RAY_RATIO();
      safetyCheck = b / w.WAD_RAY_RATIO() == a;
    }
    if (!safetyCheck) {
      vm.expectRevert();
      w.wadToRay(a);
    } else {
      assertEq(w.wadToRay(a), a * w.WAD_RAY_RATIO());
      assertEq(w.wadToRay(a), b);
    }
  }

  function test_rayToWad_fuzz(uint256 a) public view {
    uint256 b;
    uint256 remainder;
    bool roundHalf;
    unchecked {
      b = a / w.WAD_RAY_RATIO();
      remainder = a % w.WAD_RAY_RATIO();
      roundHalf = remainder < w.WAD_RAY_RATIO() / 2;
    }
    if (!roundHalf) {
      assertEq(w.rayToWad(a), (a / w.WAD_RAY_RATIO()) + 1);
      assertEq(w.rayToWad(a), b + 1);
    } else {
      assertEq(w.rayToWad(a), a / w.WAD_RAY_RATIO());
      assertEq(w.rayToWad(a), b);
    }
  }

  function test_rayify_fuzz(uint256 a) public {
    uint256 b;
    bool safetyCheck;
    unchecked {
      b = a * w.RAY();
      safetyCheck = b / w.RAY() == a;
    }
    if (!safetyCheck) {
      vm.expectRevert();
      w.rayify(a);
    } else {
      assertEq(w.rayify(a), a * w.RAY());
      assertEq(w.rayify(a), b);
    }
  }

  function test_derayify_fuzz(uint256 a) public {
    assertEq(w.derayify(a), a / w.RAY());
  }
}

contract WadRayMathExtendedDifferentialTests is Test {
  WadRayMathWrapper internal w;
  WadRayMathExtendedWrapper internal wExtended;

  function setUp() public {
    w = new WadRayMathWrapper();
    wExtended = new WadRayMathExtendedWrapper();
  }

  function test_fuzz_wadMul(uint256 a, uint256 b) public {
    // overflow case
    if (!(b == 0 || !(a > type(uint256).max / b))) {
      vm.expectRevert();
      wExtended.wadMulDown(a, b);
      vm.expectRevert();
      wExtended.wadMulUp(a, b);
    } else {
      assertEq(wExtended.wadMulDown(a, b), (a * b) / w.WAD());
      assertEq(wExtended.wadMulUp(a, b), a * b == 0 ? 0 : (a * b - 1) / w.WAD() + 1);
    }

    // check against current implementation
    if (!(b == 0 || !(a > (type(uint256).max - w.HALF_WAD()) / b))) {
      vm.expectRevert();
      w.wadMul(a, b);
    } else {
      assertEq(
        w.wadMul(a, b),
        ((a * b) + w.HALF_WAD()) % w.WAD() < (a * b) % w.WAD()
          ? wExtended.wadMulUp(a, b)
          : wExtended.wadMulDown(a, b),
        'impl diff'
      );
    }
  }

  function test_fuzz_wadDiv(uint256 a, uint256 b) public {
    if (b == 0 || (a > type(uint256).max / w.WAD())) {
      vm.expectRevert();
      wExtended.wadDivDown(a, b);
      vm.expectRevert();
      wExtended.wadDivUp(a, b);

      return;
    }

    assertEq(wExtended.wadDivDown(a, b), (a * w.WAD()) / b);
    assertEq(wExtended.wadDivUp(a, b), a == 0 ? 0 : (a * w.WAD() - 1) / b + 1);

    // check against current implementation
    if (b == 0 || (a > (type(uint256).max - b / 2) / w.WAD())) {
      vm.expectRevert();
      w.wadDiv(a, b);
    } else {
      assertEq(
        w.wadDiv(a, b),
        ((a * w.WAD()) + (b / 2)) % b < (a * w.WAD()) % b
          ? wExtended.wadDivUp(a, b)
          : wExtended.wadDivDown(a, b),
        'impl diff'
      );
    }
  }

  function test_fuzz_rayMul(uint256 a, uint256 b) public {
    // overflow case
    if (!(b == 0 || !(a > type(uint256).max / b))) {
      vm.expectRevert();
      wExtended.rayMulDown(a, b);
      vm.expectRevert();
      wExtended.rayMulUp(a, b);
    } else {
      assertEq(wExtended.rayMulDown(a, b), (a * b) / w.RAY());
      assertEq(wExtended.rayMulUp(a, b), a * b == 0 ? 0 : (a * b - 1) / w.RAY() + 1);
    }

    // check against current implementation
    if (!(b == 0 || !(a > (type(uint256).max - w.HALF_RAY()) / b))) {
      vm.expectRevert();
      w.rayMul(a, b);
    } else {
      assertEq(
        w.rayMul(a, b),
        ((a * b) + w.HALF_RAY()) % w.RAY() < (a * b) % w.RAY()
          ? wExtended.rayMulUp(a, b)
          : wExtended.rayMulDown(a, b),
        'impl diff'
      );
    }
  }

  function test_fuzz_rayDiv(uint256 a, uint256 b) public {
    if (b == 0 || (a > type(uint256).max / w.RAY())) {
      vm.expectRevert();
      wExtended.rayDivDown(a, b);
      vm.expectRevert();
      wExtended.rayDivUp(a, b);

      return;
    }

    assertEq(wExtended.rayDivDown(a, b), (a * w.RAY()) / b);
    assertEq(wExtended.rayDivUp(a, b), a == 0 ? 0 : (a * w.RAY() - 1) / b + 1);

    // check against current implementation
    if (b == 0 || (a > (type(uint256).max - b / 2) / w.RAY())) {
      vm.expectRevert();
      w.rayDiv(a, b);
    } else {
      assertEq(
        w.rayDiv(a, b),
        ((a * w.RAY()) + (b / 2)) % b < (a * w.RAY()) % b
          ? wExtended.rayDivUp(a, b)
          : wExtended.rayDivDown(a, b),
        'impl diff'
      );
    }
  }

  function test_wadMul() public {
    assertEq(wExtended.wadMulDown(0, 1e18), 0);
    assertEq(wExtended.wadMulDown(1e18, 0), 0);
    assertEq(wExtended.wadMulDown(0, 0), 0);

    assertEq(wExtended.wadMulDown(2.5e18, 0.5e18), 1.25e18);
    assertEq(wExtended.wadMulDown(3e18, 1e18), 3e18);
    assertEq(wExtended.wadMulDown(369, 271), 0);
    assertEq(wExtended.wadMulDown(412.2e18, 1e18), 412.2e18);
    assertEq(wExtended.wadMulDown(6e18, 2e18), 12e18);

    assertEq(wExtended.wadMulUp(0, 1e18), 0);
    assertEq(wExtended.wadMulUp(1e18, 0), 0);
    assertEq(wExtended.wadMulUp(0, 0), 0);

    assertEq(wExtended.wadMulUp(2.5e18, 0.5e18), 1.25e18);
    assertEq(wExtended.wadMulUp(3e18, 1e18), 3e18);
    assertEq(wExtended.wadMulUp(369, 271), 1);
    assertEq(wExtended.wadMulUp(412.2e18, 1e18), 412.2e18);
    assertEq(wExtended.wadMulUp(6e18, 2e18), 12e18);
  }

  function test_rayMul() public {
    assertEq(wExtended.rayMulDown(0, 1e27), 0);
    assertEq(wExtended.rayMulDown(1e27, 0), 0);
    assertEq(wExtended.rayMulDown(0, 0), 0);

    assertEq(wExtended.rayMulDown(2.5e27, 0.5e27), 1.25e27);
    assertEq(wExtended.rayMulDown(3e27, 1e27), 3e27);
    assertEq(wExtended.rayMulDown(369, 271), 0);
    assertEq(wExtended.rayMulDown(412.2e27, 1e27), 412.2e27);
    assertEq(wExtended.rayMulDown(6e27, 2e27), 12e27);

    assertEq(wExtended.rayMulUp(0, 1e27), 0);
    assertEq(wExtended.rayMulUp(1e27, 0), 0);
    assertEq(wExtended.rayMulUp(0, 0), 0);

    assertEq(wExtended.rayMulUp(2.5e27, 0.5e27), 1.25e27);
    assertEq(wExtended.rayMulUp(3e27, 1e27), 3e27);
    assertEq(wExtended.rayMulUp(369, 271), 1);
    assertEq(wExtended.rayMulUp(412.2e27, 1e27), 412.2e27);
    assertEq(wExtended.rayMulUp(6e27, 2e27), 12e27);
  }

  function test_wadDiv() public {
    assertEq(wExtended.wadDivDown(0, 1e18), 0);
    vm.expectRevert();
    assertEq(wExtended.wadDivDown(1e18, 0), 0);
    vm.expectRevert();
    assertEq(wExtended.wadDivDown(0, 0), 0);

    assertEq(wExtended.wadDivDown(2.5e18, 0.5e18), 5e18);
    assertEq(wExtended.wadDivDown(412.2e18, 1e18), 412.2e18);
    assertEq(wExtended.wadDivDown(8.745e18, 0.67e18), 13.052238805970149253e18);
    assertEq(wExtended.wadDivDown(6e18, 2e18), 3e18);
    assertEq(wExtended.wadDivDown(1.25e18, 0.5e18), 2.5e18);
    assertEq(wExtended.wadDivDown(3e18, 1e18), 3e18);
    assertEq(wExtended.wadDivDown(2, 100000000000000e18), 0);

    assertEq(wExtended.wadDivUp(0, 1e18), 0);
    vm.expectRevert();
    assertEq(wExtended.wadDivUp(1e18, 0), 0);
    vm.expectRevert();
    assertEq(wExtended.wadDivUp(0, 0), 0);

    assertEq(wExtended.wadDivUp(2.5e18, 0.5e18), 5e18);
    assertEq(wExtended.wadDivUp(412.2e18, 1e18), 412.2e18);
    assertEq(wExtended.wadDivUp(8.745e18, 0.67e18), 13.052238805970149254e18);
    assertEq(wExtended.wadDivUp(6e18, 2e18), 3e18);
    assertEq(wExtended.wadDivUp(1.25e18, 0.5e18), 2.5e18);
    assertEq(wExtended.wadDivUp(3e18, 1e18), 3e18);
    assertEq(wExtended.wadDivUp(2, 100000000000000e18), 1);
  }

  function test_rayDiv() public {
    assertEq(wExtended.rayDivDown(0, 1e27), 0);
    vm.expectRevert();
    assertEq(wExtended.rayDivDown(1e27, 0), 0);
    vm.expectRevert();
    assertEq(wExtended.rayDivDown(0, 0), 0);

    assertEq(wExtended.rayDivDown(2.5e27, 0.5e27), 5e27);
    assertEq(wExtended.rayDivDown(412.2e27, 1e27), 412.2e27);
    assertEq(wExtended.rayDivDown(8.745e27, 0.67e27), 13.052238805970149253731343283e27);
    assertEq(wExtended.rayDivDown(6e27, 2e27), 3e27);
    assertEq(wExtended.rayDivDown(1.25e27, 0.5e27), 2.5e27);
    assertEq(wExtended.rayDivDown(3e27, 1e27), 3e27);
    assertEq(wExtended.rayDivDown(2, 100000000000000e27), 0);

    assertEq(wExtended.rayDivUp(0, 1e27), 0);
    vm.expectRevert();
    assertEq(wExtended.rayDivUp(1e27, 0), 0);
    vm.expectRevert();
    assertEq(wExtended.rayDivUp(0, 0), 0);

    assertEq(wExtended.rayDivUp(2.5e27, 0.5e27), 5e27);
    assertEq(wExtended.rayDivUp(412.2e27, 1e27), 412.2e27);
    assertEq(wExtended.rayDivUp(8.745e27, 0.67e27), 13.052238805970149253731343284e27);
    assertEq(wExtended.rayDivUp(6e27, 2e27), 3e27);
    assertEq(wExtended.rayDivUp(1.25e27, 0.5e27), 2.5e27);
    assertEq(wExtended.rayDivUp(3e27, 1e27), 3e27);
    assertEq(wExtended.rayDivUp(2, 100000000000000e27), 1);
  }

  function test_dewadify_fuzz(uint256 a) public {
    assertEq(wExtended.dewadify(a), a / wExtended.WAD());
  }

  function test_wadify_fuzz(uint256 a) public {
    uint256 b;
    bool safetyCheck;
    unchecked {
      b = a * wExtended.WAD();
      safetyCheck = b / wExtended.WAD() == a;
    }
    if (!safetyCheck) {
      vm.expectRevert();
      wExtended.wadify(a);
    } else {
      assertEq(wExtended.wadify(a), a * w.WAD());
      assertEq(wExtended.wadify(a), b);
    }
  }
}
