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

  // @dev Utilizes existing `spoke.baseBorrowIndex` & `spoke.riskPremium`
  function accrueInterest(SpokeData storage spoke, uint256 nextBaseBorrowIndex) internal {
    (uint256 cumulatedBaseDebt, uint256 cumulatedOutstandingPremium) = spoke.previewInterest(
      nextBaseBorrowIndex
    );

    spoke.baseDebt = cumulatedBaseDebt;
    spoke.outstandingPremium = cumulatedOutstandingPremium;
    spoke.baseBorrowIndex = nextBaseBorrowIndex; // opt: doesn't need update on supply/withdraw actions?
    spoke.lastUpdateTimestamp = block.timestamp;
  }

  function previewInterest(
    SpokeData storage spoke,
    uint256 nextBaseBorrowIndex
  ) internal view returns (uint256, uint256) {
    uint256 existingBaseDebt = spoke.baseDebt;
    uint256 existingOutstandingPremium = spoke.outstandingPremium;

    if (existingBaseDebt == 0 || spoke.lastUpdateTimestamp == block.timestamp) {
      return (existingBaseDebt, existingOutstandingPremium);
    }

    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      spoke.baseBorrowIndex
    );

    return (
      cumulatedBaseDebt,
      existingOutstandingPremium +
        (cumulatedBaseDebt - existingBaseDebt).percentMul(spoke.riskPremium.derayify())
    );
  }
}
