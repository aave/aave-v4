// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Test} from 'forge-std/Test.sol';

interface IForwarder {
  function forward(address target, bytes calldata data) external returns (bytes memory);
  function capture(address target, bytes calldata data) external returns (bool, bytes memory);
  function static_forward(address target, bytes calldata data) external view returns (bytes memory);
  function delegate_forward(address target, bytes calldata data) external returns (bytes memory);
  function via_internal(address target, bytes calldata data) external returns (bytes memory);
  function bounded_widened(address target, bytes calldata data) external returns (bytes memory);
  function bounded_capture(address target, bytes calldata data) external returns (bool, bytes memory);
  function two_calls(address target, bytes calldata first, bytes calldata second) external returns (bytes memory, bytes memory);
}

contract RawTarget {
  function raw(bytes calldata value, bool fail) external pure {
    assembly {
      calldatacopy(0, value.offset, value.length)
      if fail { revert(0, value.length) }
      return(0, value.length)
    }
  }
  function context() external view returns (address, address) {
    return (address(this), msg.sender);
  }
}

contract GasProbe {
  function measure(IForwarder f, address target, bytes calldata input) external returns (uint256 used, bytes memory result) {
    f.forward(target, input);
    uint256 start = gasleft();
    result = f.forward(target, input);
    used = start - gasleft();
  }
}

contract PR5271Test is Test {
  IForwarder forwarder;
  RawTarget target;
  function setUp() public {
    forwarder = IForwarder(vm.deployCode('Forwarder.vy:Forwarder'));
    target = new RawTarget();
  }
  function payload(uint256 n) internal pure returns (bytes memory result) {
    result = new bytes(n);
    for (uint256 i; i < n; ++i) result[i] = bytes1(uint8((i * 37 + 11) % 256));
  }
  function success(uint256 n) internal {
    bytes memory expected = payload(n);
    bytes memory callData = abi.encodeCall(RawTarget.raw, (expected, false));
    assertEq(forwarder.forward(address(target), callData), expected);
    assertEq(forwarder.static_forward(address(target), callData), expected);
    assertEq(forwarder.delegate_forward(address(target), callData), expected);
    assertEq(forwarder.via_internal(address(target), callData), expected);
    (bool ok, bytes memory data) = forwarder.capture(address(target), callData);
    assertTrue(ok);
    assertEq(data, expected);
    (ok, data) = address(forwarder).call(abi.encodeCall(IForwarder.forward, (address(target), callData)));
    assertTrue(ok);
    assertEq(data, abi.encode(expected));
    (ok, data) = address(forwarder).call(abi.encodeCall(IForwarder.capture, (address(target), callData)));
    assertTrue(ok);
    assertEq(data, abi.encode(true, expected));
  }
  function failure(uint256 n) internal {
    bytes memory expected = payload(n);
    bytes memory callData = abi.encodeCall(RawTarget.raw, (expected, true));
    (bool ok, bytes memory data) = forwarder.capture(address(target), callData);
    assertFalse(ok);
    assertEq(data, expected);
    (ok, data) = address(forwarder).call(abi.encodeCall(IForwarder.forward, (address(target), callData)));
    assertFalse(ok);
    assertEq(data, expected);
  }
  function test_successBoundaries() public {
    uint256[12] memory sizes = [uint256(0),1,31,32,33,255,256,257,32767,32768,32769,65537];
    for (uint256 i; i < sizes.length; ++i) success(sizes[i]);
  }
  function test_failureBoundaries() public {
    uint256[6] memory sizes = [uint256(0),1,33,257,32769,65537];
    for (uint256 i; i < sizes.length; ++i) failure(sizes[i]);
  }
  function testFuzz_success(uint256 n) public { success(bound(n, 0, 65537)); }
  function testFuzz_failure(uint256 n) public { failure(bound(n, 0, 65537)); }
  function test_twoLiveBuffers() public {
    bytes memory a = payload(32769);
    bytes memory b = payload(33);
    (bytes memory x, bytes memory y) = forwarder.two_calls(address(target), abi.encodeCall(RawTarget.raw, (a, false)), abi.encodeCall(RawTarget.raw, (b, false)));
    assertEq(x, a);
    assertEq(y, b);
  }
  function test_delegateContext() public {
    (address self, address sender) = abi.decode(forwarder.delegate_forward(address(target), abi.encodeCall(RawTarget.context, ())), (address,address));
    assertEq(self, address(forwarder));
    assertEq(sender, address(this));
  }
  function test_boundedOutputRemainsBounded() public {
    bytes memory value = payload(65537);
    bytes memory expected = payload(32);
    assertEq(forwarder.bounded_widened(address(target), abi.encodeCall(RawTarget.raw, (value, false))), expected);
    (bool ok, bytes memory data) = forwarder.bounded_capture(address(target), abi.encodeCall(RawTarget.raw, (value, true)));
    assertFalse(ok);
    assertEq(data, expected);
  }
  function test_gasByReturnSize() public {
    IForwarder bounded = IForwarder(vm.deployCode('Bounded.vy:Bounded'));
    IForwarder unbounded = IForwarder(vm.deployCode('Unbounded.vy:Unbounded'));
    GasProbe probe = new GasProbe();
    uint256[6] memory sizes = [uint256(0),32,256,4096,32768,32769];
    for (uint256 i; i < sizes.length; ++i) {
      bytes memory expected = payload(sizes[i]);
      bytes memory callData = abi.encodeCall(RawTarget.raw, (expected, false));
      (uint256 boundedGas, bytes memory b) = probe.measure(bounded, address(target), callData);
      (uint256 unboundedGas, bytes memory u) = probe.measure(unbounded, address(target), callData);
      assertEq(u, expected);
      assertEq(b.length, sizes[i] > 32768 ? 32768 : sizes[i]);
      emit log_named_uint('return bytes', sizes[i]);
      emit log_named_uint('bounded call gas', boundedGas);
      emit log_named_uint('unbounded call gas', unboundedGas);
    }
  }
  function test_unusedSiblingMemoryCoupling() public {
    IForwarder unbounded = IForwarder(vm.deployCode('Unbounded.vy:Unbounded'));
    IForwarder coupled = IForwarder(vm.deployCode('Coupled.vy:Coupled'));
    GasProbe probe = new GasProbe();
    bytes memory expected = payload(32);
    bytes memory callData = abi.encodeCall(RawTarget.raw, (expected, false));
    (uint256 smallGas, bytes memory small) = probe.measure(unbounded, address(target), callData);
    (uint256 coupledGas, bytes memory big) = probe.measure(coupled, address(target), callData);
    assertEq(small, expected);
    assertEq(big, expected);
    assertGt(coupledGas, smallGas);
    emit log_named_uint('32-byte unbounded call gas', smallGas);
    emit log_named_uint('same call with unused bounded sibling', coupledGas);
  }
}
