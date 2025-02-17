pragma solidity ^0.8.0;

import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

library SpokeDataLogic {
  using SpokeDataLogic for SpokeData;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;

  // @dev Utilizes existing `spoke.baseBorrowIndex` & `spoke.riskPremiumRad`
  function accrueInterest(SpokeData storage spoke, uint256 nextBaseBorrowIndex) internal {
    if (spoke.lastUpdateTimestamp == block.timestamp) {
      return;
    }

    uint256 existingBaseDebt = spoke.baseDebt;
    if (existingBaseDebt != 0) {
      uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
        spoke.baseBorrowIndex
      ); // precision loss, same as in v3

      // accrue premium interest on the accrued base interest
      spoke.outstandingPremium += (cumulatedBaseDebt - existingBaseDebt).radMul(
        spoke.riskPremiumRad
      );
      spoke.baseDebt = cumulatedBaseDebt;
    }

    spoke.baseBorrowIndex = nextBaseBorrowIndex; // opt: doesn't need update on supply/withdraw actions?
    spoke.lastUpdateTimestamp = block.timestamp;
  }
}
