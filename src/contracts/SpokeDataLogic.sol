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
    uint256 elapsed = block.timestamp - spoke.lastUpdateTimestamp;
    if (elapsed == 0) return;
    uint256 existingBaseDebt = spoke.baseDebt;
    if (existingBaseDebt == 0) return;

    // todo: add rayMulDiv in WadRayMath (=mulDiv / RAY) to optimize out the one cancelled RAY
    // & avoid precision loss
    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      spoke.baseBorrowIndex
    );
    spoke.outstandingPremium += (cumulatedBaseDebt - existingBaseDebt).radMul(spoke.riskPremiumRad);
    spoke.baseDebt = cumulatedBaseDebt;
    spoke.baseBorrowIndex = nextBaseBorrowIndex;
    spoke.lastUpdateTimestamp = block.timestamp;
  }
}
