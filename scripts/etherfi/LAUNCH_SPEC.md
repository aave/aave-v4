# ether.fi Cash Aave V4 Instance on OP Mainnet - Launch Specification

> Status: PRE-DEPLOYMENT. All instance and payload addresses below are PREDICTED from a full fork
> simulation run as the launch deployer (CREATE2, reproduce-or-revert). The AaveOracle and Cash
> Spoke additionally require the deployer to start at nonce 3 with no interleaved transactions.
> To be confirmed against the deployment report. Spoke implementation: EtherFiSpokeInstance
> (borrow gated to Cash Safes), linked against LiquidationLogic 0x818E84198224535FAeaEc1b583d3Ff6b812A5AF3.

## Summary

Two-phase launch of the ether.fi Cash Aave V4 whitelabel instance on OP Mainnet, mirroring the Aave V4 Avalanche activation (proposal 504). Phase 1 (launch payload) configures everything DORMANT: lists 19 assets on the Hub, registers the Cash Spoke with per-asset caps (active = false), lists the reserves with their risk parameters, sets the Spoke liquidation configuration, and wires the operator roles. After on-chain verification of the configured state, phase 2 (activation payload) enumerates and activates every (asset, spoke) pair. Both phases are executed by the Owner Safe via delegatecall Safe transactions.

## Administration

| Role | Holder |
|---|---|
| Instance owner / payload executor | Owner Safe 0x082B85ED50F1cd120C597EF860ece712e54CE844 |
| Caps + dynamic risk config operator | Operator Safe (Nonce Capital) 0x23c30c38d73a0D1609ffAAe47aA7d6D1a3e46f03 |

Operator roles carved out by the payload: HUB_CAPS_OPERATOR_ROLE (201) for updateSpokeCaps/updateSpokeAddCap/updateSpokeDrawCap on the HubConfigurator, and SPOKE_RISK_OPERATOR_ROLE (401) for addDynamicReserveConfig/updateDynamicReserveConfig on the SpokeConfigurator. Both roles are also granted to the Owner Safe.

## Specification

### Liquidation engine (Spoke)

| Parameter | Value |
|---|---|
| Target health factor | 1.24 |
| Health factor for max bonus | 0.90 |
| Liquidation bonus factor | unchanged (deploy default) |

### Reserves

| Asset | CF | Max liq. bonus | Liq. fee | Borrowable | Liquidity fee | Kink | Base | Slope1 | Slope2 | Add cap | Draw cap |
|---|---|---|---|---|---|---|---|---|---|---|---|
| USDC | 95% | 1% | 10% | yes | 5% | 92% | 0% | 4% | 10% | 10000000 | 7000000 |
| WETH | 75% | 3.5% | 10% | yes | 7% | 92% | 0% | 2.35% | 14% | 1000 | 100 |
| USDT | 95% | 1% | 10% | no | 0% | 99% | 0% | 0% | 0% | 10000000 | 0 |
| EURC | 95% | 1% | 10% | no | 0% | 99% | 0% | 0% | 0% | 5000000 | 0 |
| frxUSD | 95% | 1% | 10% | no | 0% | 99% | 0% | 0% | 0% | 5000000 | 0 |
| weETH | 75% | 3.5% | 10% | no | 0% | 99% | 0% | 0% | 0% | 1000 | 0 |
| eBTC | 72% | 5% | 10% | no | 0% | 99% | 0% | 0% | 0% | 200 | 0 |
| eUSD | 90% | 2% | 10% | no | 0% | 99% | 0% | 0% | 0% | 1000000 | 0 |
| ETHFI | 30% | 5% | 10% | no | 0% | 99% | 0% | 0% | 0% | 2000000 | 0 |
| sETHFI | 30% | 5% | 10% | no | 0% | 99% | 0% | 0% | 0% | 2000000 | 0 |
| OP | 30% | 5% | 10% | no | 0% | 99% | 0% | 0% | 0% | 1000000 | 0 |
| WHYPE | 65% | 4% | 10% | no | 0% | 99% | 0% | 0% | 0% | 100000 | 0 |
| beHYPE | 60% | 5% | 10% | no | 0% | 99% | 0% | 0% | 0% | 100000 | 0 |
| liquidETH | 70% | 5% | 10% | no | 0% | 99% | 0% | 0% | 0% | 1000 | 0 |
| liquidBTC | 70% | 5% | 10% | no | 0% | 99% | 0% | 0% | 0% | 100 | 0 |
| liquidUSD | 80% | 2% | 10% | no | 0% | 99% | 0% | 0% | 0% | 5000000 | 0 |
| liquidRESERVE | 80% | 2% | 10% | no | 0% | 99% | 0% | 0% | 0% | 1000000 | 0 |
| weEUR | 80% | 2% | 10% | no | 0% | 99% | 0% | 0% | 0% | 1000000 | 0 |
| liquidRWA | 80% | 2% | 10% | no | 0% | 99% | 0% | 0% | 0% | 1000000 | 0 |

