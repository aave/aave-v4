// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ITakerPositionManager} from 'src/position-manager/interfaces/ITakerPositionManager.sol';

import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';

contract PositionManagerEIP712HashTest is Test {
  using EIP712Hash for *;

  function test_constants() public pure {
    assertEq(
      EIP712Hash.SUPPLY_TYPEHASH,
      keccak256(
        'Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(EIP712Hash.SUPPLY_TYPEHASH, vm.eip712HashType('Supply'));

    assertEq(
      EIP712Hash.WITHDRAW_TYPEHASH,
      keccak256(
        'Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(EIP712Hash.WITHDRAW_TYPEHASH, vm.eip712HashType('Withdraw'));

    assertEq(
      EIP712Hash.BORROW_TYPEHASH,
      keccak256(
        'Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(EIP712Hash.BORROW_TYPEHASH, vm.eip712HashType('Borrow'));

    assertEq(
      EIP712Hash.REPAY_TYPEHASH,
      keccak256(
        'Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(EIP712Hash.REPAY_TYPEHASH, vm.eip712HashType('Repay'));

    assertEq(
      EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH,
      keccak256(
        'SetUsingAsCollateral(address spoke,uint256 reserveId,bool useAsCollateral,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH,
      vm.eip712HashType('SetUsingAsCollateral')
    );

    assertEq(
      EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH,
      keccak256(
        'UpdateUserRiskPremium(address spoke,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH,
      vm.eip712HashType('UpdateUserRiskPremium')
    );

    assertEq(
      EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
      keccak256(
        'UpdateUserDynamicConfig(address spoke,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
      vm.eip712HashType('UpdateUserDynamicConfig')
    );

    assertEq(
      EIP712Hash.WITHDRAW_PERMIT_TYPEHASH,
      keccak256(
        'WithdrawPermit(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(EIP712Hash.WITHDRAW_PERMIT_TYPEHASH, vm.eip712HashType('WithdrawPermit'));

    assertEq(
      EIP712Hash.BORROW_PERMIT_TYPEHASH,
      keccak256(
        'BorrowPermit(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(EIP712Hash.BORROW_PERMIT_TYPEHASH, vm.eip712HashType('BorrowPermit'));
  }

  // @dev all struct params should be hashed & placed in the same order as the typehash
  function test_hash_supply_fuzz(ISignatureGateway.Supply calldata params) public pure {
    bytes32 expectedHash = keccak256(abi.encode(EIP712Hash.SUPPLY_TYPEHASH, params));
    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('Supply', abi.encode(params)));
  }

  function test_hash_withdraw_fuzz(ISignatureGateway.Withdraw calldata params) public pure {
    bytes32 expectedHash = keccak256(abi.encode(EIP712Hash.WITHDRAW_TYPEHASH, params));
    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('Withdraw', abi.encode(params)));
  }

  function test_hash_borrow_fuzz(ISignatureGateway.Borrow calldata params) public pure {
    bytes32 expectedHash = keccak256(abi.encode(EIP712Hash.BORROW_TYPEHASH, params));
    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('Borrow', abi.encode(params)));
  }

  function test_hash_repay_fuzz(ISignatureGateway.Repay calldata params) public pure {
    bytes32 expectedHash = keccak256(abi.encode(EIP712Hash.REPAY_TYPEHASH, params));
    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('Repay', abi.encode(params)));
  }

  function test_hash_setUsingAsCollateral_fuzz(
    ISignatureGateway.SetUsingAsCollateral calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH, params)
    );
    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('SetUsingAsCollateral', abi.encode(params)));
  }

  function test_hash_updateUserRiskPremium_fuzz(
    ISignatureGateway.UpdateUserRiskPremium calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH, params)
    );
    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('UpdateUserRiskPremium', abi.encode(params)));
  }

  function test_hash_updateUserDynamicConfig_fuzz(
    ISignatureGateway.UpdateUserDynamicConfig calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH, params)
    );
    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('UpdateUserDynamicConfig', abi.encode(params)));
  }

  function test_hash_withdrawPermit_fuzz(
    ITakerPositionManager.WithdrawPermit calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(abi.encode(EIP712Hash.WITHDRAW_PERMIT_TYPEHASH, params));

    assertEq(params.hash(), expectedHash);
  }

  function test_hash_borrowPermit_fuzz(
    ITakerPositionManager.BorrowPermit calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(abi.encode(EIP712Hash.BORROW_PERMIT_TYPEHASH, params));

    assertEq(params.hash(), expectedHash);
  }
}
