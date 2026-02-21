// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

contract PositionStatusMapWrapper {
  using PositionStatusMap for ISpoke.PositionStatus;

  ISpoke.PositionStatus internal _p;

  function BORROWING_MASK() external pure returns (uint256) {
    return PositionStatusMap.BORROWING_MASK;
  }

  function COLLATERAL_MASK() external pure returns (uint256) {
    return PositionStatusMap.COLLATERAL_MASK;
  }

  function setBorrowing(uint256 reserveId, bool borrowing) external {
    _p.setBorrowing(reserveId, borrowing);
  }

  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external {
    _p.setUsingAsCollateral(reserveId, usingAsCollateral);
  }

  function isUsingAsCollateralOrBorrowing(uint256 reserveId) external view returns (bool) {
    return _p.isUsingAsCollateralOrBorrowing(reserveId);
  }

  function isBorrowing(uint256 reserveId) external view returns (bool) {
    return _p.isBorrowing(reserveId);
  }

  function isUsingAsCollateral(uint256 reserveId) external view returns (bool) {
    return _p.isUsingAsCollateral(reserveId);
  }

  function collateralCount(uint256 reserveCount) external view returns (uint256) {
    return _p.collateralCount(reserveCount);
  }

  function borrowCount(uint256 reserveCount) external view returns (uint256) {
    return _p.borrowCount(reserveCount);
  }

  function getBucketWord(uint256 reserveId) external view returns (uint256) {
    return _p.getBucketWord(reserveId);
  }

  function bucketId(uint256 reserveId) external pure returns (uint256) {
    return PositionStatusMap.bucketId(reserveId);
  }

  function fromBitId(uint256 bitId, uint256 bucket) external pure returns (uint256) {
    return PositionStatusMap.fromBitId(bitId, bucket);
  }

  function isolateBorrowing(uint256 word) external pure returns (uint256) {
    return PositionStatusMap.isolateBorrowing(word);
  }

  function isolateBorrowingUntil(
    uint256 word,
    uint256 reserveCount
  ) external pure returns (uint256) {
    return PositionStatusMap.isolateBorrowingUntil(word, reserveCount);
  }

  function isolateUntil(uint256 word, uint256 reserveId) external pure returns (uint256) {
    return PositionStatusMap.isolateUntil(word, reserveId);
  }

  function isolateCollateral(uint256 word) external pure returns (uint256) {
    return PositionStatusMap.isolateCollateral(word);
  }

  function isolateCollateralUntil(
    uint256 word,
    uint256 reserveCount
  ) external pure returns (uint256) {
    return PositionStatusMap.isolateCollateralUntil(word, reserveCount);
  }

  function next(uint256 startReserveId) external view returns (uint256, bool, bool) {
    return _p.next(startReserveId);
  }

  function nextBorrowing(uint256 startReserveId) external view returns (uint256) {
    return _p.nextBorrowing(startReserveId);
  }

  function nextCollateral(uint256 startReserveId) external view returns (uint256) {
    return _p.nextCollateral(startReserveId);
  }

  function slot() external pure returns (bytes32 s) {
    assembly ('memory-safe') {
      s := _p.slot
    }
  }
}
