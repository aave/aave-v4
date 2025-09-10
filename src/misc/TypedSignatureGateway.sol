// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SignatureCheckerLib} from 'src/dependencies/solady/SignatureCheckerLib.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {Multicall} from 'src/misc/Multicall.sol';
import {ITypedSignatureGateway} from 'src/interfaces/ITypedSignatureGateway.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

contract TypedSignatureGateway is EIP712, Multicall, ITypedSignatureGateway {
  // @inheritdoc ITypedSignatureGateway
  ISpoke public immutable SPOKE;

  // @inheritdoc ITypedSignatureGateway
  bytes32 public constant SUPPLY_TYPEHASH =
    0xe85497eb293c001e8483fe105efadd1d50aa0dadfc0570b27058031dfceab2e6; // keccak256('Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)');
  // @inheritdoc ITypedSignatureGateway
  bytes32 public constant WITHDRAW_TYPEHASH =
    0x0bc73eb58cf4068a29b9593ef18c0d26b3b4453bd2155424a90cb26a22f41d7f; // keccak256('Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)');
  // @inheritdoc ITypedSignatureGateway
  bytes32 public constant BORROW_TYPEHASH =
    0xe248895a233688ba2a70b6f560472dbc27e35ece0d86914f7d43bf2f7df8025b; // keccak256('Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)');
  // @inheritdoc ITypedSignatureGateway
  bytes32 public constant REPAY_TYPEHASH =
    0xd23fe99a7aac398d03952a098faa8889259d062784bd80ea0f159e4af604c045; // keccak256('Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)');

  mapping(address user => uint256 nonce) internal _nonces;

  constructor(address spoke_) {
    assert(spoke_ != address(0));
    SPOKE = ISpoke(spoke_);
  }

  // @inheritdoc ITypedSignatureGateway
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

  // @inheritdoc ITypedSignatureGateway
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

  // @inheritdoc ITypedSignatureGateway
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

  // @inheritdoc ITypedSignatureGateway
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

  // @inheritdoc ITypedSignatureGateway
  function setSelfAsUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    bytes calldata signature
  ) external {
    SPOKE.setUserPositionManagerWithSig(address(this), user, approve, deadline, signature);
  }

  // @inheritdoc ITypedSignatureGateway
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    SPOKE.permitReserve(reserveId, onBehalfOf, value, deadline, v, r, s);
  }

  // @inheritdoc ITypedSignatureGateway
  function renounceSelfAsUserPositionManager(address user) external {
    SPOKE.renouncePositionManagerRole(user);
  }

  // @inheritdoc ITypedSignatureGateway
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  // @inheritdoc ITypedSignatureGateway
  function useNonce() external {
    _useNonce(msg.sender);
  }

  // @inheritdoc ITypedSignatureGateway
  function nonces(address user) external view returns (uint256) {
    return _nonces[user];
  }

  function _useNonce(address user) internal returns (uint256) {
    unchecked {
      return _nonces[user]++;
    }
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('TypedSignatureGateway', '1');
  }
}
