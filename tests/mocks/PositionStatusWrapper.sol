// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract PositionStatusWrapper {
  using PositionStatus for DataTypes.PositionStatus;
  DataTypes.PositionStatus internal _p;

  function BORROWING_MASK() external pure returns (uint256) {
    return PositionStatus.BORROWING_MASK;
  }

  function COLLATERAL_MASK() external pure returns (uint256) {
    return PositionStatus.COLLATERAL_MASK;
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

  function getBucketWord(uint256 reserveId) external view returns (uint256) {
    return _p.getBucketWord(reserveId);
  }

  function slot() external pure returns (bytes32 s) {
    assembly ('memory-safe') {
      s := _p.slot
    }
  }
}
