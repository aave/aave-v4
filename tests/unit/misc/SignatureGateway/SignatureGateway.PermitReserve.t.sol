// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGatewayPermitReserveTest is SignatureGatewayBaseTest {
  function test_permitReserve_revertsWith_InvalidReserveId() public {
    uint256 unlistedReserveId = vm.randomUint(spoke1.getReserveCount() + 1, UINT256_MAX);
    vm.expectRevert(ISignatureGateway.InvalidReserveId.selector);
    vm.prank(vm.randomAddress());
    gateway.permitReserve(
      unlistedReserveId,
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );
  }

  function test_permitReserve_forwards_correct_call() public {
    uint256 reserveId = _randomReserveId(spoke1);
    address owner = vm.randomAddress();
    address spender = address(gateway);
    uint256 value = vm.randomUint();
    uint256 deadline = vm.randomUint();
    uint8 v = uint8(vm.randomUint());
    bytes32 r = bytes32(vm.randomUint());
    bytes32 s = bytes32(vm.randomUint());

    vm.expectCall(
      address(_underlying(spoke1, reserveId)),
      abi.encodeCall(TestnetERC20.permit, (owner, spender, value, deadline, v, r, s)),
      1
    );
    vm.prank(vm.randomAddress());
    gateway.permitReserve(reserveId, owner, value, deadline, v, r, s);
  }

  function test_permitReserve_ignores_permit_reverts() public {
    uint256 reserveId = _randomReserveId(spoke1);
    address token = address(_underlying(spoke1, reserveId));

    vm.mockCallRevert(token, TestnetERC20.permit.selector, vm.randomBytes(64));

    vm.prank(vm.randomAddress());
    gateway.permitReserve(
      reserveId,
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );
  }

  function test_permitReserve() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    uint256 reserveId = _randomReserveId(spoke1);
    TestnetERC20 token = TestnetERC20(address(_underlying(spoke1, reserveId)));

    assertEq(token.allowance(user, address(gateway)), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(gateway),
      value: 100e18,
      deadline: _warpBeforeRandomDeadline(),
      nonce: token.nonces(user)
    });

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(token, params));

    vm.expectEmit(address(token));
    emit IERC20.Approval(user, address(gateway), params.value);
    vm.prank(vm.randomAddress());
    gateway.permitReserve(reserveId, user, params.value, params.deadline, v, r, s);

    assertEq(token.allowance(user, address(gateway)), params.value);
  }
}
