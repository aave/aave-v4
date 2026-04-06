// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Premium} from '../../src/hub/libraries/Premium.sol';

contract PremiumWrapper {
    function calculatePremiumRay(
        uint256 premiumShares,
        int256 premiumOffsetRay,
        uint256 drawnIndex
    ) external pure returns (uint256) {
        return Premium.calculatePremiumRay(premiumShares, premiumOffsetRay, drawnIndex);
    }
}

