// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SignatureGatewayBaseTest is SpokeBase {
  ISignatureGateway public gateway;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    gateway = ISignatureGateway(new SignatureGateway(ADMIN));
    (alice, alicePk) = makeAddrAndKey('alice');

    vm.prank(address(ADMIN));
    gateway.registerSpoke(address(spoke1), true);
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    return abi.encodePacked(r, s, v);
  }

  function _supplyData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.Supply memory) {
    return
      ISignatureGateway.Supply({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _withdrawData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.Withdraw memory) {
    return
      ISignatureGateway.Withdraw({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _borrowData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.Borrow memory) {
    return
      ISignatureGateway.Borrow({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _repayData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.Repay memory) {
    return
      ISignatureGateway.Repay({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _setAsCollateralData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureGateway.SetUsingAsCollateral memory) {
    return
      ISignatureGateway.SetUsingAsCollateral({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        useAsCollateral: vm.randomBool(),
        onBehalfOf: who,
        nonce: gateway.nonces(who, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _updateRiskPremiumData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.UpdateUserRiskPremium memory) {
    return
      ISignatureGateway.UpdateUserRiskPremium({
        spoke: address(spoke),
        user: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _updateDynamicConfigData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.UpdateUserDynamicConfig memory) {
    return
      ISignatureGateway.UpdateUserDynamicConfig({
        spoke: address(spoke),
        user: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.Supply memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Supply', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.Withdraw memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Withdraw', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.Borrow memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Borrow', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.Repay memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Repay', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.SetUsingAsCollateral memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_gateway, vm.eip712HashStruct('SetUsingAsCollateral', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.UpdateUserRiskPremium memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_gateway, vm.eip712HashStruct('UpdateUserRiskPremium', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    ISignatureGateway.UpdateUserDynamicConfig memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_gateway, vm.eip712HashStruct('UpdateUserDynamicConfig', abi.encode(_params)));
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
}
