// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {SignatureGateway, ISignatureGateway} from 'src/misc/SignatureGateway.sol';

contract SignatureGatewayBaseTest is Base {
  using stdStorage for StdStorage;

  ISignatureGateway public gateway;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    gateway = ISignatureGateway(new SignatureGateway(address(spoke1), ADMIN));
    (alice, alicePk) = makeAddrAndKey('alice');
  }

  /**
   * @dev Warps after to a random time after a randomly generated deadline.
   * @return The randomly generated deadline.
   */
  function _warpAfterRandomDeadline() internal returns (uint256) {
    uint256 deadline = vm.randomUint(0, MAX_SKIP_TIME - 1);
    vm.warp(vm.randomUint(deadline + 1, MAX_SKIP_TIME));
    return deadline;
  }

  /**
   * @dev Warps to a random time before a randomly generated deadline.
   * @return The randomly generated deadline.
   */
  function _warpBeforeRandomDeadline() internal returns (uint256) {
    uint256 deadline = vm.randomUint(1, MAX_SKIP_TIME);
    vm.warp(vm.randomUint(0, deadline - 1));
    return deadline;
  }

  function _burnRandomNonces(address user) internal {
    uint256 newNonce = vm.randomUint(1, UINT256_MAX - 1);
    stdstore
      .target(address(gateway))
      .sig(ISignatureGateway.nonces.selector)
      .with_key(user)
      .checked_write(newNonce);
    assertEq(gateway.nonces(user), newNonce);
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    return abi.encodePacked(r, s, v);
  }

  function _randomReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(0, spoke.getReserveCount() - 1);
  }

  function _randomInvalidReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(spoke.getReserveCount(), UINT256_MAX);
  }

  function _supplyData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Supply memory) {
    return
      EIP712Types.Supply({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(who),
        deadline: deadline
      });
  }

  function _withdrawData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Withdraw memory) {
    return
      EIP712Types.Withdraw({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(who),
        deadline: deadline
      });
  }

  function _borrowData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Borrow memory) {
    return
      EIP712Types.Borrow({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(who),
        deadline: deadline
      });
  }

  function _repayData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.Repay memory) {
    return
      EIP712Types.Repay({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: who,
        nonce: gateway.nonces(who),
        deadline: deadline
      });
  }

  function _setAsCollateralData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (EIP712Types.SetUsingAsCollateral memory) {
    return
      EIP712Types.SetUsingAsCollateral({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        useAsCollateral: vm.randomBool(),
        onBehalfOf: who,
        nonce: gateway.nonces(who),
        deadline: deadline
      });
  }

  function _updateRiskPremiumData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (EIP712Types.UpdateUserRiskPremium memory) {
    return
      EIP712Types.UpdateUserRiskPremium({
        spoke: address(spoke),
        user: user,
        nonce: gateway.nonces(user),
        deadline: deadline
      });
  }

  function _updateDynamicConfigData(
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (EIP712Types.UpdateUserDynamicConfig memory) {
    return
      EIP712Types.UpdateUserDynamicConfig({
        spoke: address(spoke),
        user: user,
        nonce: gateway.nonces(user),
        deadline: deadline
      });
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    EIP712Types.Supply memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Supply', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    EIP712Types.Withdraw memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Withdraw', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    EIP712Types.Borrow memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Borrow', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    EIP712Types.Repay memory _params
  ) internal view returns (bytes32) {
    return _typedDataHash(_gateway, vm.eip712HashStruct('Repay', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    EIP712Types.SetUsingAsCollateral memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_gateway, vm.eip712HashStruct('SetUsingAsCollateral', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    EIP712Types.UpdateUserRiskPremium memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_gateway, vm.eip712HashStruct('UpdateUserRiskPremium', abi.encode(_params)));
  }

  function _getTypedDataHash(
    ISignatureGateway _gateway,
    EIP712Types.UpdateUserDynamicConfig memory _params
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
      assertFalse(spoke.isUsingAsCollateral(reserveId, address(_gateway)));
      assertFalse(spoke.isBorrowing(reserveId, address(_gateway)));
    }
  }
}
