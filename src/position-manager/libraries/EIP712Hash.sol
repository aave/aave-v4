// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.20;

import {IConfigPositionManager} from 'src/position-manager/interfaces/IConfigPositionManager.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ITakerPositionManager} from 'src/position-manager/interfaces/ITakerPositionManager.sol';

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

  bytes32 public constant WITHDRAW_PERMIT_TYPEHASH =
    // keccak256('WithdrawPermit(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)')
    0x9e6642fd4c06a4c1a5e201f1e41c6b7892fcf06859c796b054c510b80e2a0a3f;

  bytes32 public constant BORROW_PERMIT_TYPEHASH =
    // keccak256('BorrowPermit(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)')
    0x14236ea048da65ffb52a9b32a2c840f24ab374cc31f65faeb7877d22ceca144e;

  bytes32 public constant SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH =
    // keccak256('SetGlobalPermissionPermit(address spoke,address delegator,address delegatee,bool permission,uint256 nonce,uint256 deadline)')
    0x468edc8a22a4686863c6b8a79342e76c578e93ea7d28606606acd95e2ffc4d53;

  bytes32 public constant SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH =
    // keccak256('SetCanSetUsingAsCollateralPermissionPermit(address spoke,address delegator,address delegatee,bool permission,uint256 nonce,uint256 deadline)')
    0x26244f8fd59210a303a35d34ec9efc9cdb15e142b8093aa0a97b185d8533f1db;

  bytes32 public constant SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH =
    // keccak256('SetCanUpdateUserRiskPremiumPermissionPermit(address spoke,address delegator,address delegatee,bool permission,uint256 nonce,uint256 deadline)')
    0xce16a7f069cf522ce3ad86420662e3bd8d13dc7883379dfe72865440fc6e4434;

  bytes32 public constant SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH =
    // keccak256('SetCanUpdateUserDynamicConfigPermissionPermit(address spoke,address delegator,address delegatee,bool permission,uint256 nonce,uint256 deadline)')
    0xa00e492b4ed483e810de8f2015cc1603a01e1245be610157d5bcb7c64974c053;

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

  function hash(
    ITakerPositionManager.WithdrawPermit calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          WITHDRAW_PERMIT_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.owner,
          params.spender,
          params.amount,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    ITakerPositionManager.BorrowPermit calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          BORROW_PERMIT_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.owner,
          params.spender,
          params.amount,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    IConfigPositionManager.SetGlobalPermissionPermit calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH,
          params.spoke,
          params.delegator,
          params.delegatee,
          params.permission,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH,
          params.spoke,
          params.delegator,
          params.delegatee,
          params.permission,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH,
          params.spoke,
          params.delegator,
          params.delegatee,
          params.permission,
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH,
          params.spoke,
          params.delegator,
          params.delegatee,
          params.permission,
          params.nonce,
          params.deadline
        )
      );
  }
}
