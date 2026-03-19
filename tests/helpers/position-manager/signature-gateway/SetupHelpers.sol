// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeHelpers} from 'tests/helpers/spoke/SpokeHelpers.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title SetupHelpers
/// @notice Data builders for SignatureGateway tests.
abstract contract SetupHelpers is SpokeHelpers {
  function _supplyData(
    ISignatureGateway gateway,
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.Supply memory) {
    return
      ISignatureGateway.Supply({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _withdrawData(
    ISignatureGateway gateway,
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.Withdraw memory) {
    return
      ISignatureGateway.Withdraw({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _borrowData(
    ISignatureGateway gateway,
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.Borrow memory) {
    return
      ISignatureGateway.Borrow({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _repayData(
    ISignatureGateway gateway,
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.Repay memory) {
    return
      ISignatureGateway.Repay({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        onBehalfOf: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _setAsCollateralData(
    ISignatureGateway gateway,
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.SetUsingAsCollateral memory) {
    return
      ISignatureGateway.SetUsingAsCollateral({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        useAsCollateral: vm.randomBool(),
        onBehalfOf: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _updateRiskPremiumData(
    ISignatureGateway gateway,
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.UpdateUserRiskPremium memory) {
    return
      ISignatureGateway.UpdateUserRiskPremium({
        spoke: address(spoke),
        onBehalfOf: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _updateDynamicConfigData(
    ISignatureGateway gateway,
    ISpoke spoke,
    address user,
    uint256 deadline
  ) internal returns (ISignatureGateway.UpdateUserDynamicConfig memory) {
    return
      ISignatureGateway.UpdateUserDynamicConfig({
        spoke: address(spoke),
        onBehalfOf: user,
        nonce: gateway.nonces(user, _randomNonceKey()),
        deadline: deadline
      });
  }
}