### Addresses

| Contract | Address |
|---|---|
| Launch payload (phase 1, dormant config) | 0x2aD084eac1f5783f2d971B02e1063EAF19617BAB |
| Activation payload (phase 2) | 0x7E30C8Fd5C59c929798911926cFaed02b0Cb5FbB |
| Owner Safe | 0x082B85ED50F1cd120C597EF860ece712e54CE844 |
| Operator Safe | 0x23c30c38d73a0D1609ffAAe47aA7d6D1a3e46f03 |
| AccessManager | 0x188d7173772499FB6375F23FdFd130CE6107286b |
| Config Engine | 0x84210b3087E952Be0f3610fD75f0f045995eAF22 |
| Hub | 0x66753c4e3fC84f1eD0e3C267C927284E9d90C572 |
| Hub Configurator | 0xA39bEf2fD611fb9c5a69D63277b4Af97a30F0dbC |
| Cash Spoke | 0xc5645c9956c088847616012855C786036A280a5C |
| Spoke Configurator | 0xFEe9E8cCE1c40D3bd9F025437D3A11cA0DAe9f8b |
| IR Strategy | 0x51d07C362f9c4716F96EbEB63DB985EF9D2aCd7C |
| Treasury Spoke (fee receiver) | 0x7EB4d25F137868662350603A2863F682287b0768 |
| USDC | 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85 |
| USDC feed | 0x87C74CB64b69FD6b338EE15F9772F05668914ED7 |
| WETH | 0x4200000000000000000000000000000000000006 |
| WETH feed | 0xCFe45EF2B9E138E5A2e1C25592441D5c556B3ca3 |
| USDT | 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 |
| USDT feed | 0x3Fe46756Ece51Dac6dd202F2e2b45454D4F8b89c |
| EURC | 0xDCB612005417Dc906fF72c87DF732e5a90D49e11 |
| EURC feed | 0xc700125927b9f6ffae2F7b77D1D14cC725bAe628 |
| frxUSD | 0x80Eede496655FB9047dd39d9f418d5483ED600df |
| frxUSD feed | 0xf1cF6275a3DD9DEf2bF902BCc25BfE4E1aB9Cc1b |
| weETH | 0x5A7fACB970D094B6C7FF1df0eA68D99E6e73CBFF |
| weETH feed | 0x9e1cAf5C8E7aB34628EA5973C0F2945bBD5109aC |
| eBTC | 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642 |
| eBTC feed | 0x0fdF97E16f0bd50513Eed2771d4BC31265166488 |
| eUSD | 0x939778D83b46B456224A33Fb59630B11DEC56663 |
| eUSD feed | 0x106399f5fCb6b1401b99A0B12F075721d518aD63 |
| ETHFI | 0xe0080d2F853ecDdbd81A643dC10DA075Df26fD3f |
| ETHFI feed | 0x823d8De4d50454E7e1529Ed8b390DaD973f3Daba |
| sETHFI | 0x86B5780b606940Eb59A062aA85a07959518c0161 |
| sETHFI feed | 0x14c7600aC4023ccCf72fe81b1d475764c9214b13 |
| OP | 0x4200000000000000000000000000000000000042 |
| OP feed | 0x6D53a69EBC75cFeDf319F77569a4F732f75AED79 |
| WHYPE | 0xd83E3d560bA6F05094d9D8B3EB8aaEA571D1864E |
| WHYPE feed | 0xc4ca8A733aB9686753F1fc47443c46dEdb7b3670 |
| beHYPE | 0xA519AfBc91986c0e7501d7e34968FEE51CD901aC |
| beHYPE feed | 0x259992e490BbfB94A08B51C753FBd001CC3b9Fb8 |
| liquidETH | 0xf0bb20865277aBd641a307eCe5Ee04E79073416C |
| liquidETH feed | 0x4829C107Bc9896792c6f54bBF2Cb6F3322f20eCD |
| liquidBTC | 0x5f46d540b6eD704C3c8789105F30E075AA900726 |
| liquidBTC feed | 0xc5b599B15826d50b1f9Ef9dF7a68a14cCb4123b3 |
| liquidUSD | 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C |
| liquidUSD feed | 0x7E916FE60091497c74D4aEd43A7Cf348e40AE38C |
| liquidRESERVE | 0xca5921DF65E2e1b0B98Ae91c0187BA80D4124898 |
| liquidRESERVE feed | 0x6D7b3725Faa812FE5e29EB67068882A71228b0CB |
| weEUR | 0xcC476B1a49bcDf5192561e87b6Fb8ea78aa28C13 |
| weEUR feed | 0x4fdc1B6638f277bc2468Fb910f833678DF119f26 |
| liquidRWA | 0x17bC8Ffd82b8a36e737Ca1141C025089589B915e |
| liquidRWA feed | 0x6148eE0E0923Ed5F0cCde2600a85166f4E250154 |

## Review

TODO: link payload review reports against the deployed payload address.
