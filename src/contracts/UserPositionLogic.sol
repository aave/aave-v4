// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

library UserPositionLogic {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using UserPositionLogic for DataTypes.UserPosition;

  function accrueInterest(
    DataTypes.UserPosition storage userPosition,
    DataTypes.UserData storage userData,
    uint256 nextBaseBorrowIndex
  ) internal {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = userPosition.previewInterest(
      userData,
      nextBaseBorrowIndex
    );

    userPosition.baseDebt = cumulatedBaseDebt;
    userPosition.outstandingPremium = cumulatedOutstandingPremium;
    userPosition.baseBorrowIndex = nextBaseBorrowIndex;
    userPosition.lastUpdateTimestamp = block.timestamp;
  }

  function previewInterest(
    DataTypes.UserPosition storage userPosition,
    DataTypes.UserData storage userData, // todo opt: pass user rp only
    uint256 nextBaseBorrowIndex
  ) internal view returns (uint256, uint256) {
    uint256 existingBaseDebt = userPosition.baseDebt;
    uint256 existingOutstandingPremium = userPosition.outstandingPremium;

    if (existingBaseDebt == 0 || userPosition.lastUpdateTimestamp == block.timestamp) {
      return (existingBaseDebt, existingOutstandingPremium);
    }

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      userPosition.baseBorrowIndex
    );

    return (
      cumulatedBaseDebt,
      existingOutstandingPremium +
        (cumulatedBaseDebt - existingBaseDebt).percentMul(userData.riskPremium.derayify())
    );
  }
}
