// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {BatchEIP712} from 'src/position-manager/libraries/BatchEIP712.sol';

contract BatchEIP712Test is Test {
  function test_constants_supplyParamsTypehash() public pure {
    assertEq(BatchEIP712.SUPPLY_PARAMS_TYPEHASH, vm.eip712HashType('SupplyParams'));
  }

  function test_constants_withdrawParamsTypehash() public pure {
    assertEq(BatchEIP712.WITHDRAW_PARAMS_TYPEHASH, vm.eip712HashType('WithdrawParams'));
  }

  function test_constants_borrowParamsTypehash() public pure {
    assertEq(BatchEIP712.BORROW_PARAMS_TYPEHASH, vm.eip712HashType('BorrowParams'));
  }

  function test_constants_repayParamsTypehash() public pure {
    assertEq(BatchEIP712.REPAY_PARAMS_TYPEHASH, vm.eip712HashType('RepayParams'));
  }

  function test_constants_setUsingAsCollateralParamsTypehash() public pure {
    assertEq(
      BatchEIP712.SET_USING_AS_COLLATERAL_PARAMS_TYPEHASH,
      vm.eip712HashType('SetUsingAsCollateralParams')
    );
  }

  function test_constants_updateUserRiskPremiumParamsTypehash() public pure {
    assertEq(
      BatchEIP712.UPDATE_USER_RISK_PREMIUM_PARAMS_TYPEHASH,
      vm.eip712HashType('UpdateUserRiskPremiumParams')
    );
  }

  function test_constants_updateUserDynamicConfigParamsTypehash() public pure {
    assertEq(
      BatchEIP712.UPDATE_USER_DYNAMIC_CONFIG_PARAMS_TYPEHASH,
      vm.eip712HashType('UpdateUserDynamicConfigParams')
    );
  }

  function test_buildBatchTypeString_singleSupply() public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(SupplyParams action0,address onBehalfOf,uint256 nonce,uint256 deadline)SupplyParams(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_singleWithdraw() public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Withdraw);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(WithdrawParams action0,address onBehalfOf,uint256 nonce,uint256 deadline)WithdrawParams(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_singleBorrow() public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Borrow);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(BorrowParams action0,address onBehalfOf,uint256 nonce,uint256 deadline)BorrowParams(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_singleRepay() public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Repay);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(RepayParams action0,address onBehalfOf,uint256 nonce,uint256 deadline)RepayParams(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_singleSetUsingAsCollateral() public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(SetUsingAsCollateralParams action0,address onBehalfOf,uint256 nonce,uint256 deadline)SetUsingAsCollateralParams(address spoke,uint256 reserveId,bool useAsCollateral)'
    );
  }

  function test_buildBatchTypeString_singleUpdateUserRiskPremium() public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(UpdateUserRiskPremiumParams action0,address onBehalfOf,uint256 nonce,uint256 deadline)UpdateUserRiskPremiumParams(address spoke)'
    );
  }

  function test_buildBatchTypeString_singleUpdateUserDynamicConfig() public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(UpdateUserDynamicConfigParams action0,address onBehalfOf,uint256 nonce,uint256 deadline)UpdateUserDynamicConfigParams(address spoke)'
    );
  }

  function test_buildBatchTypeString_supplyWithdraw() public pure {
    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(SupplyParams action0,WithdrawParams action1,address onBehalfOf,uint256 nonce,uint256 deadline)SupplyParams(address spoke,uint256 reserveId,uint256 amount)WithdrawParams(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_borrowRepay() public pure {
    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Borrow);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Repay);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(BorrowParams action0,RepayParams action1,address onBehalfOf,uint256 nonce,uint256 deadline)BorrowParams(address spoke,uint256 reserveId,uint256 amount)RepayParams(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_duplicateActions() public pure {
    uint8[] memory actionTypes = new uint8[](3);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[2] = uint8(ISignatureGateway.ActionType.Withdraw);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(SupplyParams action0,SupplyParams action1,WithdrawParams action2,address onBehalfOf,uint256 nonce,uint256 deadline)SupplyParams(address spoke,uint256 reserveId,uint256 amount)WithdrawParams(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_allActionsAlphabeticalOrder() public pure {
    uint8[] memory actionTypes = new uint8[](7);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);
    actionTypes[2] = uint8(ISignatureGateway.ActionType.Borrow);
    actionTypes[3] = uint8(ISignatureGateway.ActionType.Repay);
    actionTypes[4] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);
    actionTypes[5] = uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium);
    actionTypes[6] = uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);

    string
      memory expected = 'Batch(SupplyParams action0,WithdrawParams action1,BorrowParams action2,RepayParams action3,SetUsingAsCollateralParams action4,UpdateUserRiskPremiumParams action5,UpdateUserDynamicConfigParams action6,address onBehalfOf,uint256 nonce,uint256 deadline)BorrowParams(address spoke,uint256 reserveId,uint256 amount)RepayParams(address spoke,uint256 reserveId,uint256 amount)SetUsingAsCollateralParams(address spoke,uint256 reserveId,bool useAsCollateral)SupplyParams(address spoke,uint256 reserveId,uint256 amount)UpdateUserDynamicConfigParams(address spoke)UpdateUserRiskPremiumParams(address spoke)WithdrawParams(address spoke,uint256 reserveId,uint256 amount)';
    assertEq(typeString, expected);
  }

  function test_buildBatchTypeHash_matchesKeccak() public pure {
    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes32 typeHash = BatchEIP712.buildBatchTypeHash(actionTypes);
    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);

    assertEq(typeHash, keccak256(bytes(typeString)));
  }

  function test_hashAction_supply_fuzz(ISignatureGateway.SupplyParams calldata params) public pure {
    bytes memory actionData = abi.encode(params);
    bytes32 libHash = BatchEIP712.hashAction(
      uint8(ISignatureGateway.ActionType.Supply),
      actionData
    );

    assertEq(libHash, vm.eip712HashStruct('SupplyParams', abi.encode(params)));
  }

  function test_hashAction_withdraw_fuzz(
    ISignatureGateway.WithdrawParams calldata params
  ) public pure {
    bytes memory actionData = abi.encode(params);
    bytes32 libHash = BatchEIP712.hashAction(
      uint8(ISignatureGateway.ActionType.Withdraw),
      actionData
    );

    assertEq(libHash, vm.eip712HashStruct('WithdrawParams', abi.encode(params)));
  }

  function test_hashAction_borrow_fuzz(ISignatureGateway.BorrowParams calldata params) public pure {
    bytes memory actionData = abi.encode(params);
    bytes32 libHash = BatchEIP712.hashAction(
      uint8(ISignatureGateway.ActionType.Borrow),
      actionData
    );

    assertEq(libHash, vm.eip712HashStruct('BorrowParams', abi.encode(params)));
  }

  function test_hashAction_repay_fuzz(ISignatureGateway.RepayParams calldata params) public pure {
    bytes memory actionData = abi.encode(params);
    bytes32 libHash = BatchEIP712.hashAction(uint8(ISignatureGateway.ActionType.Repay), actionData);

    assertEq(libHash, vm.eip712HashStruct('RepayParams', abi.encode(params)));
  }

  function test_hashAction_setUsingAsCollateral_fuzz(
    ISignatureGateway.SetUsingAsCollateralParams calldata params
  ) public pure {
    bytes memory actionData = abi.encode(params);
    bytes32 libHash = BatchEIP712.hashAction(
      uint8(ISignatureGateway.ActionType.SetUsingAsCollateral),
      actionData
    );

    assertEq(libHash, vm.eip712HashStruct('SetUsingAsCollateralParams', abi.encode(params)));
  }

  function test_hashAction_updateUserRiskPremium_fuzz(
    ISignatureGateway.UpdateUserRiskPremiumParams calldata params
  ) public pure {
    bytes memory actionData = abi.encode(params);
    bytes32 libHash = BatchEIP712.hashAction(
      uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium),
      actionData
    );

    assertEq(libHash, vm.eip712HashStruct('UpdateUserRiskPremiumParams', abi.encode(params)));
  }

  function test_hashAction_updateUserDynamicConfig_fuzz(
    ISignatureGateway.UpdateUserDynamicConfigParams calldata params
  ) public pure {
    bytes memory actionData = abi.encode(params);
    bytes32 libHash = BatchEIP712.hashAction(
      uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig),
      actionData
    );

    assertEq(libHash, vm.eip712HashStruct('UpdateUserDynamicConfigParams', abi.encode(params)));
  }

  function test_hashBatch_singleSupply_fuzz(
    ISignatureGateway.SupplyParams calldata params,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(params);

    bytes32 libHash = BatchEIP712.hashBatch(actionTypes, actionData, onBehalfOf, nonce, deadline);

    bytes32 typeHash = BatchEIP712.buildBatchTypeHash(actionTypes);
    bytes32 paramsHash = vm.eip712HashStruct('SupplyParams', abi.encode(params));
    bytes32 expected = keccak256(
      bytes.concat(abi.encode(typeHash), abi.encode(paramsHash, onBehalfOf, nonce, deadline))
    );

    assertEq(libHash, expected);
  }

  function test_hashBatch_supplyWithdraw_fuzz(
    ISignatureGateway.SupplyParams calldata supplyParams,
    ISignatureGateway.WithdrawParams calldata withdrawParams,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) public pure {
    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(supplyParams);
    actionData[1] = abi.encode(withdrawParams);

    bytes32 libHash = BatchEIP712.hashBatch(actionTypes, actionData, onBehalfOf, nonce, deadline);

    bytes32 typeHash = BatchEIP712.buildBatchTypeHash(actionTypes);
    bytes32 supplyHash = vm.eip712HashStruct('SupplyParams', abi.encode(supplyParams));
    bytes32 withdrawHash = vm.eip712HashStruct('WithdrawParams', abi.encode(withdrawParams));
    bytes32 expected = keccak256(
      bytes.concat(
        abi.encode(typeHash),
        abi.encode(supplyHash),
        abi.encode(withdrawHash),
        abi.encode(onBehalfOf, nonce, deadline)
      )
    );

    assertEq(libHash, expected);
  }

  function test_hashBatch_borrowRepay_fuzz(
    ISignatureGateway.BorrowParams calldata borrowParams,
    ISignatureGateway.RepayParams calldata repayParams,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) public pure {
    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Borrow);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Repay);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(borrowParams);
    actionData[1] = abi.encode(repayParams);

    bytes32 libHash = BatchEIP712.hashBatch(actionTypes, actionData, onBehalfOf, nonce, deadline);

    bytes32 typeHash = BatchEIP712.buildBatchTypeHash(actionTypes);
    bytes32 borrowHash = vm.eip712HashStruct('BorrowParams', abi.encode(borrowParams));
    bytes32 repayHash = vm.eip712HashStruct('RepayParams', abi.encode(repayParams));
    bytes32 expected = keccak256(
      bytes.concat(
        abi.encode(typeHash),
        abi.encode(borrowHash),
        abi.encode(repayHash),
        abi.encode(onBehalfOf, nonce, deadline)
      )
    );

    assertEq(libHash, expected);
  }

  function test_hashBatch_threeActions_fuzz(
    ISignatureGateway.SupplyParams calldata supplyParams,
    ISignatureGateway.RepayParams calldata repayParams,
    ISignatureGateway.SetUsingAsCollateralParams calldata collateralParams,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) public pure {
    uint8[] memory actionTypes = new uint8[](3);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Repay);
    actionTypes[2] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);

    bytes[] memory actionData = new bytes[](3);
    actionData[0] = abi.encode(supplyParams);
    actionData[1] = abi.encode(repayParams);
    actionData[2] = abi.encode(collateralParams);

    bytes32 libHash = BatchEIP712.hashBatch(actionTypes, actionData, onBehalfOf, nonce, deadline);

    bytes32 typeHash = BatchEIP712.buildBatchTypeHash(actionTypes);
    bytes32 supplyHash = vm.eip712HashStruct('SupplyParams', abi.encode(supplyParams));
    bytes32 repayHash = vm.eip712HashStruct('RepayParams', abi.encode(repayParams));
    bytes32 collateralHash = vm.eip712HashStruct(
      'SetUsingAsCollateralParams',
      abi.encode(collateralParams)
    );
    bytes32 expected = keccak256(
      bytes.concat(
        abi.encode(typeHash),
        abi.encode(supplyHash),
        abi.encode(repayHash),
        abi.encode(collateralHash),
        abi.encode(onBehalfOf, nonce, deadline)
      )
    );

    assertEq(libHash, expected);
  }

  function test_hashBatch_duplicateSupply_fuzz(
    ISignatureGateway.SupplyParams calldata supply1,
    ISignatureGateway.SupplyParams calldata supply2,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) public pure {
    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(supply1);
    actionData[1] = abi.encode(supply2);

    bytes32 libHash = BatchEIP712.hashBatch(actionTypes, actionData, onBehalfOf, nonce, deadline);

    bytes32 typeHash = BatchEIP712.buildBatchTypeHash(actionTypes);
    bytes32 supply1Hash = vm.eip712HashStruct('SupplyParams', abi.encode(supply1));
    bytes32 supply2Hash = vm.eip712HashStruct('SupplyParams', abi.encode(supply2));
    bytes32 expected = keccak256(
      bytes.concat(
        abi.encode(typeHash),
        abi.encode(supply1Hash),
        abi.encode(supply2Hash),
        abi.encode(onBehalfOf, nonce, deadline)
      )
    );

    assertEq(libHash, expected);
  }

  function test_hashAction_revertsOnInvalidActionType() public {
    bytes memory actionData = abi.encode(address(0), uint256(0), uint256(0));
    vm.expectRevert(abi.encodeWithSelector(BatchEIP712.InvalidActionType.selector, 255));
    this.externalHashAction(255, actionData);
  }

  function externalHashAction(
    uint8 actionType,
    bytes memory actionData
  ) external pure returns (bytes32) {
    return BatchEIP712.hashAction(actionType, actionData);
  }
}
