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

  function test_constants_supplyTypehash() public pure {
    assertEq(PositionManagerEIP712Hash.SUPPLY_TYPEHASH, vm.eip712HashType('SupplyAction'));
  }

  function test_constants_supplyParamsTypehash() public pure {
    assertEq(PositionManagerEIP712Hash.SUPPLY_PARAMS_TYPEHASH, vm.eip712HashType('SupplyParams'));
  }

  function test_constants_withdrawTypehash() public pure {
    assertEq(PositionManagerEIP712Hash.WITHDRAW_TYPEHASH, vm.eip712HashType('WithdrawAction'));
  }

  function test_constants_withdrawParamsTypehash() public pure {
    assertEq(
      PositionManagerEIP712Hash.WITHDRAW_PARAMS_TYPEHASH,
      vm.eip712HashType('WithdrawParams')
    );
  }

  function test_constants_borrowTypehash() public pure {
    assertEq(PositionManagerEIP712Hash.BORROW_TYPEHASH, vm.eip712HashType('BorrowAction'));
  }

  function test_constants_borrowParamsTypehash() public pure {
    assertEq(PositionManagerEIP712Hash.BORROW_PARAMS_TYPEHASH, vm.eip712HashType('BorrowParams'));
  }

  function test_constants_repayTypehash() public pure {
    assertEq(PositionManagerEIP712Hash.REPAY_TYPEHASH, vm.eip712HashType('RepayAction'));
  }

  function test_constants_repayParamsTypehash() public pure {
    assertEq(PositionManagerEIP712Hash.REPAY_PARAMS_TYPEHASH, vm.eip712HashType('RepayParams'));
  }

  function test_constants_setUsingAsCollateralTypehash() public pure {
    assertEq(
      PositionManagerEIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH,
      vm.eip712HashType('SetUsingAsCollateralAction')
    );
  }

  function test_constants_setUsingAsCollateralParamsTypehash() public pure {
    assertEq(
      PositionManagerEIP712Hash.SET_USING_AS_COLLATERAL_PARAMS_TYPEHASH,
      vm.eip712HashType('SetUsingAsCollateralParams')
    );
  }

  function test_constants_updateUserRiskPremiumTypehash() public pure {
    assertEq(
      PositionManagerEIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH,
      vm.eip712HashType('UpdateUserRiskPremiumAction')
    );
  }

  function test_constants_updateUserRiskPremiumParamsTypehash() public pure {
    assertEq(
      PositionManagerEIP712Hash.UPDATE_USER_RISK_PREMIUM_PARAMS_TYPEHASH,
      vm.eip712HashType('UpdateUserRiskPremiumParams')
    );
  }

  function test_constants_updateUserDynamicConfigTypehash() public pure {
    assertEq(
      PositionManagerEIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
      vm.eip712HashType('UpdateUserDynamicConfigAction')
    );
  }

  function test_constants_updateUserDynamicConfigParamsTypehash() public pure {
    assertEq(
      PositionManagerEIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_PARAMS_TYPEHASH,
      vm.eip712HashType('UpdateUserDynamicConfigParams')
    );
  }

  function test_constants_setUserPositionManagersTypehash() public pure {
    assertEq(
      SpokeEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      vm.eip712HashType('SetUserPositionManagers')
    );
  }

  function test_constants_positionManagerUpdateTypehash() public pure {
    assertEq(SpokeEIP712Hash.POSITION_MANAGER_UPDATE, vm.eip712HashType('PositionManagerUpdate'));
  }

  function test_hash_supplyAction_fuzz(ISignatureGateway.SupplyAction calldata action) public pure {
    assertEq(action.hash(), vm.eip712HashStruct('SupplyAction', abi.encode(action)));
  }

  function test_hash_supplyParams_fuzz(ISignatureGateway.SupplyParams calldata params) public pure {
    assertEq(params.hash(), vm.eip712HashStruct('SupplyParams', abi.encode(params)));
  }

  function test_hash_withdrawAction_fuzz(
    ISignatureGateway.WithdrawAction calldata action
  ) public pure {
    assertEq(action.hash(), vm.eip712HashStruct('WithdrawAction', abi.encode(action)));
  }

  function test_hash_withdrawParams_fuzz(
    ISignatureGateway.WithdrawParams calldata params
  ) public pure {
    assertEq(params.hash(), vm.eip712HashStruct('WithdrawParams', abi.encode(params)));
  }

  function test_hash_borrowAction_fuzz(ISignatureGateway.BorrowAction calldata action) public pure {
    assertEq(action.hash(), vm.eip712HashStruct('BorrowAction', abi.encode(action)));
  }

  function test_hash_borrowParams_fuzz(ISignatureGateway.BorrowParams calldata params) public pure {
    assertEq(params.hash(), vm.eip712HashStruct('BorrowParams', abi.encode(params)));
  }

  function test_hash_repayAction_fuzz(ISignatureGateway.RepayAction calldata action) public pure {
    assertEq(action.hash(), vm.eip712HashStruct('RepayAction', abi.encode(action)));
  }

  function test_hash_repayParams_fuzz(ISignatureGateway.RepayParams calldata params) public pure {
    assertEq(params.hash(), vm.eip712HashStruct('RepayParams', abi.encode(params)));
  }

  function test_hash_setUsingAsCollateralAction_fuzz(
    ISignatureGateway.SetUsingAsCollateralAction calldata action
  ) public pure {
    assertEq(action.hash(), vm.eip712HashStruct('SetUsingAsCollateralAction', abi.encode(action)));
  }

  function test_hash_setUsingAsCollateralParams_fuzz(
    ISignatureGateway.SetUsingAsCollateralParams calldata params
  ) public pure {
    assertEq(params.hash(), vm.eip712HashStruct('SetUsingAsCollateralParams', abi.encode(params)));
  }

  function test_hash_updateUserRiskPremiumAction_fuzz(
    ISignatureGateway.UpdateUserRiskPremiumAction calldata action
  ) public pure {
    assertEq(action.hash(), vm.eip712HashStruct('UpdateUserRiskPremiumAction', abi.encode(action)));
  }

  function test_hash_updateUserRiskPremiumParams_fuzz(
    ISignatureGateway.UpdateUserRiskPremiumParams calldata params
  ) public pure {
    assertEq(params.hash(), vm.eip712HashStruct('UpdateUserRiskPremiumParams', abi.encode(params)));
  }

  function test_hash_updateUserDynamicConfigAction_fuzz(
    ISignatureGateway.UpdateUserDynamicConfigAction calldata action
  ) public pure {
    assertEq(
      action.hash(),
      vm.eip712HashStruct('UpdateUserDynamicConfigAction', abi.encode(action))
    );
  }

  function test_hash_updateUserDynamicConfigParams_fuzz(
    ISignatureGateway.UpdateUserDynamicConfigParams calldata params
  ) public pure {
    assertEq(
      params.hash(),
      vm.eip712HashStruct('UpdateUserDynamicConfigParams', abi.encode(params))
    );
  }

  function test_hash_setUserPositionManagers_fuzz(
    ISpoke.SetUserPositionManagers calldata params
  ) public pure {
    assertEq(params.hash(), vm.eip712HashStruct('SetUserPositionManagers', abi.encode(params)));
  }

  function test_hash_positionManagerUpdate_fuzz(
    ISpoke.PositionManagerUpdate calldata params
  ) public pure {
    assertEq(params.hash(), vm.eip712HashStruct('PositionManagerUpdate', abi.encode(params)));
  }
}
