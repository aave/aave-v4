// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {EIP712Hash, EIP712Types} from 'src/position-manager/libraries/EIP712Hash.sol';

contract EIP712HashTest is Test {
  using EIP712Hash for *;

  function test_constants() public pure {
    assertEq(
      EIP712Hash.SUPPLY_TYPEHASH,
      keccak256(
        'Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      EIP712Hash.WITHDRAW_TYPEHASH,
      keccak256(
        'Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      EIP712Hash.BORROW_TYPEHASH,
      keccak256(
        'Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      EIP712Hash.REPAY_TYPEHASH,
      keccak256(
        'Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH,
      keccak256(
        'SetUsingAsCollateral(address spoke,uint256 reserveId,bool useAsCollateral,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH,
      keccak256('UpdateUserRiskPremium(address spoke,address user,uint256 nonce,uint256 deadline)')
    );
    assertEq(
      EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
      keccak256(
        'UpdateUserDynamicConfig(address spoke,address user,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_hash_supply_fuzz(EIP712Types.Supply calldata params) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        EIP712Hash.SUPPLY_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.amount,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
  }

  function test_hash_withdraw_fuzz(EIP712Types.Withdraw calldata params) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        EIP712Hash.WITHDRAW_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.amount,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
  }

  function test_hash_borrow_fuzz(EIP712Types.Borrow calldata params) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        EIP712Hash.BORROW_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.amount,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
  }

  function test_hash_repay_fuzz(EIP712Types.Repay calldata params) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        EIP712Hash.REPAY_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.amount,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
  }

  function test_hash_setUsingAsCollateral_fuzz(
    EIP712Types.SetUsingAsCollateral calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.useAsCollateral,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
  }

  function test_hash_updateUserRiskPremium_fuzz(
    EIP712Types.UpdateUserRiskPremium calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH,
        params.spoke,
        params.user,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
  }

  function test_hash_updateUserDynamicConfig_fuzz(
    EIP712Types.UpdateUserDynamicConfig calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
        params.spoke,
        params.user,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
  }
}
