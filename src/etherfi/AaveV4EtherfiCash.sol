// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// aave-address-book format (see AaveV4Avalanche.sol there) so this file can be upstreamed
// verbatim once the instance is live. Until then it is the single pinned source for the
// launch pipeline.
//
// Entry classes:
//   - VERIFIED: checked on-chain 2026-07-23/24 — tokens via symbol()/decimals(), feeds via
//     decimals()/description()/latestAnswer() (the exact IPriceFeed interface AaveOracle
//     consumes), Safes via live code + getThreshold().
//   - PREDICTED: from a full fork simulation of the instance deployment run as the launch
//     deployer (0xf8a86ea1Ac39EC529814c377Bd484387D395421e). All are CREATE2 via the Safe
//     Singleton Factory (0x914d7Fec…43d7) and either reproduce exactly or revert; the Cash
//     Spoke additionally requires the deployer to start at nonce 3 with the exact tx sequence
//     (the AaveOracle address, plain `new`, feeds into the spoke deployment). The preflight
//     validator blocks the pipeline until code exists at every address.

/// @notice Core contracts and administration of the ether.fi Cash Aave V4 instance (OP Mainnet).
library AaveV4EtherfiCash {
  // administration multisigs — VERIFIED (Safe v1.4.1)
  address internal constant OWNER_SAFE = 0x082B85ED50F1cd120C597EF860ece712e54CE844;
  address internal constant OPERATOR_SAFE = 0x23c30c38d73a0D1609ffAAe47aA7d6D1a3e46f03; // Nonce risk curator

  // instance — PREDICTED pending deployment
  address internal constant ACCESS_MANAGER = 0x188d7173772499FB6375F23FdFd130CE6107286b;
  address internal constant CONFIG_ENGINE = 0x84210b3087E952Be0f3610fD75f0f045995eAF22; // deployer-independent
  address internal constant HUB_CONFIGURATOR = 0xA39bEf2fD611fb9c5a69D63277b4Af97a30F0dbC;
  address internal constant SPOKE_CONFIGURATOR = 0xFEe9E8cCE1c40D3bd9F025437D3A11cA0DAe9f8b;
}

/// @notice Hubs of the ether.fi Cash Aave V4 instance.
library AaveV4EtherfiCashHubs {
  address internal constant CASH_HUB = 0x66753c4e3fC84f1eD0e3C267C927284E9d90C572; // PREDICTED
  address internal constant CASH_HUB_IR_STRATEGY = 0x51d07C362f9c4716F96EbEB63DB985EF9D2aCd7C; // PREDICTED
}

/// @notice Spokes of the ether.fi Cash Aave V4 instance.
library AaveV4EtherfiCashSpokes {
  address internal constant CASH_SPOKE = 0x6eAb1dC9eA3E6557dCE44B52c340a514a5ed5b83; // PREDICTED (nonce 3 + exact sequence; EtherFiSpokeInstance)
  address internal constant CASH_SPOKE_IMPLEMENTATION = 0x5826a76f3c484a5008A57Fd3904E07163889B813; // PREDICTED (nonce 3 + exact sequence; EtherFiSpokeInstance)
  address internal constant TREASURY_SPOKE = 0x7EB4d25F137868662350603A2863F682287b0768; // PREDICTED (fee receiver)
}

