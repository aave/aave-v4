// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library PremiumHelper {
  function calculateAccruedPremium(
    uint256 premiumDrawnAssets,
    uint256 premiumOffset
  ) internal pure returns (uint256) {
    uint256 accrued = premiumDrawnAssets < premiumOffset ? 0 : premiumDrawnAssets - premiumOffset;
    return accrued;
  }

  function calculateAccruedPremium2(
    uint256 premiumDrawnAssets,
    uint256 premiumOffset
  ) internal pure returns (uint256) {
    uint256 accrued = premiumDrawnAssets < premiumOffset && premiumOffset - premiumDrawnAssets < 2
      ? 0
      : premiumDrawnAssets - premiumOffset;
    return accrued;
  }
}
