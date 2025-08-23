// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokePermitReserveTest is SpokeBase {
  function test_permitReserve_revertsWith_ReserveNotListed() public {
    uint256 unlistedReserveId = vm.randomUint(spoke1.getReserveCount() + 1, UINT256_MAX);
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(vm.randomAddress());
    spoke1.permitReserve(
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
    uint256 reserveId = _daiReserveId(spoke1);
    address owner = vm.randomAddress();
    address spender = address(getReserveInfo(spoke1, reserveId).hub);
    uint256 value = vm.randomUint();
    uint256 deadline = vm.randomUint();
    uint8 v = uint8(vm.randomUint());
    bytes32 r = bytes32(vm.randomUint());
    bytes32 s = bytes32(vm.randomUint());

    vm.expectCall(
      address(tokenList.dai),
      abi.encodeCall(TestnetERC20.permit, (owner, spender, value, deadline, v, r, s)),
      1
    );
    vm.prank(vm.randomAddress());
    spoke1.permitReserve(reserveId, owner, value, deadline, v, r, s);
  }

  function test_permitReserve_ignores_permit_reverts() public {
    vm.mockCallRevert(address(tokenList.dai), TestnetERC20.permit.selector, vm.randomBytes(64));

    vm.prank(vm.randomAddress());
    spoke1.permitReserve(
      _daiReserveId(spoke1),
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
    uint256 reserveId = _daiReserveId(spoke1);
    address hub = address(getReserveInfo(spoke1, reserveId).hub);

    assertEq(tokenList.dai.allowance(user, hub), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: hub,
      value: 100e18,
      deadline: vm.randomUint(1, MAX_SKIP_TIME),
      nonce: tokenList.dai.nonces(user)
    });
    vm.warp(params.deadline - 1);

    bytes32 digest = _getTypedDataHash(tokenList.dai, params);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Approval(user, hub, params.value);
    vm.prank(vm.randomAddress());
    spoke1.permitReserve(_daiReserveId(spoke1), user, params.value, params.deadline, v, r, s);

    assertEq(tokenList.dai.allowance(user, hub), params.value);
  }
}
