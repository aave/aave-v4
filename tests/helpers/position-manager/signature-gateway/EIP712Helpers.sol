// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title EIP712Helpers
/// @notice EIP-712 typed data hash helpers for SignatureGateway tests.
abstract contract EIP712Helpers is Test {
  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.Supply memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Supply', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.Withdraw memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Withdraw', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.Borrow memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Borrow', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.Repay memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Repay', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.SetUsingAsCollateral memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_gateway, vm.eip712HashStruct('SetUsingAsCollateral', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.UpdateUserRiskPremium memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_gateway, vm.eip712HashStruct('UpdateUserRiskPremium', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.UpdateUserDynamicConfig memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_gateway, vm.eip712HashStruct('UpdateUserDynamicConfig', abi.encode(_params)));
  }

  function _typedDataHash(
    ISignatureGateway _gateway,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _gateway.DOMAIN_SEPARATOR(), typeHash));
  }
}
