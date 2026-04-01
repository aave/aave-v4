// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {Test} from 'forge-std/Test.sol';

contract EIP712HashTest is Test {
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
}
