// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Multicall} from 'src/misc/Multicall.sol';
import {SignatureCheckerLib} from 'src/dependencies/solady/SignatureCheckerLib.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

contract InstantDelegator is EIP712, Multicall {
  error InvalidSignature();

  bytes32 public constant SUPPLY_TYPEHASH =
    keccak256(
      'Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant WITHDRAW_TYPEHASH =
    keccak256(
      'Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant BORROW_TYPEHASH =
    keccak256(
      'Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant REPAY_TYPEHASH =
    keccak256(
      'Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );

  mapping(address user => uint256 nonce) internal _nonces;

  function supplyWithSig(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          SUPPLY_TYPEHASH,
          spoke,
          reserveId,
          amount,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(
      SignatureCheckerLib.isValidSignatureNowCalldata(onBehalfOf, hash, signature),
      InvalidSignature()
    );
    ISpoke(spoke).supply(reserveId, amount, onBehalfOf);
  }

  function withdrawWithSig(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          WITHDRAW_TYPEHASH,
          spoke,
          reserveId,
          amount,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(
      SignatureCheckerLib.isValidSignatureNowCalldata(onBehalfOf, hash, signature),
      InvalidSignature()
    );
    ISpoke(spoke).withdraw(reserveId, amount, onBehalfOf);
  }

  function borrowWithSig(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          BORROW_TYPEHASH,
          spoke,
          reserveId,
          amount,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(
      SignatureCheckerLib.isValidSignatureNowCalldata(onBehalfOf, hash, signature),
      InvalidSignature()
    );
    ISpoke(spoke).borrow(reserveId, amount, onBehalfOf);
  }

  function repayWithSig(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          REPAY_TYPEHASH,
          spoke,
          reserveId,
          amount,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(
      SignatureCheckerLib.isValidSignatureNowCalldata(onBehalfOf, hash, signature),
      InvalidSignature()
    );
    ISpoke(spoke).repay(reserveId, amount, onBehalfOf);
  }

  function useNonce() external {
    _useNonce(msg.sender);
  }

  function nonces(address user) external view returns (uint256) {
    return _nonces[user];
  }

  function _useNonce(address user) internal returns (uint256) {
    unchecked {
      return _nonces[user]++;
    }
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('InstantDelegator', '1');
  }
}
