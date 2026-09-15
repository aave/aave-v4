// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeUtils} from 'src/spoke/libraries/SpokeUtils.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title SpokeUtilsWrapper
/// @author Aave Labs
/// @notice Wrapper for the SpokeUtils library to be used in tests.
contract SpokeUtilsWrapper {
  mapping(bytes32 reserveBucket => ISpoke.Reserve) internal _reserves;

  function setReserve(uint256 reserveId, ISpoke.Reserve memory reserve) external {
    _reserves[PositionStatusMap.reserveBucket(reserveId)] = reserve;
  }

  function get(uint256 reserveId) external view returns (ISpoke.Reserve memory) {
    return SpokeUtils.get(_reserves, reserveId);
  }

  function toValue(
    uint256 amount,
    uint256 decimals,
    uint256 price
  ) external pure returns (uint256) {
    return SpokeUtils.toValue(amount, decimals, price);
  }
}
