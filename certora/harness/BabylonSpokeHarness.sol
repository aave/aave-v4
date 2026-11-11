// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BabylonSpokeInstance} from 'src/spoke/instances/BabylonSpokeInstance.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';

/// @notice Read-only access to the real position bitmap and reserve flags.
/// @dev Unlike getUserReserveStatus, these readers also work for unlisted reserves.
contract BabylonSpokeHarness is BabylonSpokeInstance {
  constructor(
    address oracle_,
    address liquidationManager_,
    uint256 managedCollateralReserveId_
  ) BabylonSpokeInstance(oracle_, liquidationManager_, managedCollateralReserveId_) {}

  function harnessIsCollateral(address user, uint256 reserveId) external view returns (bool) {
    return PositionStatusMap.isUsingAsCollateral(_positionStatus[user], reserveId);
  }

  function harnessIsBorrowing(address user, uint256 reserveId) external view returns (bool) {
    return PositionStatusMap.isBorrowing(_positionStatus[user], reserveId);
  }

  function harnessCollateralCount(address user) external view returns (uint256) {
    return PositionStatusMap.collateralCount(_positionStatus[user], _reserveCount);
  }

  function harnessBorrowCount(address user) external view returns (uint256) {
    return PositionStatusMap.borrowCount(_positionStatus[user], _reserveCount);
  }

  function harnessIsBorrowable(uint256 reserveId) external view returns (bool) {
    return ReserveFlagsMap.borrowable(_reserves[reserveId].flags);
  }
}
