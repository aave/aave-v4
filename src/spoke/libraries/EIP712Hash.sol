// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IVaultSpoke} from 'src/spoke/interfaces/IVaultSpoke.sol';

/// @title EIP712Hash library
/// @author Aave Labs
/// @notice Helper methods to hash EIP712 typed data structs.
library EIP712Hash {
  using EIP712Hash for *;

  bytes32 public constant SET_USER_POSITION_MANAGERS_TYPEHASH =
    // keccak256('SetUserPositionManagers(address user,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)')
    0xa9a500485f4e7c738838a1c065fe46501b5a92142c290f6a51aa56f61810c5b0;

  bytes32 public constant POSITION_MANAGER_UPDATE =
    // keccak256('PositionManagerUpdate(address positionManager,bool approve)')
    0x187dbd227227274b90655fb4011fc21dd749e8966fc040bd91e0b92609202565;

  bytes32 public constant VAULT_DEPOSIT_TYPEHASH =
    // keccak256('VaultDeposit(address depositor,uint256 assets,address receiver,uint256 nonce,uint256 deadline)')
    0x8e93b8e8149376c7ae7fb14ab6815d5cab2d1f72a9284c1dd9c9110ef06d1b75;

  bytes32 public constant VAULT_MINT_TYPEHASH =
    // keccak256('VaultMint(address depositor,uint256 shares,address receiver,uint256 nonce,uint256 deadline)')
    0xc9777aa8e2687ff2ee6bf1c3cd14300a96bd425d4d1cb69e1155f5b8ecdf05d2;

  bytes32 public constant VAULT_WITHDRAW_TYPEHASH =
    // keccak256('VaultWithdraw(address owner,uint256 assets,address receiver,uint256 nonce,uint256 deadline)')
    0x8575f76be3d57d8fc8f537e04c7e5bea275ef41afb95c3dc53b43d4fc2e43545;

  bytes32 public constant VAULT_REDEEM_TYPEHASH =
    // keccak256('VaultRedeem(address owner,uint256 shares,address receiver,uint256 nonce,uint256 deadline)')
    0x78b72753239783411f44a6ae16b7cc070aa270bf9328e0afd1ea709e5e6ab4ea;

  bytes32 public constant PERMIT_TYPEHASH =
    // keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)')
    0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

  function hash(ISpoke.SetUserPositionManagers calldata params) internal pure returns (bytes32) {
    bytes32[] memory updatesHashes = new bytes32[](params.updates.length);
    for (uint256 i = 0; i < updatesHashes.length; ++i) {
      updatesHashes[i] = params.updates[i].hash();
    }
    return
      keccak256(
        abi.encode(
          SET_USER_POSITION_MANAGERS_TYPEHASH,
          params.user,
          keccak256(abi.encodePacked(updatesHashes)),
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(ISpoke.PositionManagerUpdate calldata params) internal pure returns (bytes32) {
    return keccak256(abi.encode(POSITION_MANAGER_UPDATE, params.positionManager, params.approve));
  }

  function hash(IVaultSpoke.VaultDeposit calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          VAULT_DEPOSIT_TYPEHASH,
          params.depositor,
          params.assets,
          params.receiver,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(IVaultSpoke.VaultMint calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          VAULT_MINT_TYPEHASH,
          params.depositor,
          params.shares,
          params.receiver,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(IVaultSpoke.VaultWithdraw calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          VAULT_WITHDRAW_TYPEHASH,
          params.owner,
          params.assets,
          params.receiver,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(IVaultSpoke.VaultRedeem calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          VAULT_REDEEM_TYPEHASH,
          params.owner,
          params.shares,
          params.receiver,
          params.nonce,
          params.deadline
        )
      );
  }
}
