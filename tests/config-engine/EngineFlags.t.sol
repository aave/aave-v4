// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

/// @dev Wrapper to call EngineFlags library functions externally so vm.expectRevert works.
contract EngineFlagsHarness {
  function toBool(uint256 flag) external pure returns (bool) {
    return EngineFlags.toBool(flag);
  }

  function fromBool(bool value) external pure returns (uint256) {
    return EngineFlags.fromBool(value);
  }
}

contract EngineFlagsTest is Test {
  EngineFlagsHarness internal _harness;

  function setUp() public {
    _harness = vm.envOr('TEST_VYPER', false)
      ? EngineFlagsHarness(vm.deployCode('EngineFlagsHarness.vy:EngineFlagsHarness'))
      : new EngineFlagsHarness();
  }

  function test_toBool_zero_returnsFalse() public view {
    assertFalse(_harness.toBool(0));
  }

  function test_toBool_one_returnsTrue() public view {
    assertTrue(_harness.toBool(1));
  }

  function test_toBool_revertsOnInvalidValue() public {
    vm.expectRevert(abi.encodeWithSelector(EngineFlags.InvalidBoolValue.selector, 2));
    _harness.toBool(2);
  }

  function test_fuzz_toBool_revertsOnInvalidValue(uint256 value) public {
    vm.assume(value > 1 && value < type(uint256).max);
    vm.expectRevert(abi.encodeWithSelector(EngineFlags.InvalidBoolValue.selector, value));
    _harness.toBool(value);
  }

  function test_toBool_revertsOnMax() public {
    vm.expectRevert(
      abi.encodeWithSelector(EngineFlags.InvalidBoolValue.selector, type(uint256).max)
    );
    _harness.toBool(type(uint256).max);
  }

  function test_fuzz_toBool_revertsOnInvalid(uint256 value) public {
    vm.assume(value > 1);
    vm.expectRevert(abi.encodeWithSelector(EngineFlags.InvalidBoolValue.selector, value));
    _harness.toBool(value);
  }

  function test_fromBool_false_returnsDisabled() public view {
    assertEq(_harness.fromBool(false), EngineFlags.DISABLED);
  }

  function test_fromBool_true_returnsEnabled() public view {
    assertEq(_harness.fromBool(true), EngineFlags.ENABLED);
  }

  function test_fuzz_fromBool(bool value) public view {
    uint256 result = _harness.fromBool(value);
    if (value) {
      assertEq(result, EngineFlags.ENABLED);
    } else {
      assertEq(result, EngineFlags.DISABLED);
    }
  }

  function test_roundtrip_toBool_fromBool() public view {
    assertEq(_harness.fromBool(_harness.toBool(0)), EngineFlags.DISABLED);
    assertEq(_harness.fromBool(_harness.toBool(1)), EngineFlags.ENABLED);
  }

  function test_constants() public pure {
    assertEq(EngineFlags.KEEP_CURRENT, type(uint256).max - 652);
    assertEq(EngineFlags.KEEP_CURRENT_ADDRESS, address(type(uint160).max));
    assertEq(EngineFlags.KEEP_CURRENT_UINT64, type(uint64).max - 46);
    assertEq(EngineFlags.KEEP_CURRENT_UINT32, type(uint32).max - 23);
    assertEq(EngineFlags.KEEP_CURRENT_UINT16, type(uint16).max - 61);
    assertEq(EngineFlags.ENABLED, 1);
    assertEq(EngineFlags.DISABLED, 0);
  }
}
