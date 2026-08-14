// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.20;

import {IPositionManagerGate} from 'src/spoke/interfaces/IPositionManagerGate.sol';

/// @title PositionManagerGateEIP712Hash
/// @author Aave Labs
/// @notice EIP-712 hashing helpers for PositionManagerGate intents.
library PositionManagerGateEIP712Hash {
  using PositionManagerGateEIP712Hash for *;

  bytes32 public constant SET_USER_POSITION_MANAGERS_TYPEHASH =
    keccak256(
      'SetUserPositionManagers(address spoke,address onBehalfOf,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)'
    );

  bytes32 public constant POSITION_MANAGER_UPDATE_TYPEHASH =
    keccak256('PositionManagerUpdate(address positionManager,bool approve)');

  function hash(
    IPositionManagerGate.SetUserPositionManagers calldata params
  ) internal pure returns (bytes32) {
    bytes32[] memory updatesHashes = new bytes32[](params.updates.length);
    for (uint256 i = 0; i < updatesHashes.length; ++i) {
      updatesHashes[i] = params.updates[i].hash();
    }
    return
      keccak256(
        abi.encode(
          SET_USER_POSITION_MANAGERS_TYPEHASH,
          params.spoke,
          params.onBehalfOf,
          keccak256(abi.encodePacked(updatesHashes)),
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    IPositionManagerGate.PositionManagerUpdate calldata params
  ) internal pure returns (bytes32 digest) {
    return
      keccak256(
        abi.encode(POSITION_MANAGER_UPDATE_TYPEHASH, params.positionManager, params.approve)
      );
  }
}
