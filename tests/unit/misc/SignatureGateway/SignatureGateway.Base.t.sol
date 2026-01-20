// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SignatureGatewayBaseTest is SpokeBase {
  address internal constant CANONICAL_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  ISignatureGateway public gateway;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    gateway = ISignatureGateway(new SignatureGateway(ADMIN, CANONICAL_PERMIT2));
    (alice, alicePk) = makeAddrAndKey('alice');

    vm.prank(address(ADMIN));
    gateway.registerSpoke(address(spoke1), true);
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    return abi.encodePacked(r, s, v);
  }

  function _supplyAction(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.SupplyAction memory) {
    return
      ISignatureGateway.SupplyAction({
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline,
        params: ISignatureGateway.SupplyParams({
          spoke: address(spoke),
          reserveId: _randomReserveId(spoke),
          amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT)
        })
      });
  }

  function _withdrawAction(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.WithdrawAction memory) {
    return
      ISignatureGateway.WithdrawAction({
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline,
        params: ISignatureGateway.WithdrawParams({
          spoke: address(spoke),
          reserveId: _randomReserveId(spoke),
          amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT)
        })
      });
  }

  function _borrowAction(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.BorrowAction memory) {
    return
      ISignatureGateway.BorrowAction({
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline,
        params: ISignatureGateway.BorrowParams({
          spoke: address(spoke),
          reserveId: _randomReserveId(spoke),
          amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT)
        })
      });
  }

  function _repayAction(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.RepayAction memory) {
    return
      ISignatureGateway.RepayAction({
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline,
        params: ISignatureGateway.RepayParams({
          spoke: address(spoke),
          reserveId: _randomReserveId(spoke),
          amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT)
        })
      });
  }

  function _setAsCollateralAction(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.SetUsingAsCollateralAction memory) {
    return
      ISignatureGateway.SetUsingAsCollateralAction({
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline,
        params: ISignatureGateway.SetUsingAsCollateralParams({
          spoke: address(spoke),
          reserveId: _randomReserveId(spoke),
          useAsCollateral: vm.randomBool()
        })
      });
  }

  function _updateRiskPremiumAction(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.UpdateUserRiskPremiumAction memory) {
    return
      ISignatureGateway.UpdateUserRiskPremiumAction({
        user: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline,
        params: ISignatureGateway.UpdateUserRiskPremiumParams({spoke: address(spoke)})
      });
  }

  function _updateDynamicConfigAction(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.UpdateUserDynamicConfigAction memory) {
    return
      ISignatureGateway.UpdateUserDynamicConfigAction({
        user: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline,
        params: ISignatureGateway.UpdateUserDynamicConfigParams({spoke: address(spoke)})
      });
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.SupplyAction memory _action
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('SupplyAction', abi.encode(_action)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.WithdrawAction memory _action
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('WithdrawAction', abi.encode(_action)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.BorrowAction memory _action
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('BorrowAction', abi.encode(_action)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.RepayAction memory _action
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('RepayAction', abi.encode(_action)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.SetUsingAsCollateralAction memory _action
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _gateway,
        vm.eip712HashStruct('SetUsingAsCollateralAction', abi.encode(_action))
      );
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.UpdateUserRiskPremiumAction memory _action
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _gateway,
        vm.eip712HashStruct('UpdateUserRiskPremiumAction', abi.encode(_action))
      );
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.UpdateUserDynamicConfigAction memory _action
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _gateway,
        vm.eip712HashStruct('UpdateUserDynamicConfigAction', abi.encode(_action))
      );
  }

  function _typedDataHash(
    ISignatureGateway _gateway,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _gateway.DOMAIN_SEPARATOR(), typeHash));
  }

  function _assertGatewayHasNoBalanceOrAllowance(
    ISpoke spoke,
    ISignatureGateway _gateway,
    address who
  ) internal view {
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      IERC20 underlying = _underlying(spoke, reserveId);
      assertEq(underlying.balanceOf(address(_gateway)), 0);
      assertEq(underlying.allowance({owner: who, spender: address(_gateway)}), 0);
    }
  }

  function _assertGatewayHasNoActivePosition(
    ISpoke spoke,
    ISignatureGateway _gateway
  ) internal view {
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      assertEq(spoke.getUserSuppliedShares(reserveId, address(_gateway)), 0);
      assertEq(spoke.getUserTotalDebt(reserveId, address(_gateway)), 0); // rounds up so asset validation is enough
      assertFalse(_isUsingAsCollateral(spoke, reserveId, address(_gateway)));
      assertFalse(_isBorrowing(spoke, reserveId, address(_gateway)));
    }
  }

  // ============ Batch Helpers ============

  function _supplyParams(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal pure returns (ISignatureGateway.SupplyParams memory) {
    return
      ISignatureGateway.SupplyParams({spoke: address(spoke), reserveId: reserveId, amount: amount});
  }

  function _withdrawParams(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal pure returns (ISignatureGateway.WithdrawParams memory) {
    return
      ISignatureGateway.WithdrawParams({
        spoke: address(spoke),
        reserveId: reserveId,
        amount: amount
      });
  }

  function _borrowParams(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal pure returns (ISignatureGateway.BorrowParams memory) {
    return
      ISignatureGateway.BorrowParams({spoke: address(spoke), reserveId: reserveId, amount: amount});
  }

  function _repayParams(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal pure returns (ISignatureGateway.RepayParams memory) {
    return
      ISignatureGateway.RepayParams({spoke: address(spoke), reserveId: reserveId, amount: amount});
  }

  function _setUsingAsCollateralParams(
    ISpoke spoke,
    uint256 reserveId,
    bool useAsCollateral
  ) internal pure returns (ISignatureGateway.SetUsingAsCollateralParams memory) {
    return
      ISignatureGateway.SetUsingAsCollateralParams({
        spoke: address(spoke),
        reserveId: reserveId,
        useAsCollateral: useAsCollateral
      });
  }

  function _getBatchTypedDataHash(
    ISignatureGateway _gateway,
    uint8[] memory actionTypes,
    bytes[] memory actionData,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) internal view returns (bytes32) {
    bytes32 typeHash = keccak256(bytes(_buildBatchTypeString(actionTypes)));

    bytes memory encoded = abi.encode(typeHash);
    for (uint256 i = 0; i < actionTypes.length; i++) {
      bytes32 actionHash = _hashActionParams(actionTypes[i], actionData[i]);
      encoded = bytes.concat(encoded, abi.encode(actionHash));
    }
    encoded = bytes.concat(encoded, abi.encode(onBehalfOf, nonce, deadline));

    bytes32 structHash = keccak256(encoded);

    return keccak256(abi.encodePacked('\x19\x01', _gateway.DOMAIN_SEPARATOR(), structHash));
  }

  function _buildBatchTypeString(uint8[] memory actionTypes) internal pure returns (string memory) {
    uint256 len = actionTypes.length;
    uint8 usedTypes = 0;

    bytes memory batchPart = 'Batch(';

    for (uint256 i = 0; i < len; i++) {
      uint8 actionType = actionTypes[i];
      usedTypes |= uint8(1 << actionType);
      batchPart = bytes.concat(
        batchPart,
        bytes(_getParamsTypeName(actionType)),
        ' action',
        bytes(_uintToString(i)),
        ','
      );
    }

    batchPart = bytes.concat(batchPart, 'address onBehalfOf,uint256 nonce,uint256 deadline)');

    bytes memory typeDefs = '';
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Borrow)) != 0) {
      typeDefs = bytes.concat(
        typeDefs,
        'BorrowParams(address spoke,uint256 reserveId,uint256 amount)'
      );
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Repay)) != 0) {
      typeDefs = bytes.concat(
        typeDefs,
        'RepayParams(address spoke,uint256 reserveId,uint256 amount)'
      );
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) != 0) {
      typeDefs = bytes.concat(
        typeDefs,
        'SetUsingAsCollateralParams(address spoke,uint256 reserveId,bool useAsCollateral)'
      );
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Supply)) != 0) {
      typeDefs = bytes.concat(
        typeDefs,
        'SupplyParams(address spoke,uint256 reserveId,uint256 amount)'
      );
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) != 0) {
      typeDefs = bytes.concat(typeDefs, 'UpdateUserDynamicConfigParams(address spoke)');
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) != 0) {
      typeDefs = bytes.concat(typeDefs, 'UpdateUserRiskPremiumParams(address spoke)');
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Withdraw)) != 0) {
      typeDefs = bytes.concat(
        typeDefs,
        'WithdrawParams(address spoke,uint256 reserveId,uint256 amount)'
      );
    }

    return string(bytes.concat(batchPart, typeDefs));
  }

  function _hashActionParams(
    uint8 actionType,
    bytes memory actionData
  ) internal pure returns (bytes32) {
    if (actionType == uint8(ISignatureGateway.ActionType.Supply)) {
      return vm.eip712HashStruct('SupplyParams', actionData);
    } else if (actionType == uint8(ISignatureGateway.ActionType.Withdraw)) {
      return vm.eip712HashStruct('WithdrawParams', actionData);
    } else if (actionType == uint8(ISignatureGateway.ActionType.Borrow)) {
      return vm.eip712HashStruct('BorrowParams', actionData);
    } else if (actionType == uint8(ISignatureGateway.ActionType.Repay)) {
      return vm.eip712HashStruct('RepayParams', actionData);
    } else if (actionType == uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) {
      return vm.eip712HashStruct('SetUsingAsCollateralParams', actionData);
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) {
      return vm.eip712HashStruct('UpdateUserRiskPremiumParams', actionData);
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) {
      return vm.eip712HashStruct('UpdateUserDynamicConfigParams', actionData);
    } else {
      revert('Invalid action type');
    }
  }

  function _getParamsTypeName(uint8 actionType) internal pure returns (string memory) {
    if (actionType == uint8(ISignatureGateway.ActionType.Supply)) return 'SupplyParams';
    if (actionType == uint8(ISignatureGateway.ActionType.Withdraw)) return 'WithdrawParams';
    if (actionType == uint8(ISignatureGateway.ActionType.Borrow)) return 'BorrowParams';
    if (actionType == uint8(ISignatureGateway.ActionType.Repay)) return 'RepayParams';
    if (actionType == uint8(ISignatureGateway.ActionType.SetUsingAsCollateral))
      return 'SetUsingAsCollateralParams';
    if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium))
      return 'UpdateUserRiskPremiumParams';
    if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig))
      return 'UpdateUserDynamicConfigParams';
    revert('Invalid action type');
  }

  function _uintToString(uint256 value) internal pure returns (string memory) {
    if (value < 10) return string(abi.encodePacked(bytes1(uint8(48 + value))));
    bytes memory buffer;
    while (value > 0) {
      buffer = bytes.concat(bytes1(uint8(48 + (value % 10))), buffer);
      value /= 10;
    }
    return string(buffer);
  }
}
