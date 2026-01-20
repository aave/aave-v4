// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title BatchEIP712 library
/// @author Aave Labs
/// @notice Helper methods to construct dynamic EIP-712 type strings and hash batch actions.
/// @dev Constructs type strings at runtime to maintain full wallet UX visibility for batch signing.
library BatchEIP712 {
  error InvalidActionType(uint8 actionType);

  string internal constant SUPPLY_PARAMS_NAME = 'SupplyParams';
  string internal constant WITHDRAW_PARAMS_NAME = 'WithdrawParams';
  string internal constant BORROW_PARAMS_NAME = 'BorrowParams';
  string internal constant REPAY_PARAMS_NAME = 'RepayParams';
  string internal constant SET_USING_AS_COLLATERAL_PARAMS_NAME = 'SetUsingAsCollateralParams';
  string internal constant UPDATE_USER_RISK_PREMIUM_PARAMS_NAME = 'UpdateUserRiskPremiumParams';
  string internal constant UPDATE_USER_DYNAMIC_CONFIG_PARAMS_NAME = 'UpdateUserDynamicConfigParams';

  string internal constant BORROW_PARAMS_DEF =
    'BorrowParams(address spoke,uint256 reserveId,uint256 amount)';
  string internal constant REPAY_PARAMS_DEF =
    'RepayParams(address spoke,uint256 reserveId,uint256 amount)';
  string internal constant SET_USING_AS_COLLATERAL_PARAMS_DEF =
    'SetUsingAsCollateralParams(address spoke,uint256 reserveId,bool useAsCollateral)';
  string internal constant SUPPLY_PARAMS_DEF =
    'SupplyParams(address spoke,uint256 reserveId,uint256 amount)';
  string internal constant UPDATE_USER_DYNAMIC_CONFIG_PARAMS_DEF =
    'UpdateUserDynamicConfigParams(address spoke)';
  string internal constant UPDATE_USER_RISK_PREMIUM_PARAMS_DEF =
    'UpdateUserRiskPremiumParams(address spoke)';
  string internal constant WITHDRAW_PARAMS_DEF =
    'WithdrawParams(address spoke,uint256 reserveId,uint256 amount)';

  bytes32 internal constant SUPPLY_PARAMS_TYPEHASH =
    // keccak256('SupplyParams(address spoke,uint256 reserveId,uint256 amount)')
    0x1b6c40592fda6c0e86066b14d06a185a879ce67373f4cd91b4fe3e33349bc0e4;

  bytes32 internal constant WITHDRAW_PARAMS_TYPEHASH =
    // keccak256('WithdrawParams(address spoke,uint256 reserveId,uint256 amount)')
    0x58e75e9fd311eede04e4a3321d00361fa26e40f92d428b2f3b7112091c0860f2;

  bytes32 internal constant BORROW_PARAMS_TYPEHASH =
    // keccak256('BorrowParams(address spoke,uint256 reserveId,uint256 amount)')
    0x27e94de9e568a399cf53391caca93fcca225076a0b9f458c66cd5fa6ee6ceb38;

  bytes32 internal constant REPAY_PARAMS_TYPEHASH =
    // keccak256('RepayParams(address spoke,uint256 reserveId,uint256 amount)')
    0x48a24fcb78882348e1291dd601640ee99f1b94a1225439c70518495fe9d1ba0f;

  bytes32 internal constant SET_USING_AS_COLLATERAL_PARAMS_TYPEHASH =
    // keccak256('SetUsingAsCollateralParams(address spoke,uint256 reserveId,bool useAsCollateral)')
    0xbeb8a283b5a625e3baa522c56742f1fd573cf67a4a5f3e8fa864d4baa30901cf;

  bytes32 internal constant UPDATE_USER_RISK_PREMIUM_PARAMS_TYPEHASH =
    // keccak256('UpdateUserRiskPremiumParams(address spoke)')
    0xbe8b5422434fc4c91f3a5701cf247efae41407cd51fe5ea72082e9d8d2e5f83d;

  bytes32 internal constant UPDATE_USER_DYNAMIC_CONFIG_PARAMS_TYPEHASH =
    // keccak256('UpdateUserDynamicConfigParams(address spoke)')
    0xbf8bd4f7648216d4e812c05faf8b3c04c9d48c630d02d868deb2ad3dc4dd45a5;

  bytes internal constant ACTION_FIELD_PREFIX = ' action';
  bytes internal constant FIELD_SEPARATOR = ',';

  bytes internal constant BATCH_PREFIX = 'Batch(';
  bytes internal constant BATCH_SUFFIX = 'address onBehalfOf,uint256 nonce,uint256 deadline)';

  /// @notice Build the batch type hash from an array of action types.
  /// @dev Constructs the type string dynamically and returns its keccak256 hash.
  /// @param actionTypes Array of action type enum values.
  /// @return The keccak256 hash of the constructed type string.
  function buildBatchTypeHash(uint8[] memory actionTypes) internal pure returns (bytes32) {
    return keccak256(bytes(buildBatchTypeString(actionTypes)));
  }

  /// @notice Build the full batch type string from an array of action types.
  /// @dev The type string format is:
  ///      Batch({ParamsType} action0,{ParamsType} action1,...,address onBehalfOf,uint256 nonce,uint256 deadline){TypeDefs}
  ///      where {TypeDefs} are the nested type definitions in alphabetical order.
  /// @param actionTypes Array of action type enum values.
  /// @return The constructed type string.
  function buildBatchTypeString(uint8[] memory actionTypes) internal pure returns (string memory) {
    uint256 len = actionTypes.length;

    // Track which action types are used (bitmap for deduplication)
    uint8 usedTypes = 0;

    // Build the Batch(...) part
    bytes memory batchPart = BATCH_PREFIX;

    for (uint256 i = 0; i < len; i++) {
      uint8 actionType = actionTypes[i];
      usedTypes |= uint8(1 << actionType);

      // Append "{ParamsTypeName} action{i},"
      batchPart = bytes.concat(
        batchPart,
        bytes(_getParamsTypeName(actionType)),
        ACTION_FIELD_PREFIX,
        bytes(_uintToString(i)),
        FIELD_SEPARATOR
      );
    }

    // Append the fixed suffix
    batchPart = bytes.concat(batchPart, BATCH_SUFFIX);

    // Append type definitions in alphabetical order
    // Order: Borrow < Repay < SetUsingAsCollateral < Supply < UpdateUserDynamicConfig < UpdateUserRiskPremium < Withdraw
    bytes memory typeDefs = '';

    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Borrow)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(BORROW_PARAMS_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Repay)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(REPAY_PARAMS_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(SET_USING_AS_COLLATERAL_PARAMS_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Supply)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(SUPPLY_PARAMS_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(UPDATE_USER_DYNAMIC_CONFIG_PARAMS_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(UPDATE_USER_RISK_PREMIUM_PARAMS_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Withdraw)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(WITHDRAW_PARAMS_DEF));
    }

    return string(bytes.concat(batchPart, typeDefs));
  }

  /// @notice Hash a specific action based on its type.
  /// @param actionType The action type enum value.
  /// @param actionData The ABI-encoded params struct.
  /// @return The struct hash of the params.
  function hashAction(uint8 actionType, bytes memory actionData) internal pure returns (bytes32) {
    if (actionType == uint8(ISignatureGateway.ActionType.Supply)) {
      ISignatureGateway.SupplyParams memory params = abi.decode(
        actionData,
        (ISignatureGateway.SupplyParams)
      );
      return
        keccak256(
          abi.encode(SUPPLY_PARAMS_TYPEHASH, params.spoke, params.reserveId, params.amount)
        );
    } else if (actionType == uint8(ISignatureGateway.ActionType.Withdraw)) {
      ISignatureGateway.WithdrawParams memory params = abi.decode(
        actionData,
        (ISignatureGateway.WithdrawParams)
      );
      return
        keccak256(
          abi.encode(WITHDRAW_PARAMS_TYPEHASH, params.spoke, params.reserveId, params.amount)
        );
    } else if (actionType == uint8(ISignatureGateway.ActionType.Borrow)) {
      ISignatureGateway.BorrowParams memory params = abi.decode(
        actionData,
        (ISignatureGateway.BorrowParams)
      );
      return
        keccak256(
          abi.encode(BORROW_PARAMS_TYPEHASH, params.spoke, params.reserveId, params.amount)
        );
    } else if (actionType == uint8(ISignatureGateway.ActionType.Repay)) {
      ISignatureGateway.RepayParams memory params = abi.decode(
        actionData,
        (ISignatureGateway.RepayParams)
      );
      return
        keccak256(abi.encode(REPAY_PARAMS_TYPEHASH, params.spoke, params.reserveId, params.amount));
    } else if (actionType == uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) {
      ISignatureGateway.SetUsingAsCollateralParams memory params = abi.decode(
        actionData,
        (ISignatureGateway.SetUsingAsCollateralParams)
      );
      return
        keccak256(
          abi.encode(
            SET_USING_AS_COLLATERAL_PARAMS_TYPEHASH,
            params.spoke,
            params.reserveId,
            params.useAsCollateral
          )
        );
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) {
      ISignatureGateway.UpdateUserRiskPremiumParams memory params = abi.decode(
        actionData,
        (ISignatureGateway.UpdateUserRiskPremiumParams)
      );
      return keccak256(abi.encode(UPDATE_USER_RISK_PREMIUM_PARAMS_TYPEHASH, params.spoke));
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) {
      ISignatureGateway.UpdateUserDynamicConfigParams memory params = abi.decode(
        actionData,
        (ISignatureGateway.UpdateUserDynamicConfigParams)
      );
      return keccak256(abi.encode(UPDATE_USER_DYNAMIC_CONFIG_PARAMS_TYPEHASH, params.spoke));
    } else {
      revert InvalidActionType(actionType);
    }
  }

  /// @notice Compute the full batch struct hash.
  /// @dev Per EIP-712, struct hash = keccak256(abi.encode(typeHash, member1, member2, ...))
  ///      For nested structs, each member is the hashStruct of that nested struct.
  /// @param actionTypes Array of action type enum values.
  /// @param actionData Array of ABI-encoded params structs.
  /// @param onBehalfOf The user on whose behalf all actions are performed.
  /// @param nonce The nonce for replay protection.
  /// @param deadline The deadline for the batch.
  /// @return The struct hash of the batch.
  function hashBatch(
    uint8[] memory actionTypes,
    bytes[] memory actionData,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) internal pure returns (bytes32) {
    bytes32 typeHash = buildBatchTypeHash(actionTypes);

    // Build the encoding dynamically since number of action fields varies
    // Per EIP-712: each nested struct field is encoded as hashStruct(field)
    bytes memory encoded = abi.encode(typeHash);

    uint256 len = actionTypes.length;
    for (uint256 i = 0; i < len; i++) {
      encoded = bytes.concat(encoded, abi.encode(hashAction(actionTypes[i], actionData[i])));
    }

    // Append the fixed fields
    encoded = bytes.concat(encoded, abi.encode(onBehalfOf, nonce, deadline));

    return keccak256(encoded);
  }

  /// @notice Get the params type name string for a given action type.
  /// @param actionType The action type enum value.
  /// @return The params type name string.
  function _getParamsTypeName(uint8 actionType) private pure returns (string memory) {
    if (actionType == uint8(ISignatureGateway.ActionType.Supply)) {
      return SUPPLY_PARAMS_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.Withdraw)) {
      return WITHDRAW_PARAMS_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.Borrow)) {
      return BORROW_PARAMS_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.Repay)) {
      return REPAY_PARAMS_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) {
      return SET_USING_AS_COLLATERAL_PARAMS_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) {
      return UPDATE_USER_RISK_PREMIUM_PARAMS_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) {
      return UPDATE_USER_DYNAMIC_CONFIG_PARAMS_NAME;
    } else {
      revert InvalidActionType(actionType);
    }
  }

  /// @notice Convert a uint256 to its string representation.
  /// @dev Only handles small numbers (0-9) for action indices.
  /// @param value The value to convert.
  /// @return The string representation.
  function _uintToString(uint256 value) private pure returns (string memory) {
    if (value == 0) return '0';
    if (value == 1) return '1';
    if (value == 2) return '2';
    if (value == 3) return '3';
    if (value == 4) return '4';
    if (value == 5) return '5';
    if (value == 6) return '6';
    if (value == 7) return '7';
    if (value == 8) return '8';
    if (value == 9) return '9';

    // For values >= 10, build the string
    bytes memory buffer;
    while (value > 0) {
      buffer = bytes.concat(bytes1(uint8(48 + (value % 10))), buffer);
      value /= 10;
    }
    return string(buffer);
  }
}
