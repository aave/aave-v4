// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

contract PositionManagerBaseWrapper is PositionManagerBase {
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  function getReserveUnderlying(address spoke, uint256 reserveId) external view returns (address) {
    return address(_getReserveUnderlying(spoke, reserveId));
  }

  function _multicallEnabled() internal pure override returns (bool) {
    return true;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('PositionManagerBaseWrapper', '1');
  }
}
