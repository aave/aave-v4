// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {TypedSignatureGateway, ITypedSignatureGateway} from 'src/misc/TypedSignatureGateway.sol';

contract TypedSignatureGatewayBaseTest is Base {
  ITypedSignatureGateway public gateway;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    gateway = ITypedSignatureGateway(new TypedSignatureGateway(address(spoke1)));
    (alice, alicePk) = makeAddrAndKey('alice');
  }

  /**
   * @dev Warps after to a random time after a randomly generated deadline.
   * @return The randomly generated deadline.
   */
  function _warpAfterRandomDeadline() internal returns (uint256) {
    uint256 deadline = vm.randomUint(0, MAX_SKIP_TIME - 1);
    vm.warp(vm.randomUint(deadline + 1, MAX_SKIP_TIME));
    return deadline;
  }

  /**
   * @dev Warps to a random time before a randomly generated deadline.
   * @return The randomly generated deadline.
   */
  function _warpUntilRandomDeadline() internal returns (uint256) {
    uint256 deadline = vm.randomUint(1, MAX_SKIP_TIME);
    vm.warp(vm.randomUint(0, deadline - 1));
    return deadline;
  }

  function _consumeRandomNonces(address user) internal {
    uint256 count = vm.randomUint(1, 100);
    while (--count > 0) {
      vm.prank(user);
      gateway.useNonce();
    }
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    return abi.encodePacked(r, s, v);
  }

  function _randomReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(0, spoke.getReserveCount() - 1);
  }

  function _supplyData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Supply memory) {
    return
      EIP712Types.Supply({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(alice),
        deadline: deadline
      });
  }

  function _withdrawData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Withdraw memory) {
    return
      EIP712Types.Withdraw({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(alice),
        deadline: deadline
      });
  }

  function _borrowData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Borrow memory) {
    return
      EIP712Types.Borrow({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(alice),
        deadline: deadline
      });
  }

  function _repayData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Repay memory) {
    return
      EIP712Types.Repay({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(alice),
        deadline: deadline
      });
  }

  function _getTypedDataHash(
    ITypedSignatureGateway _gateway,
    EIP712Types.Supply memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Supply', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ITypedSignatureGateway _gateway,
    EIP712Types.Withdraw memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Withdraw', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ITypedSignatureGateway _gateway,
    EIP712Types.Borrow memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Borrow', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ITypedSignatureGateway _gateway,
    EIP712Types.Repay memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Repay', abi.encode(_params)));
  }

  function _typedDataHash(
    ITypedSignatureGateway _gateway,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _gateway.DOMAIN_SEPARATOR(), typeHash));
  }

  function _hub(ISpoke spoke, uint256 reserveId) internal view returns (IHub) {
    return IHub(spoke.getReserve(reserveId).hub);
  }

  function _assetId(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
    return spoke.getReserve(reserveId).assetId;
  }
}
