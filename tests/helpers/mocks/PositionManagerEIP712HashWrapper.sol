// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ITakerPositionManager} from 'src/position-manager/interfaces/ITakerPositionManager.sol';

contract PositionManagerEIP712HashWrapper {
  using EIP712Hash for *;

  function SUPPLY_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.SUPPLY_TYPEHASH; }
  function WITHDRAW_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.WITHDRAW_TYPEHASH; }
  function BORROW_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.BORROW_TYPEHASH; }
  function REPAY_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.REPAY_TYPEHASH; }
  function SET_USING_AS_COLLATERAL_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH; }
  function UPDATE_USER_RISK_PREMIUM_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH; }
  function UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH; }
  function WITHDRAW_PERMIT_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.WITHDRAW_PERMIT_TYPEHASH; }
  function BORROW_PERMIT_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.BORROW_PERMIT_TYPEHASH; }

  function hashSupply(ISignatureGateway.Supply calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashWithdraw(ISignatureGateway.Withdraw calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashBorrow(ISignatureGateway.Borrow calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashRepay(ISignatureGateway.Repay calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashSetUsingAsCollateral(ISignatureGateway.SetUsingAsCollateral calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashUpdateUserRiskPremium(ISignatureGateway.UpdateUserRiskPremium calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashUpdateUserDynamicConfig(ISignatureGateway.UpdateUserDynamicConfig calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashWithdrawPermit(ITakerPositionManager.WithdrawPermit calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashBorrowPermit(ITakerPositionManager.BorrowPermit calldata p) external pure returns (bytes32) { return p.hash(); }
}
