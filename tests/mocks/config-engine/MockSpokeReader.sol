// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

contract MockSpokeReader {
  string public constant REVERT_MSG = 'MOCK_READ_REVERT';

  bool public shouldRevertOnRead;

  mapping(bytes32 => ISpoke.DynamicReserveConfig) private _configs;
  mapping(bytes32 => uint256) private _reserveIds;

  function setShouldRevertOnRead(bool revert_) external {
    shouldRevertOnRead = revert_;
  }

  function setDynamicReserveConfig(
    uint256 reserveId,
    uint32 key,
    ISpoke.DynamicReserveConfig memory config
  ) external {
    _configs[keccak256(abi.encode(reserveId, key))] = config;
  }

  function setReserveId(address hub, uint256 assetId, uint256 reserveId) external {
    _reserveIds[keccak256(abi.encode(hub, assetId))] = reserveId;
  }

  function getReserveId(address hub, uint256 assetId) external view returns (uint256) {
    return _reserveIds[keccak256(abi.encode(hub, assetId))];
  }

  function getDynamicReserveConfig(
    uint256 reserveId,
    uint32 dynamicConfigKey
  ) external view returns (ISpoke.DynamicReserveConfig memory) {
    if (shouldRevertOnRead) revert(REVERT_MSG);
    return _configs[keccak256(abi.encode(reserveId, dynamicConfigKey))];
  }
}
