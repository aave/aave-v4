// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

library ReserveLogic {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using ReserveLogic for DataTypes.Reserve;

  function accrueInterest(DataTypes.Reserve storage reserve, uint256 nextBaseBorrowIndex) internal {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = reserve.previewInterest(
      nextBaseBorrowIndex
    );

    reserve.baseDebt = cumulatedBaseDebt;
    reserve.outstandingPremium = cumulatedOutstandingPremium;
    reserve.baseBorrowIndex = nextBaseBorrowIndex;
    reserve.lastUpdateTimestamp = block.timestamp;
  }

  function previewInterest(
    DataTypes.Reserve storage reserve,
    uint256 nextBaseBorrowIndex
  ) internal view returns (uint256, uint256) {
    uint256 existingBaseDebt = reserve.baseDebt;
    uint256 existingOutstandingPremium = reserve.outstandingPremium;

    if (existingBaseDebt == 0 || reserve.lastUpdateTimestamp == block.timestamp) {
      return (existingBaseDebt, existingOutstandingPremium);
    }

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      reserve.baseBorrowIndex
    );

    return (
      cumulatedBaseDebt,
      existingOutstandingPremium +
        (cumulatedBaseDebt - existingBaseDebt).percentMul(reserve.riskPremium.derayify())
    );
  }
}
