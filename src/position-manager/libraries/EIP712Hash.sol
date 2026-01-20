// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title EIP712Hash library
/// @author Aave Labs
/// @notice Helper methods to hash EIP712 typed data structs.
library EIP712Hash {
  using EIP712Hash for *;

  bytes32 public constant SUPPLY_TYPEHASH =
    // keccak256('SupplyAction(address onBehalfOf,uint256 nonce,uint256 deadline,SupplyParams params)SupplyParams(address spoke,uint256 reserveId,uint256 amount)')
    0xbb32af8a7bebc0600e2174d08c4269abad5d0d78b18faaf394a11dfe08877e05;

  bytes32 public constant SUPPLY_PARAMS_TYPEHASH =
    // keccak256('SupplyParams(address spoke,uint256 reserveId,uint256 amount)')
    0x1b6c40592fda6c0e86066b14d06a185a879ce67373f4cd91b4fe3e33349bc0e4;

  bytes32 public constant WITHDRAW_TYPEHASH =
    // keccak256('WithdrawAction(address onBehalfOf,uint256 nonce,uint256 deadline,WithdrawParams params)WithdrawParams(address spoke,uint256 reserveId,uint256 amount)')
    0x970c03fef0ce23693f4d291532e982d4036fc1c297c8e6eb5eb8cc9e8a43c18b;

  bytes32 public constant WITHDRAW_PARAMS_TYPEHASH =
    // keccak256('WithdrawParams(address spoke,uint256 reserveId,uint256 amount)')
    0x58e75e9fd311eede04e4a3321d00361fa26e40f92d428b2f3b7112091c0860f2;

  bytes32 public constant BORROW_TYPEHASH =
    // keccak256('BorrowAction(address onBehalfOf,uint256 nonce,uint256 deadline,BorrowParams params)BorrowParams(address spoke,uint256 reserveId,uint256 amount)')
    0xdf9c4985a627692f0f61e1ff6443dd1c52c4838ad331885a379eda2b5936bbd7;

  bytes32 public constant BORROW_PARAMS_TYPEHASH =
    // keccak256('BorrowParams(address spoke,uint256 reserveId,uint256 amount)')
    0x27e94de9e568a399cf53391caca93fcca225076a0b9f458c66cd5fa6ee6ceb38;

  bytes32 public constant REPAY_TYPEHASH =
    // keccak256('RepayAction(address onBehalfOf,uint256 nonce,uint256 deadline,RepayParams params)RepayParams(address spoke,uint256 reserveId,uint256 amount)')
    0x39155913bb8fdc35112317080698e2c7eb9c24b0e32ce09f895fa123280c3aa4;

  bytes32 public constant REPAY_PARAMS_TYPEHASH =
    // keccak256('RepayParams(address spoke,uint256 reserveId,uint256 amount)')
    0x48a24fcb78882348e1291dd601640ee99f1b94a1225439c70518495fe9d1ba0f;

  bytes32 public constant SET_USING_AS_COLLATERAL_TYPEHASH =
    // keccak256('SetUsingAsCollateralAction(address onBehalfOf,uint256 nonce,uint256 deadline,SetUsingAsCollateralParams params)SetUsingAsCollateralParams(address spoke,uint256 reserveId,bool useAsCollateral)')
    0x5c7cf8b2daccf16abc5c02b884ab19466a70d693b4831cfc8bb5cfccdda53466;

  bytes32 public constant SET_USING_AS_COLLATERAL_PARAMS_TYPEHASH =
    // keccak256('SetUsingAsCollateralParams(address spoke,uint256 reserveId,bool useAsCollateral)')
    0xbeb8a283b5a625e3baa522c56742f1fd573cf67a4a5f3e8fa864d4baa30901cf;

  bytes32 public constant UPDATE_USER_RISK_PREMIUM_TYPEHASH =
    // keccak256('UpdateUserRiskPremiumAction(address user,uint256 nonce,uint256 deadline,UpdateUserRiskPremiumParams params)UpdateUserRiskPremiumParams(address spoke)')
    0x06f48accbacba38999087c808cd2206162256b5e2a1656388bbf2045ad38c55a;

  bytes32 public constant UPDATE_USER_RISK_PREMIUM_PARAMS_TYPEHASH =
    // keccak256('UpdateUserRiskPremiumParams(address spoke)')
    0xbe8b5422434fc4c91f3a5701cf247efae41407cd51fe5ea72082e9d8d2e5f83d;

  bytes32 public constant UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH =
    // keccak256('UpdateUserDynamicConfigAction(address user,uint256 nonce,uint256 deadline,UpdateUserDynamicConfigParams params)UpdateUserDynamicConfigParams(address spoke)')
    0x8b3e676fb7c7341a0fb375c2cc2f84f9a35c8090ffcc7262da10544389a08731;

  bytes32 public constant UPDATE_USER_DYNAMIC_CONFIG_PARAMS_TYPEHASH =
    // keccak256('UpdateUserDynamicConfigParams(address spoke)')
    0xbf8bd4f7648216d4e812c05faf8b3c04c9d48c630d02d868deb2ad3dc4dd45a5;

  function hash(ISignatureGateway.SupplyAction calldata action) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SUPPLY_TYPEHASH,
          action.onBehalfOf,
          action.nonce,
          action.deadline,
          action.params.hash()
        )
      );
  }

  function hash(ISignatureGateway.SupplyParams calldata params) internal pure returns (bytes32) {
    return
      keccak256(abi.encode(SUPPLY_PARAMS_TYPEHASH, params.spoke, params.reserveId, params.amount));
  }

  function hash(ISignatureGateway.WithdrawAction calldata action) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          WITHDRAW_TYPEHASH,
          action.onBehalfOf,
          action.nonce,
          action.deadline,
          action.params.hash()
        )
      );
  }

  function hash(ISignatureGateway.WithdrawParams calldata params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(WITHDRAW_PARAMS_TYPEHASH, params.spoke, params.reserveId, params.amount)
      );
  }

  function hash(ISignatureGateway.BorrowAction calldata action) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          BORROW_TYPEHASH,
          action.onBehalfOf,
          action.nonce,
          action.deadline,
          action.params.hash()
        )
      );
  }

  function hash(ISignatureGateway.BorrowParams calldata params) internal pure returns (bytes32) {
    return
      keccak256(abi.encode(BORROW_PARAMS_TYPEHASH, params.spoke, params.reserveId, params.amount));
  }

  function hash(ISignatureGateway.RepayAction calldata action) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          REPAY_TYPEHASH,
          action.onBehalfOf,
          action.nonce,
          action.deadline,
          action.params.hash()
        )
      );
  }

  function hash(ISignatureGateway.RepayParams calldata params) internal pure returns (bytes32) {
    return
      keccak256(abi.encode(REPAY_PARAMS_TYPEHASH, params.spoke, params.reserveId, params.amount));
  }

  function hash(
    ISignatureGateway.SetUsingAsCollateralAction calldata action
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SET_USING_AS_COLLATERAL_TYPEHASH,
          action.onBehalfOf,
          action.nonce,
          action.deadline,
          action.params.hash()
        )
      );
  }

  function hash(
    ISignatureGateway.SetUsingAsCollateralParams calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SET_USING_AS_COLLATERAL_PARAMS_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.useAsCollateral
        )
      );
  }

  function hash(
    ISignatureGateway.UpdateUserRiskPremiumAction calldata action
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          UPDATE_USER_RISK_PREMIUM_TYPEHASH,
          action.user,
          action.nonce,
          action.deadline,
          action.params.hash()
        )
      );
  }

  function hash(
    ISignatureGateway.UpdateUserRiskPremiumParams calldata params
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(UPDATE_USER_RISK_PREMIUM_PARAMS_TYPEHASH, params.spoke));
  }

  function hash(
    ISignatureGateway.UpdateUserDynamicConfigAction calldata action
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
          action.user,
          action.nonce,
          action.deadline,
          action.params.hash()
        )
      );
  }

  function hash(
    ISignatureGateway.UpdateUserDynamicConfigParams calldata params
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(UPDATE_USER_DYNAMIC_CONFIG_PARAMS_TYPEHASH, params.spoke));
  }
}
