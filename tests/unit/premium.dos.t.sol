// // SPDX-License-Identifier: UNLICENSED
// // Copyright (c) 2025 Aave Labs
// pragma solidity ^0.8.10;

// import 'tests/Base.t.sol';
// import {AssetLogic} from 'src/hub/libraries/AssetLogic.sol';

// contract TestPremiumPoC is Test {
//   using MathUtils for *;
//   using SafeCast for *;
//   using AssetLogic for *;
//   using WadRayMath for *;

//   IHub.Asset asset;
//   IHub.SpokeData spoke0;
//   IHub.SpokeData spoke1;

//   function _applyPremiumDelta(
//     IHubBase.PremiumDelta memory premium,
//     uint256 premiumAmount
//   ) internal {
//     uint256 premiumBefore = asset.premium();

//     asset.premiumShares = asset.premiumShares.add(premium.sharesDelta).toUint128();
//     asset.premiumOffset = asset.premiumOffset.add(premium.offsetDelta).toUint128();
//     asset.realizedPremium = asset.realizedPremium.add(premium.realizedDelta).toUint128();

//     spoke0.premiumShares = spoke0.premiumShares.add(premium.sharesDelta).toUint128();
//     spoke0.premiumOffset = spoke0.premiumOffset.add(premium.offsetDelta).toUint128();
//     spoke0.realizedPremium = spoke0.realizedPremium.add(premium.realizedDelta).toUint128();

//     require(asset.premium() + premiumAmount - premiumBefore <= 2);
//   }

//   function test_maxPremium() public {
//     spoke0.premiumShares = 5 * 10 ** 18;
//     spoke1.premiumShares = 5 * 10 ** 18;

//     spoke0.premiumOffset = 2 * 10 ** 18;
//     spoke1.premiumOffset = 3 * 10 ** 18;

//     asset.drawnIndex = 10 ** 27 + 2 * 10 ** 26; // 1.2
//     asset.premiumShares = spoke0.premiumShares + spoke1.premiumShares; //10*10**18; // 10
//     asset.premiumOffset = spoke0.premiumOffset + spoke1.premiumOffset; //5*10**18; // 10
//     asset.realizedPremium = 0;

//     uint newOffset = 2 ** 128 - 1;

//     int offsetDelta = int(newOffset) - int128(asset.premiumOffset);
//     int shareDelta = int((asset.premium() + newOffset).rayDivUp(uint(asset.drawnIndex))) -
//       int128(asset.premiumShares);
//     IHubBase.PremiumDelta memory premium = IHubBase.PremiumDelta({
//       sharesDelta: shareDelta,
//       offsetDelta: offsetDelta,
//       realizedDelta: 0
//     });

//     _applyPremiumDelta(premium, 0);

//     assert(asset.premiumOffset == 2 ** 128 - 1);
//     assert(spoke0.premiumOffset == 340282366920938463460374607431768211455);
//   }
// }
