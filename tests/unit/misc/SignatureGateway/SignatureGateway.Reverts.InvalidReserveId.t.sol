// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGateway_InvalidReserveId_Test is SignatureGatewayBaseTest {
  function test_supplyWithSig_revertsWith_InvalidReserveId() public {
    EIP712Types.Supply memory p = _supplyData(spoke1, alice, _warpUntilRandomDeadline());
    p.reserveId = _randomInvalidReserveId(spoke1);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISignatureGateway.InvalidReserveId.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, alice, p.deadline, signature);
  }

  function test_repayWithSig_revertsWith_InvalidReserveId() public {
    EIP712Types.Repay memory p = _repayData(spoke1, alice, _warpUntilRandomDeadline());
    p.reserveId = _randomInvalidReserveId(spoke1);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISignatureGateway.InvalidReserveId.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, alice, p.deadline, signature);
  }

  // withdraw, borrow revert earlier at Spoke

  function test_permitReserve_revertsWith_InvalidReserveId() public {
    uint256 reserveId = _randomInvalidReserveId(spoke1);
    vm.expectRevert(ISignatureGateway.InvalidReserveId.selector);
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
}
