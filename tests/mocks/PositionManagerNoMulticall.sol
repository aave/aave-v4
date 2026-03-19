// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

contract PositionManagerNoMulticall is PositionManagerBase {
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  function getReserveUnderlying(address spoke, uint256 reserveId) external view returns (address) {
    return address(_getReserveUnderlying(spoke, reserveId));
  }

  function _multicallEnabled() internal pure override returns (bool) {
    return false;
  }
}
