// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

import {EIP712Hash as PositionManagerEIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {EIP712Hash as SpokeEIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';

contract EIP712HashTest is Test {
  using PositionManagerEIP712Hash for *;
  using SpokeEIP712Hash for *;

  function test_constants() public pure {
    assertEq(
      PositionManagerEIP712Hash.SUPPLY_TYPEHASH,
      keccak256(
        'Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(PositionManagerEIP712Hash.SUPPLY_TYPEHASH, vm.eip712HashType('Supply'));

    assertEq(
      PositionManagerEIP712Hash.WITHDRAW_TYPEHASH,
      keccak256(
        'Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(PositionManagerEIP712Hash.WITHDRAW_TYPEHASH, vm.eip712HashType('Withdraw'));

    assertEq(
      PositionManagerEIP712Hash.BORROW_TYPEHASH,
      keccak256(
        'Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(PositionManagerEIP712Hash.BORROW_TYPEHASH, vm.eip712HashType('Borrow'));

    assertEq(
      PositionManagerEIP712Hash.REPAY_TYPEHASH,
      keccak256(
        'Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(PositionManagerEIP712Hash.REPAY_TYPEHASH, vm.eip712HashType('Repay'));

    assertEq(
      PositionManagerEIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH,
      keccak256(
        'SetUsingAsCollateral(address spoke,uint256 reserveId,bool useAsCollateral,address onBehalfOf,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      PositionManagerEIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH,
      vm.eip712HashType('SetUsingAsCollateral')
    );

    assertEq(
      PositionManagerEIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH,
      keccak256('UpdateUserRiskPremium(address spoke,address user,uint256 nonce,uint256 deadline)')
    );
    assertEq(
      PositionManagerEIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH,
      vm.eip712HashType('UpdateUserRiskPremium')
    );

    assertEq(
      PositionManagerEIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
      keccak256(
        'UpdateUserDynamicConfig(address spoke,address user,uint256 nonce,uint256 deadline)'
      )
    );
    assertEq(
      PositionManagerEIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
      vm.eip712HashType('UpdateUserDynamicConfig')
    );

    assertEq(
      SpokeEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      keccak256(
        'SetUserPositionManagers(address user,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)'
      )
    );
    assertEq(
      SpokeEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      vm.eip712HashType('SetUserPositionManagers')
    );

    assertEq(
      SpokeEIP712Hash.POSITION_MANAGER_UPDATE,
      keccak256('PositionManagerUpdate(address positionManager,bool approve)')
    );
    assertEq(SpokeEIP712Hash.POSITION_MANAGER_UPDATE, vm.eip712HashType('PositionManagerUpdate'));
  }

  function test_hash_supply_fuzz(ISignatureGateway.Supply calldata params) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        PositionManagerEIP712Hash.SUPPLY_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.amount,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('Supply', abi.encode(params)));
  }

  function test_hash_withdraw_fuzz(ISignatureGateway.Withdraw calldata params) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        PositionManagerEIP712Hash.WITHDRAW_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.amount,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('Withdraw', abi.encode(params)));
  }

  function test_hash_borrow_fuzz(ISignatureGateway.Borrow calldata params) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        PositionManagerEIP712Hash.BORROW_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.amount,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('Borrow', abi.encode(params)));
  }

  function test_hash_repay_fuzz(ISignatureGateway.Repay calldata params) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        PositionManagerEIP712Hash.REPAY_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.amount,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('Repay', abi.encode(params)));
  }

  function test_hash_setUsingAsCollateral_fuzz(
    ISignatureGateway.SetUsingAsCollateral calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        PositionManagerEIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH,
        params.spoke,
        params.reserveId,
        params.useAsCollateral,
        params.onBehalfOf,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('SetUsingAsCollateral', abi.encode(params)));
  }

  function test_hash_updateUserRiskPremium_fuzz(
    ISignatureGateway.UpdateUserRiskPremium calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        PositionManagerEIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH,
        params.spoke,
        params.user,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('UpdateUserRiskPremium', abi.encode(params)));
  }

  function test_hash_updateUserDynamicConfig_fuzz(
    ISignatureGateway.UpdateUserDynamicConfig calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(
        PositionManagerEIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
        params.spoke,
        params.user,
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('UpdateUserDynamicConfig', abi.encode(params)));
  }

  function test_hash_setUserPositionManagers_fuzz(
    ISpoke.SetUserPositionManagers calldata params
  ) public pure {
    bytes32[] memory updatesHashes = new bytes32[](params.updates.length);
    for (uint256 i = 0; i < updatesHashes.length; ++i) {
      updatesHashes[i] = params.updates[i].hash();
    }

    bytes32 expectedHash = keccak256(
      abi.encode(
        SpokeEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
        params.user,
        keccak256(abi.encodePacked(updatesHashes)),
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('SetUserPositionManagers', abi.encode(params)));
  }

  function test_hash_positionManagerUpdate_fuzz(
    ISpoke.PositionManagerUpdate calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(SpokeEIP712Hash.POSITION_MANAGER_UPDATE, params.positionManager, params.approve)
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('PositionManagerUpdate', abi.encode(params)));
  }
}
