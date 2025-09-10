// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Multicall} from 'src/misc/Multicall.sol';
import {SignatureCheckerLib} from 'src/dependencies/solady/SignatureCheckerLib.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

contract InstantDelegator is EIP712, Multicall {
  ISpoke public immutable SPOKE;

  error InvalidSignature();

  bytes32 public constant SUPPLY_TYPEHASH =
    keccak256(
      'Supply(uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant WITHDRAW_TYPEHASH =
    keccak256(
      'Withdraw(uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant BORROW_TYPEHASH =
    keccak256(
      'Borrow(uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant REPAY_TYPEHASH =
    keccak256(
      'Repay(uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
    );

  mapping(address user => uint256 nonce) internal _nonces;

  constructor(address spoke_) {
    assert(spoke_ != address(0));
    SPOKE = ISpoke(spoke_);
  }

  function supplyWithSig(
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
          address(SPOKE),
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
    SPOKE.supply(reserveId, amount, onBehalfOf);
  }

  function withdrawWithSig(
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
          address(SPOKE),
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
    SPOKE.withdraw(reserveId, amount, onBehalfOf);
  }

  function borrowWithSig(
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
          address(SPOKE),
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
    SPOKE.borrow(reserveId, amount, onBehalfOf);
  }

  function repayWithSig(
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
          address(SPOKE),
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
    SPOKE.repay(reserveId, amount, onBehalfOf);
  }

  function setSelfAsUserPositionManager(bool approve) external {
    (bool ok, ) = address(SPOKE).delegatecall(
      abi.encodeCall(ISpoke.setUserPositionManager, (address(this), approve))
    );
    assert(ok);
  }

  function setSelfAsUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    SPOKE.setUserPositionManagerWithSig(address(this), user, approve, deadline, v, r, s);
  }

  function renounceSelfAsUserPositionManager(address user) external {
    SPOKE.renouncePositionManagerRole(user);
  }

  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
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