/// @notice Launch assets: underlying + price source (+ decimals), all VERIFIED on-chain.
/// address(0) = staged (asset skipped by the payload until pinned).
library AaveV4EtherfiCashAssets {
  address internal constant USDC_UNDERLYING = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
  address internal constant USDC_ORACLE = 0x87C74CB64b69FD6b338EE15F9772F05668914ED7;
  uint8 internal constant USDC_DECIMALS = 6;

  address internal constant USDT_UNDERLYING = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
  address internal constant USDT_ORACLE = 0x3Fe46756Ece51Dac6dd202F2e2b45454D4F8b89c;
  uint8 internal constant USDT_DECIMALS = 6;

  address internal constant EURC_UNDERLYING = 0xDCB612005417Dc906fF72c87DF732e5a90D49e11;
  address internal constant EURC_ORACLE = 0xc700125927b9f6ffae2F7b77D1D14cC725bAe628;
  uint8 internal constant EURC_DECIMALS = 6;

  address internal constant FRXUSD_UNDERLYING = 0x80Eede496655FB9047dd39d9f418d5483ED600df;
  address internal constant FRXUSD_ORACLE = 0xf1cF6275a3DD9DEf2bF902BCc25BfE4E1aB9Cc1b;
  uint8 internal constant FRXUSD_DECIMALS = 18;

  address internal constant WETH_UNDERLYING = 0x4200000000000000000000000000000000000006;
  address internal constant WETH_ORACLE = 0xCFe45EF2B9E138E5A2e1C25592441D5c556B3ca3; // "ETH / USD"
  uint8 internal constant WETH_DECIMALS = 18;

  address internal constant WEETH_UNDERLYING = 0x5A7fACB970D094B6C7FF1df0eA68D99E6e73CBFF;
  address internal constant WEETH_ORACLE = 0x9e1cAf5C8E7aB34628EA5973C0F2945bBD5109aC;
  uint8 internal constant WEETH_DECIMALS = 18;

  address internal constant EBTC_UNDERLYING = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
  address internal constant EBTC_ORACLE = 0x0fdF97E16f0bd50513Eed2771d4BC31265166488;
  uint8 internal constant EBTC_DECIMALS = 8;

  address internal constant EUSD_UNDERLYING = 0x939778D83b46B456224A33Fb59630B11DEC56663;
  address internal constant EUSD_ORACLE = 0x106399f5fCb6b1401b99A0B12F075721d518aD63;
  uint8 internal constant EUSD_DECIMALS = 18;

  address internal constant ETHFI_UNDERLYING = 0xe0080d2F853ecDdbd81A643dC10DA075Df26fD3f;
  address internal constant ETHFI_ORACLE = 0x823d8De4d50454E7e1529Ed8b390DaD973f3Daba;
  uint8 internal constant ETHFI_DECIMALS = 18;

  address internal constant SETHFI_UNDERLYING = 0x86B5780b606940Eb59A062aA85a07959518c0161;
  address internal constant SETHFI_ORACLE = 0x14c7600aC4023ccCf72fe81b1d475764c9214b13;
  uint8 internal constant SETHFI_DECIMALS = 18;

  address internal constant OP_UNDERLYING = 0x4200000000000000000000000000000000000042;
  address internal constant OP_ORACLE = 0x6D53a69EBC75cFeDf319F77569a4F732f75AED79;
  uint8 internal constant OP_DECIMALS = 18;

  address internal constant WHYPE_UNDERLYING = 0xd83E3d560bA6F05094d9D8B3EB8aaEA571D1864E;
  address internal constant WHYPE_ORACLE = 0xc4ca8A733aB9686753F1fc47443c46dEdb7b3670;
  uint8 internal constant WHYPE_DECIMALS = 18;

  address internal constant BEHYPE_UNDERLYING = 0xA519AfBc91986c0e7501d7e34968FEE51CD901aC;
  address internal constant BEHYPE_ORACLE = 0x259992e490BbfB94A08B51C753FBd001CC3b9Fb8;
  uint8 internal constant BEHYPE_DECIMALS = 18;

  address internal constant LIQUID_ETH_UNDERLYING = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
  address internal constant LIQUID_ETH_ORACLE = 0x4829C107Bc9896792c6f54bBF2Cb6F3322f20eCD;
  uint8 internal constant LIQUID_ETH_DECIMALS = 18;

  address internal constant LIQUID_BTC_UNDERLYING = 0x5f46d540b6eD704C3c8789105F30E075AA900726;
  address internal constant LIQUID_BTC_ORACLE = 0xc5b599B15826d50b1f9Ef9dF7a68a14cCb4123b3;
  uint8 internal constant LIQUID_BTC_DECIMALS = 8;

  address internal constant LIQUID_USD_UNDERLYING = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
  address internal constant LIQUID_USD_ORACLE = 0x7E916FE60091497c74D4aEd43A7Cf348e40AE38C;
  uint8 internal constant LIQUID_USD_DECIMALS = 6;

  address internal constant LIQUID_RESERVE_UNDERLYING = 0xca5921DF65E2e1b0B98Ae91c0187BA80D4124898;
  address internal constant LIQUID_RESERVE_ORACLE = 0x6D7b3725Faa812FE5e29EB67068882A71228b0CB;
  uint8 internal constant LIQUID_RESERVE_DECIMALS = 18;

  address internal constant WEEUR_UNDERLYING = 0xcC476B1a49bcDf5192561e87b6Fb8ea78aa28C13;
  address internal constant WEEUR_ORACLE = 0x4fdc1B6638f277bc2468Fb910f833678DF119f26;
  uint8 internal constant WEEUR_DECIMALS = 18;

  address internal constant LIQUID_RWA_UNDERLYING = 0x17bC8Ffd82b8a36e737Ca1141C025089589B915e;
  address internal constant LIQUID_RWA_ORACLE = 0x6148eE0E0923Ed5F0cCde2600a85166f4E250154;
  uint8 internal constant LIQUID_RWA_DECIMALS = 18;
}

/// @notice Launch spoke caps (whole tokens, uint40) — FINAL per the 'Submit to AAVE' section
/// of Proposal-Aave-V4-Parameters-by-Nonce (2026-07-23 17:25 revision). Only USDC and WETH
/// are borrowable at launch; every other asset is collateral-only (draw cap 0 by design).
/// Not part of the address-book upstream — launch configuration only.
library AaveV4EtherfiCashCaps {
  uint40 internal constant USDC_ADD_CAP = 10_000_000;
  uint40 internal constant USDC_DRAW_CAP = 7_000_000; // max util 70% < 92% kink
  uint40 internal constant USDT_ADD_CAP = 10_000_000;
  uint40 internal constant WETH_ADD_CAP = 1_000;
  uint40 internal constant WETH_DRAW_CAP = 100;
  uint40 internal constant EURC_ADD_CAP = 5_000_000;
  uint40 internal constant FRXUSD_ADD_CAP = 5_000_000;
  uint40 internal constant WEETH_ADD_CAP = 1_000;
  uint40 internal constant EBTC_ADD_CAP = 200;
  uint40 internal constant EUSD_ADD_CAP = 1_000_000;
  uint40 internal constant ETHFI_ADD_CAP = 2_000_000;
  uint40 internal constant SETHFI_ADD_CAP = 2_000_000;
  uint40 internal constant OP_ADD_CAP = 1_000_000;
  uint40 internal constant WHYPE_ADD_CAP = 100_000;
  uint40 internal constant BEHYPE_ADD_CAP = 100_000;
  uint40 internal constant LIQUID_ETH_ADD_CAP = 1_000;
  uint40 internal constant LIQUID_BTC_ADD_CAP = 100;
  uint40 internal constant LIQUID_USD_ADD_CAP = 5_000_000;
  uint40 internal constant LIQUID_RESERVE_ADD_CAP = 1_000_000;
  uint40 internal constant WEEUR_ADD_CAP = 1_000_000;
  uint40 internal constant LIQUID_RWA_ADD_CAP = 1_000_000;
}
