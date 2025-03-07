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
    DataTypes.UserPosition storage user,
    DataTypes.UserData storage userData,
    uint256 nextBaseBorrowIndex
  ) internal {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = user.previewInterest(
      userData,
      nextBaseBorrowIndex
    );

    user.baseDebt = cumulatedBaseDebt;
    user.outstandingPremium = cumulatedOutstandingPremium;
    user.baseBorrowIndex = nextBaseBorrowIndex;
    user.lastUpdateTimestamp = block.timestamp;
  }

  function previewInterest(
    DataTypes.UserPosition storage user,
    DataTypes.UserData storage userData, // todo opt: pass user rp only
    uint256 nextBaseBorrowIndex
  ) internal view returns (uint256, uint256) {
    uint256 existingBaseDebt = user.baseDebt;
    uint256 existingOutstandingPremium = user.outstandingPremium;

    if (existingBaseDebt == 0 || user.lastUpdateTimestamp == block.timestamp) {
      return (existingBaseDebt, existingOutstandingPremium);
    }

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      user.baseBorrowIndex
    );

    return (
      cumulatedBaseDebt,
      existingOutstandingPremium +
        (cumulatedBaseDebt - existingBaseDebt).percentMul(userData.riskPremium.derayify())
    );
  }
}
