// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract PositionStatusWrapper {

using PositionStatus for DataTypes.PositionStatus;

 function setBorrowing(
    DataTypes.PositionStatus storage positionStatus,
    uint256 reserveIndex,
    bool borrowing
  ) internal {
    positionStatus.setBorrowing(reserveIndex, borrowing);
  }

  function setUsingAsCollateral(
    DataTypes.PositionStatus storage positionStatus,
    uint256 reserveIndex,
    bool usingAsCollateral
  ) internal {
    positionStatus.setUsingAsCollateral(reserveIndex, usingAsCollateral);
  }

}
