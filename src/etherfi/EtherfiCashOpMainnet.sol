// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title EtherfiCashOpMainnet
/// @notice Address book + cap configuration for the ether.fi Cash Aave V4 instance on OP Mainnet
/// (chainid 10). This is the ONLY file to edit when pinning launch values.
/// @dev Entry classes:
///      - VERIFIED: checked on-chain on 2026-07-23 — tokens via symbol()/decimals(), feeds via
///        decimals()/description()/latestAnswer() (the exact IPriceFeed interface AaveOracle
///        consumes), governance via aave-address-book + live calls.
///      - TBD (address(0)): not yet deployed or not yet pinned. The payload skips assets whose
///        underlying or feed is zero; the deploy pipeline refuses to run while any instance
///        address is zero.
///      - PROPOSED: caps drafted by ether.fi (see rationale in the AIP draft) — need Nonce
///        Capital sign-off before broadcast.
library EtherfiCashOpMainnet {
  // ---------------------------------------------------------------------------------------------
  // Administration multisigs — VERIFIED on OP 2026-07-23 (Safe v1.4.1, live code).
  // This is a whitelabel v4 instance: no Aave Governance V3 / PayloadsController involvement.
  // - OWNER_SAFE takes over ownership + admin roles of the instance after deployment and
  //   executes the launch payload via a delegatecall Safe transaction.
  // - OPERATOR_SAFE (Nonce risk curator) gets granular roles carved out by the payload:
  //   hub-side spoke caps (role 201) and spoke-side dynamic reserve config (role 401).
  // ---------------------------------------------------------------------------------------------
  address internal constant OWNER_SAFE = 0x082B85ED50F1cd120C597EF860ece712e54CE844;
  address internal constant OPERATOR_SAFE = 0x23c30c38d73a0D1609ffAAe47aA7d6D1a3e46f03;

  // ---------------------------------------------------------------------------------------------
  // ether.fi Cash Aave V4 instance — PREDICTED from a full fork simulation of
  // DeployEtherfiCashInstance + DeployEtherfiCashConfigEngine run as the launch deployer
  // (0xf8a86ea1Ac39EC529814c377Bd484387D395421e), 2026-07-23.
  // All addresses are CREATE2 via the Safe Singleton Factory (0x914d7Fec…43d7) with salts
  // derived from (deployer, user salt, label) — reproducible regardless of nonce, and the
  // factory reverts on mismatch, so the real deployment either produces exactly these
  // addresses or fails loudly. Requires: same commit + compiler settings, same deployer,
  // same salts. The preflight validator still blocks the pipeline until code exists here.
  // ---------------------------------------------------------------------------------------------
  address internal constant ACCESS_MANAGER = 0x188d7173772499FB6375F23FdFd130CE6107286b;
  address internal constant CONFIG_ENGINE = 0x84210b3087E952Be0f3610fD75f0f045995eAF22; // deployer-independent
  address internal constant HUB = 0x66753c4e3fC84f1eD0e3C267C927284E9d90C572; // CASH_HUB proxy
  address internal constant HUB_CONFIGURATOR = 0xA39bEf2fD611fb9c5a69D63277b4Af97a30F0dbC;
  address internal constant CASH_SPOKE = 0x208fAF5F20abb9E23A8E004CC813415C54448D8e; // CASH_SPOKE proxy
  address internal constant SPOKE_CONFIGURATOR = 0xFEe9E8cCE1c40D3bd9F025437D3A11cA0DAe9f8b;
  address internal constant IR_STRATEGY = 0x51d07C362f9c4716F96EbEB63DB985EF9D2aCd7C;
  address internal constant TREASURY_SPOKE = 0x7EB4d25F137868662350603A2863F682287b0768; // fee receiver spoke

  // AaveOracle (CASH_SPOKE) predicted at 0xf71F96C9570459af50519532b1503cB19Af5acb1 — the ONE
  // nonce-dependent address (plain `new` inside the spoke batch): valid only if the deployer's
  // OP nonce is 3 when the precompile step starts and no other txs interleave. Confirm from the
  // real deployment report. Not referenced by the payload (the spoke wires its own oracle).

  // ---------------------------------------------------------------------------------------------
  // Underlyings — all VERIFIED on-chain 2026-07-23 (source: 'Lend - Assets').
  // ---------------------------------------------------------------------------------------------
  address internal constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // "USDC", 6 dec
  address internal constant USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58; // "USDT", 6 dec
  address internal constant EURC = 0xDCB612005417Dc906fF72c87DF732e5a90D49e11; // "EURC", 6 dec
  address internal constant FRXUSD = 0x80Eede496655FB9047dd39d9f418d5483ED600df; // "frxUSD", 18 dec
  address internal constant WETH = 0x4200000000000000000000000000000000000006; // "WETH", 18 dec
  address internal constant WEETH = 0x5A7fACB970D094B6C7FF1df0eA68D99E6e73CBFF; // "weETH", 18 dec
  address internal constant EBTC = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642; // "eBTC", 8 dec
  address internal constant EUSD = 0x939778D83b46B456224A33Fb59630B11DEC56663; // "eUSD", 18 dec
  address internal constant ETHFI = 0xe0080d2F853ecDdbd81A643dC10DA075Df26fD3f; // "ETHFI", 18 dec
  address internal constant SETHFI = 0x86B5780b606940Eb59A062aA85a07959518c0161; // "sETHFI", 18 dec
  address internal constant OP = 0x4200000000000000000000000000000000000042; // "OP", 18 dec
  address internal constant WHYPE = 0xd83E3d560bA6F05094d9D8B3EB8aaEA571D1864E; // "WHYPE", 18 dec
  address internal constant BEHYPE = 0xA519AfBc91986c0e7501d7e34968FEE51CD901aC; // "beHYPE", 18 dec
  address internal constant LIQUID_ETH = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C; // "liquidETH", 18 dec
  address internal constant LIQUID_BTC = 0x5f46d540b6eD704C3c8789105F30E075AA900726; // "liquidBTC", 8 dec
  address internal constant LIQUID_USD = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C; // "liquidUSD", 6 dec
  address internal constant LIQUID_RESERVE = 0xE5d3854736e0D513aAE2D8D708Ad94d14Fd56A6a; // "liquidRESERVE", 18 dec
  address internal constant WEEUR = 0xcC476B1a49bcDf5192561e87b6Fb8ea78aa28C13; // "weEUR", 18 dec
  address internal constant LIQUID_RWA = 0x17bC8Ffd82b8a36e737Ca1141C025089589B915e; // "liquidRWA", 18 dec

  // ---------------------------------------------------------------------------------------------
  // Spoke caps, whole tokens (uint40) — FINAL per the 'Submit to AAVE' section of
  // Proposal-Aave-V4-Parameters-by-Nonce (2026-07-23 16:59 revision).
  // Only USDC and WETH are borrowable at launch; every other asset is collateral-only
  // (draw cap 0 by design).
  // ---------------------------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------------------------
  // Price sources — all VERIFIED on-chain 2026-07-23 (source: 'Lend - Oracle price feed
  // contracts'): 8 decimals, matching "<SYMBOL> / USD" description, positive latestAnswer().
  // These implement the minimal IPriceFeed (latestAnswer, no latestRoundData).
  // ---------------------------------------------------------------------------------------------
  address internal constant USDC_FEED = 0x87C74CB64b69FD6b338EE15F9772F05668914ED7;
  address internal constant USDT_FEED = 0x3Fe46756Ece51Dac6dd202F2e2b45454D4F8b89c;
  address internal constant EURC_FEED = 0xc700125927b9f6ffae2F7b77D1D14cC725bAe628;
  address internal constant FRXUSD_FEED = 0xf1cF6275a3DD9DEf2bF902BCc25BfE4E1aB9Cc1b;
  address internal constant WETH_FEED = 0xCFe45EF2B9E138E5A2e1C25592441D5c556B3ca3; // "ETH / USD"
  address internal constant WEETH_FEED = 0x9e1cAf5C8E7aB34628EA5973C0F2945bBD5109aC;
  address internal constant EBTC_FEED = 0x0fdF97E16f0bd50513Eed2771d4BC31265166488;
  address internal constant EUSD_FEED = 0x106399f5fCb6b1401b99A0B12F075721d518aD63;
  address internal constant ETHFI_FEED = 0x823d8De4d50454E7e1529Ed8b390DaD973f3Daba;
  address internal constant SETHFI_FEED = 0x14c7600aC4023ccCf72fe81b1d475764c9214b13;
  address internal constant OP_FEED = 0x6D53a69EBC75cFeDf319F77569a4F732f75AED79;
  address internal constant WHYPE_FEED = 0xc4ca8A733aB9686753F1fc47443c46dEdb7b3670;
  address internal constant BEHYPE_FEED = 0x259992e490BbfB94A08B51C753FBd001CC3b9Fb8;
  address internal constant LIQUID_ETH_FEED = 0x4829C107Bc9896792c6f54bBF2Cb6F3322f20eCD;
  address internal constant LIQUID_BTC_FEED = 0xc5b599B15826d50b1f9Ef9dF7a68a14cCb4123b3;
  address internal constant LIQUID_USD_FEED = 0x7E916FE60091497c74D4aEd43A7Cf348e40AE38C;
  address internal constant LIQUID_RESERVE_FEED = 0x6D7b3725Faa812FE5e29EB67068882A71228b0CB;
  address internal constant WEEUR_FEED = 0x4fdc1B6638f277bc2468Fb910f833678DF119f26;
  address internal constant LIQUID_RWA_FEED = 0x6148eE0E0923Ed5F0cCde2600a85166f4E250154;

  // Unmapped feed from the source list, kept for reference: standalone "BTC / USD"
  // 0xd85031243f5c9CeFf5a976f509de65D0E12aec59 (eBTC and liquidBTC have their own feeds).
}
