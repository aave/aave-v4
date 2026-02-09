// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title EIP712Hash library
/// @author Aave Labs
/// @notice Helper methods to hash EIP712 typed data structs.
library EIP712Hash {
  bytes32 public constant SUPPLY_TYPEHASH =
    // keccak256('Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0xe85497eb293c001e8483fe105efadd1d50aa0dadfc0570b27058031dfceab2e6;

  bytes32 public constant WITHDRAW_TYPEHASH =
    // keccak256('Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0x0bc73eb58cf4068a29b9593ef18c0d26b3b4453bd2155424a90cb26a22f41d7f;

  bytes32 public constant BORROW_TYPEHASH =
    // keccak256('Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0xe248895a233688ba2a70b6f560472dbc27e35ece0d86914f7d43bf2f7df8025b;

  bytes32 public constant REPAY_TYPEHASH =
    // keccak256('Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0xd23fe99a7aac398d03952a098faa8889259d062784bd80ea0f159e4af604c045;

  bytes32 public constant SET_USING_AS_COLLATERAL_TYPEHASH =
    // keccak256('SetUsingAsCollateral(address spoke,uint256 reserveId,bool useAsCollateral,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0xd4350e1f25ecd62a35b50e8cd1e00bc34331ae8c728ee4dbb69ecf1023daecf7;

  bytes32 public constant UPDATE_USER_RISK_PREMIUM_TYPEHASH =
    // keccak256('UpdateUserRiskPremium(address spoke,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0x915106098e3eee1fbe90aebcbfd68e931c539495af63e24066ebeebb638d3023;

  bytes32 public constant UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH =
    // keccak256('UpdateUserDynamicConfig(address spoke,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0x4a168dd8b32d260d07d6f0be832e23035a65a47f788675b0b02270c68b987886;

  function hash(ISignatureGateway.Supply calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SUPPLY_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.amount,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(ISignatureGateway.Withdraw calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          WITHDRAW_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.amount,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(ISignatureGateway.Borrow calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          BORROW_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.amount,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(ISignatureGateway.Repay calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          REPAY_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.amount,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    ISignatureGateway.SetUsingAsCollateral calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SET_USING_AS_COLLATERAL_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.useAsCollateral,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    ISignatureGateway.UpdateUserRiskPremium calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          UPDATE_USER_RISK_PREMIUM_TYPEHASH,
          params.spoke,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    ISignatureGateway.UpdateUserDynamicConfig calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
          params.spoke,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }
}
