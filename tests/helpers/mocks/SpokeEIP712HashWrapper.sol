// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {EIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';

contract SpokeEIP712HashWrapper {
  using EIP712Hash for *;

  function SET_USER_POSITION_MANAGERS_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH; }
  function POSITION_MANAGER_UPDATE() external pure returns (bytes32) { return EIP712Hash.POSITION_MANAGER_UPDATE; }
  function TOKENIZED_DEPOSIT_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.TOKENIZED_DEPOSIT_TYPEHASH; }
  function TOKENIZED_MINT_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.TOKENIZED_MINT_TYPEHASH; }
  function TOKENIZED_WITHDRAW_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.TOKENIZED_WITHDRAW_TYPEHASH; }
  function TOKENIZED_REDEEM_TYPEHASH() external pure returns (bytes32) { return EIP712Hash.TOKENIZED_REDEEM_TYPEHASH; }

  function hashSetUserPositionManagers(ISpoke.SetUserPositionManagers calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashPositionManagerUpdate(ISpoke.PositionManagerUpdate calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashTokenizedDeposit(ITokenizationSpoke.TokenizedDeposit calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashTokenizedMint(ITokenizationSpoke.TokenizedMint calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashTokenizedWithdraw(ITokenizationSpoke.TokenizedWithdraw calldata p) external pure returns (bytes32) { return p.hash(); }
  function hashTokenizedRedeem(ITokenizationSpoke.TokenizedRedeem calldata p) external pure returns (bytes32) { return p.hash(); }
}
